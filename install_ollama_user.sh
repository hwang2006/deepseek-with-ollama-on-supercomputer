#!/bin/sh
# This script installs Ollama on Linux in user's scratch directory.
# It detects the current operating system architecture and installs the appropriate version of Ollama.

set -eu

red="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 1 || :) 2>&-)"
plain="$( (/usr/bin/tput sgr0 || :) 2>&-)"

status() { echo ">>> $*" >&2; }
error() { echo "${red}ERROR:${plain} $*"; exit 1; }
warning() { echo "${red}WARNING:${plain} $*"; }

TEMP_DIR=$(mktemp -d)
cleanup() { rm -rf $TEMP_DIR; }
trap cleanup EXIT

available() { command -v $1 >/dev/null; }
require() {
    local MISSING=''
    for TOOL in $*; do
        if ! available $TOOL; then
            MISSING="$MISSING $TOOL"
        fi
    done

    echo $MISSING
}

[ "$(uname -s)" = "Linux" ] || error 'This script is intended to run on Linux only.'

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH" ;;
esac

IS_WSL2=false

KERN=$(uname -r)
case "$KERN" in
    *icrosoft*WSL2 | *icrosoft*wsl2) IS_WSL2=true;;
    *icrosoft) error "Microsoft WSL1 is not currently supported. Please use WSL2 with 'wsl --set-version <distro> 2'" ;;
    *) ;;
esac

VER_PARAM="${OLLAMA_VERSION:+?version=$OLLAMA_VERSION}"

# NO SUDO - installing to user directory
SUDO=""

NEEDS=$(require curl awk grep sed tee xargs)
if [ -n "$NEEDS" ]; then
    status "ERROR: The following tools are required but missing:"
    for NEED in $NEEDS; do
        echo "  - $NEED"
    done
    exit 1
fi

# Set custom installation directory in user's scratch space
OLLAMA_INSTALL_DIR="/scratch/${USER}/ollama"
BINDIR="${OLLAMA_INSTALL_DIR}/bin"

# Create directories if they don't exist
mkdir -p "$BINDIR"
mkdir -p "$OLLAMA_INSTALL_DIR/lib/ollama"

if [ -d "$OLLAMA_INSTALL_DIR/lib/ollama" ] ; then
    status "Cleaning up old version at $OLLAMA_INSTALL_DIR/lib/ollama"
    rm -rf "$OLLAMA_INSTALL_DIR/lib/ollama"
fi

status "Installing ollama to $OLLAMA_INSTALL_DIR"
mkdir -p "$OLLAMA_INSTALL_DIR/lib/ollama"

status "Downloading Linux ${ARCH} bundle"
status "https://ollama.com/download/ollama-linux-${ARCH}.tgz${VER_PARAM}"
curl --fail --show-error --location --progress-bar \
    "https://ollama.com/download/ollama-linux-${ARCH}.tgz${VER_PARAM}" | \
    tar -xzf - -C "$OLLAMA_INSTALL_DIR"

# Create symlink if ollama binary is not directly in bin directory
if [ "$OLLAMA_INSTALL_DIR/bin/ollama" != "$BINDIR/ollama" ] && [ -f "$OLLAMA_INSTALL_DIR/ollama" ]; then
    status "Making ollama accessible in the PATH in $BINDIR"
    ln -sf "$OLLAMA_INSTALL_DIR/ollama" "$BINDIR/ollama"
fi

# Check for NVIDIA JetPack systems with additional downloads
if [ -f /etc/nv_tegra_release ] ; then
    if grep R36 /etc/nv_tegra_release > /dev/null ; then
        status "Downloading JetPack 6 components"
        curl --fail --show-error --location --progress-bar \
            "https://ollama.com/download/ollama-linux-${ARCH}-jetpack6.tgz${VER_PARAM}" | \
            tar -xzf - -C "$OLLAMA_INSTALL_DIR"
    elif grep R35 /etc/nv_tegra_release > /dev/null ; then
        status "Downloading JetPack 5 components"
        curl --fail --show-error --location --progress-bar \
            "https://ollama.com/download/ollama-linux-${ARCH}-jetpack5.tgz${VER_PARAM}" | \
            tar -xzf - -C "$OLLAMA_INSTALL_DIR"
    else
        warning "Unsupported JetPack version detected.  GPU may not be supported"
    fi
fi

install_success() {
    status 'Install complete. Run "ollama" from the command line.'
    status "Make sure to add $BINDIR to your PATH:"
    status "export PATH=\"$BINDIR:\$PATH\""
    status "You can add this to your ~/.bashrc or ~/.profile for persistence"
    status 'To start ollama server: ollama serve'
    status 'The Ollama API will be available at 127.0.0.1:11434 when server is running.'
}
trap install_success EXIT

# Skip systemd configuration for user installation

# WSL2 only supports GPUs via nvidia passthrough
# so check for nvidia-smi to determine if GPU is available
if [ "$IS_WSL2" = true ]; then
    if available nvidia-smi && [ -n "$(nvidia-smi | grep -o "CUDA Version: [0-9]*\.[0-9]*")" ]; then
        status "Nvidia GPU detected."
    fi
    install_success
    exit 0
fi

# Don't attempt to install drivers on Jetson systems
if [ -f /etc/nv_tegra_release ] ; then
    status "NVIDIA JetPack ready."
    install_success
    exit 0
fi

# Install GPU dependencies on Linux (check only, no driver installation for user install)
if ! available lspci && ! available lshw; then
    warning "Unable to detect NVIDIA/AMD GPU. Install lspci or lshw to automatically detect GPU type."
    install_success
    exit 0
fi

check_gpu() {
    # Look for devices based on vendor ID for NVIDIA and AMD
    case $1 in
        lspci)
            case $2 in
                nvidia) available lspci && lspci -d '10de:' | grep -q 'NVIDIA' || return 1 ;;
                amdgpu) available lspci && lspci -d '1002:' | grep -q 'AMD' || return 1 ;;
            esac ;;
        lshw)
            case $2 in
                nvidia) available lshw && lshw -c display -numeric -disable network | grep -q 'vendor: .* \[10DE\]' || return 1 ;;
                amdgpu) available lshw && lshw -c display -numeric -disable network | grep -q 'vendor: .* \[1002\]' || return 1 ;;
            esac ;;
        nvidia-smi) available nvidia-smi || return 1 ;;
    esac
}

if check_gpu nvidia-smi; then
    status "NVIDIA GPU detected and drivers appear to be installed."
    install_success
    exit 0
fi

if ! check_gpu lspci nvidia && ! check_gpu lshw nvidia && ! check_gpu lspci amdgpu && ! check_gpu lshw amdgpu; then
    install_success
    warning "No NVIDIA/AMD GPU detected. Ollama will run in CPU-only mode."
    exit 0
fi

if check_gpu lspci amdgpu || check_gpu lshw amdgpu; then
    status "Downloading Linux ROCm ${ARCH} bundle"
    curl --fail --show-error --location --progress-bar \
        "https://ollama.com/download/ollama-linux-${ARCH}-rocm.tgz${VER_PARAM}" | \
        tar -xzf - -C "$OLLAMA_INSTALL_DIR"

    install_success
    status "AMD GPU ready."
    exit 0
fi

# For user installation, we skip CUDA driver installation as it requires root
if check_gpu lspci nvidia || check_gpu lshw nvidia; then
    warning "NVIDIA GPU detected but drivers may not be installed."
    warning "GPU acceleration requires NVIDIA drivers to be installed by system administrator."
    warning "Ollama will fall back to CPU-only mode if GPU drivers are not available."
fi

status "Installation complete. GPU support depends on system-installed drivers."
install_success
