# deepseek-with-ollama-on-supercomputer

DeepSeek-R1, the recently released AI reasoning model from the Chinese AI startup DeepSeek, has gained significant attention for its performance, comparable to leading models like OpenAI's o1 reasoning model. It is open-source and free to use, allowing users to download, modify, and run it for their own purposes.

This repository demonstrates how to run and test DeepSeek-R1 using [Ollama](https://ollama.com/) on a SLURM-managed supercomputer. Ollama provides a lightweight framework for downloading and running AI models locally, making AI deployment and management easier across different platforms, including macOS, Linux, and Windows.


## KISTI Neuron GPU Cluster
Neuron is a KISTI GPU cluster system consisting of 65 nodes with 260 GPUs (120 of NVIDIA A100 GPUs and 140 of NVIDIA V100 GPUs). [Slurm](https://slurm.schedmd.com/) is adopted for cluster/resource management and job scheduling.

<p align="center"><img src="https://user-images.githubusercontent.com/84169368/205237254-b916eccc-e4b7-46a8-b7ba-c156e7609314.png"/></p>

## Installing Conda
Once logging in to Neuron, you will need to have either [Anaconda](https://www.anaconda.com/) or [Miniconda](https://docs.conda.io/en/latest/miniconda.html) installed on your scratch directory. Anaconda is distribution of the Python and R programming languages for scientific computing, aiming to simplify package management and deployment. Anaconda comes with +150 data science packages, whereas Miniconda, a small bootstrap version of Anaconda, comes with a handful of what's needed.

1. Check the Neuron system specification
```
[glogin01]$ cat /etc/*release*
CentOS Linux release 7.9.2009 (Core)
Derived from Red Hat Enterprise Linux 7.8 (Source)
NAME="CentOS Linux"
VERSION="7 (Core)"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
PRETTY_NAME="CentOS Linux 7 (Core)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:centos:centos:7"
HOME_URL="https://www.centos.org/"
BUG_REPORT_URL="https://bugs.centos.org/"

CENTOS_MANTISBT_PROJECT="CentOS-7"
CENTOS_MANTISBT_PROJECT_VERSION="7"
REDHAT_SUPPORT_PRODUCT="centos"
REDHAT_SUPPORT_PRODUCT_VERSION="7"

CentOS Linux release 7.9.2009 (Core)
CentOS Linux release 7.9.2009 (Core)
cpe:/o:centos:centos:7
```

2. Download Anaconda or Miniconda. Miniconda comes with python, conda (package & environment manager), and some basic packages. Miniconda is fast to install and could be sufficient for distributed deep learning training practices. 
```
# (option 1) Anaconda 
[glogin01]$ cd /scratch/$USER  ## Note that $USER means your user account name on Neuron
[glogin01]$ wget https://repo.anaconda.com/archive/Anaconda3-2022.10-Linux-x86_64.sh --no-check-certificate
```
```
# (option 2) Miniconda 
[glogin01]$ cd /scratch/$USER  ## Note that $USER means your user account name on Neuron
[glogin01]$ wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh --no-check-certificate
```

3. Install Miniconda. By default conda will be installed in your home directory, which has a limited disk space. You will install and create subsequent conda environments on your scratch directory. 
```
[glogin01]$ chmod 755 Miniconda3-latest-Linux-x86_64.sh
[glogin01]$ ./Miniconda3-latest-Linux-x86_64.sh

Welcome to Miniconda3 py39_4.12.0

In order to continue the installation process, please review the license
agreement.
Please, press ENTER to continue
>>>                               <======== press ENTER here
.
.
.
Do you accept the license terms? [yes|no]
[no] >>> yes                      <========= type yes here 

Miniconda3 will now be installed into this location:
/home01/qualis/miniconda3        

  - Press ENTER to confirm the location
  - Press CTRL-C to abort the installation
  - Or specify a different location below

[/home01/qualis/miniconda3] >>> /scratch/$USER/miniconda3  <======== type /scratch/$USER/miniconda3 here
PREFIX=/scratch/qualis/miniconda3
Unpacking payload ...
Collecting package metadata (current_repodata.json): done
Solving environment: done

## Package Plan ##

  environment location: /scratch/qualis/miniconda3
.
.
.
Preparing transaction: done
Executing transaction: done
installation finished.
Do you wish to update your shell profile to automatically initialize conda?
This will activate conda on startup and change the command prompt when activated.
If you'd prefer that conda's base environment not be activated on startup,
   run the following command when conda is activated:

conda config --set auto_activate_base false

You can undo this by running `conda init --reverse $SHELL`? [yes|no]
[no] >>> yes         <========== type yes here
.
.
.
no change     /scratch/qualis/miniconda3/etc/profile.d/conda.csh
modified      /home01/qualis/.bashrc

==> For changes to take effect, close and re-open your current shell. <==

Thank you for installing Miniconda3!
```

4. finalize installing Miniconda with environment variables set including conda path

```
[glogin01]$ source ~/.bashrc    # set conda path and environment variables 
[glogin01]$ conda config --set auto_activate_base false
[glogin01]$ which conda
/scratch/$USER/miniconda3/condabin/conda
[glogin01]$ conda --version
conda 23.9.0
```

## Cloning the Repository
to set up this repository on your scratch direcory.
```
[glogin01]$ cd /scratch/$USER
[glogin01]$ git clone https://github.com/hwang2006/deepseek-with-ollama-on-supercomputer.git
[glogin01]$ cd deepseek-with-ollama-on-supercomputer
```

## Installing Ollama
Install Ollama on your own scratch directory (i.e., /scratch/$USER) by runing the install_ollama.sh script
```bash
[glogin01]$ cat install_ollama.sh
#!/bin/bash

# 1. Create Ollama installation directory
user="$USER"  # Or use $UID for more robustness in some edge cases
install_dir="/scratch/$user/ollama"

mkdir -p "$install_dir"  # -p creates parent directories if needed

# 2. Change directory and download
cd "$install_dir" || { echo "Error: Could not change directory to $install_dir"; exit 1; }

wget "https://ollama.com/download/ollama-linux-amd64.tgz" || { echo "Error: Could not download Ollama"; exit 1; }

# 3. Unzip/untar
tar -xvzf ollama-linux-amd64.tgz || { echo "Error: Could not extract Ollama"; exit 1; }

# Clean up the tar file (optional)
rm ollama-linux-amd64.tgz


# 4. Add to ~/.bashrc (more robust approach)
bashrc_file="$HOME/.bashrc"

# Check if the path is already in .bashrc to avoid duplicates
if ! grep -q "$install_dir/bin" "$bashrc_file"; then
  echo "export PATH=\$PATH:$install_dir/bin" >> "$bashrc_file"
  echo "Ollama path added to ~/.bashrc.  source ~/.bashrc or restart your terminal for changes to take effect."
else
    echo "Ollama path is already in ~/.bashrc"
fi


# Optional: Make the ollama binary executable (if needed - usually not necessary with the official .tgz)
# chmod +x "$install_dir/$ollama_extracted_dir/bin/ollama"

echo "Ollama installation complete."

[glogin01]$ ./install_ollama.sh
--2025-02-02 21:32:09--  https://ollama.com/download/ollama-linux-amd64.tgz
Resolving ollama.com (ollama.com)... 34.36.133.15
Connecting to ollama.com (ollama.com)|34.36.133.15|:443... connected.
HTTP request sent, awaiting response... 307 Temporary Redirect
Location: https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tgz [following]
--2025-02-02 21:32:09--  https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tgz
Resolving github.com (github.com)... 20.200.245.247
Connecting to github.com (github.com)|20.200.245.247|:443... connected.
HTTP request sent, awaiting response... 302 Found
.
.
.
./lib/ollama/runners/cpu_avx/ollama_llama_server
./lib/ollama/libcublas.so.11.5.1.109
./lib/ollama/libcublasLt.so.12
Ollama path added to ~/.bashrc.  source ~/.bashrc or restart your terminal for changes to take effect.
Ollama installation complete.

[glogin01]$ source ~/.bashrc
[glogin01]$ ollama -v
Warning: could not connect to a running Ollama instance
Warning: client version is 0.5.7
```

## Creating a Conda Virtual Environment
1. Create a conda virtual environment with a python version 3.11
```
[glogin01]$ conda create -n deepseek python=3.11
Retrieving notices: ...working... done
Collecting package metadata (current_repodata.json): done
Solving environment: done

## Package Plan ##

  environment location: /scratch/qualis/miniconda3/envs/deepseek

  added / updated specs:
    - python=3.11
.
.
.
Proceed ([y]/n)? y    <========== type yes 


Downloading and Extracting Packages:

Preparing transaction: done
Verifying transaction: done
Executing transaction: done
#
# To activate this environment, use
#
#     $ conda activate deepseek
#
# To deactivate an active environment, use
#
#     $ conda deactivate
```

2. Install PyTorch
```
[glogin01]$ module load gcc/10.2.0 cmake/3.26.2 cuda/12.1
[glogin01]$ conda activate deepseek
(deepseek) [glogin01]$ conda install conda install pytorch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 pytorch-cuda=12.1 -c pytorch -c nvidia -y
Channels:
 - pytorch
 - nvidia
 - defaults
Platform: linux-64
Collecting package metadata (repodata.json): done
Solving environment: done

## Package Plan ##

  environment location: /scratch/qualis/miniconda3/envs/test

  added / updated specs:
    - pytorch-cuda=12.1
    - pytorch==2.3.0
    - torchaudio==2.3.0
    - torchvision==0.18.0


The following NEW packages will be INSTALLED:

  blas               pkgs/main/linux-64::blas-1.0-mkl
  brotli-python      pkgs/main/linux-64::brotli-python-1.0.9-py310h6a678d5_8
  certifi            pkgs/main/linux-64::certifi-2024.8.30-py310h06a4308_0
  charset-normalizer pkgs/main/noarch::charset-normalizer-3.3.2-pyhd3eb1b0_0
  cuda-cudart        nvidia/linux-64::cuda-cudart-12.1.105-0
  cuda-cupti         nvidia/linux-64::cuda-cupti-12.1.105-0
  cuda-libraries     nvidia/linux-64::cuda-libraries-12.1.0-0
  cuda-nvrtc         nvidia/linux-64::cuda-nvrtc-12.1.105-0
  cuda-nvtx          nvidia/linux-64::cuda-nvtx-12.1.105-0
  cuda-opencl        nvidia/linux-64::cuda-opencl-12.6.68-0
  cuda-runtime       nvidia/linux-64::cuda-runtime-12.1.0-0
  cuda-version       nvidia/noarch::cuda-version-12.6-3
  ffmpeg             pytorch/linux-64::ffmpeg-4.3-hf484d3e_0
  filelock           pkgs/main/linux-64::filelock-3.13.1-py310h06a4308_0
  freetype           pkgs/main/linux-64::freetype-2.12.1-h4a9f257_0
  gmp                pkgs/main/linux-64::gmp-6.2.1-h295c915_3
  gmpy2              pkgs/main/linux-64::gmpy2-2.1.2-py310heeb90bb_0
  gnutls             pkgs/main/linux-64::gnutls-3.6.15-he1e5248_0
  idna               pkgs/main/linux-64::idna-3.7-py310h06a4308_0
  intel-openmp       pkgs/main/linux-64::intel-openmp-2023.1.0-hdb19cb5_46306
  jinja2             pkgs/main/linux-64::jinja2-3.1.4-py310h06a4308_0
  jpeg               pkgs/main/linux-64::jpeg-9e-h5eee18b_3
  lame               pkgs/main/linux-64::lame-3.100-h7b6447c_0
  lcms2              pkgs/main/linux-64::lcms2-2.12-h3be6417_0
  lerc               pkgs/main/linux-64::lerc-3.0-h295c915_0
  libcublas          nvidia/linux-64::libcublas-12.1.0.26-0
  libcufft           nvidia/linux-64::libcufft-11.0.2.4-0
  libcufile          nvidia/linux-64::libcufile-1.11.1.6-0
  libcurand          nvidia/linux-64::libcurand-10.3.7.68-0
  libcusolver        nvidia/linux-64::libcusolver-11.4.4.55-0
  libcusparse        nvidia/linux-64::libcusparse-12.0.2.55-0
  libdeflate         pkgs/main/linux-64::libdeflate-1.17-h5eee18b_1
  libiconv           pkgs/main/linux-64::libiconv-1.16-h5eee18b_3
  libidn2            pkgs/main/linux-64::libidn2-2.3.4-h5eee18b_0
  libjpeg-turbo      pytorch/linux-64::libjpeg-turbo-2.0.0-h9bf148f_0
  libnpp             nvidia/linux-64::libnpp-12.0.2.50-0
  libnvjitlink       nvidia/linux-64::libnvjitlink-12.1.105-0
  libnvjpeg          nvidia/linux-64::libnvjpeg-12.1.1.14-0
  libpng             pkgs/main/linux-64::libpng-1.6.39-h5eee18b_0
  libtasn1           pkgs/main/linux-64::libtasn1-4.19.0-h5eee18b_0
  libtiff            pkgs/main/linux-64::libtiff-4.5.1-h6a678d5_0
  libunistring       pkgs/main/linux-64::libunistring-0.9.10-h27cfd23_0
  libwebp-base       pkgs/main/linux-64::libwebp-base-1.3.2-h5eee18b_0
  llvm-openmp        pkgs/main/linux-64::llvm-openmp-14.0.6-h9e868ea_0
  lz4-c              pkgs/main/linux-64::lz4-c-1.9.4-h6a678d5_1
  markupsafe         pkgs/main/linux-64::markupsafe-2.1.3-py310h5eee18b_0
  mkl                pkgs/main/linux-64::mkl-2023.1.0-h213fc3f_46344
  mkl-service        pkgs/main/linux-64::mkl-service-2.4.0-py310h5eee18b_1
  mkl_fft            pkgs/main/linux-64::mkl_fft-1.3.10-py310h5eee18b_0
  mkl_random         pkgs/main/linux-64::mkl_random-1.2.7-py310h1128e8f_0
  mpc                pkgs/main/linux-64::mpc-1.1.0-h10f8cd9_1
  mpfr               pkgs/main/linux-64::mpfr-4.0.2-hb69a4c5_1
  mpmath             pkgs/main/linux-64::mpmath-1.3.0-py310h06a4308_0
  nettle             pkgs/main/linux-64::nettle-3.7.3-hbbd107a_1
  networkx           pkgs/main/linux-64::networkx-3.2.1-py310h06a4308_0
  numpy              pkgs/main/linux-64::numpy-2.0.1-py310h5f9d8c6_1
  numpy-base         pkgs/main/linux-64::numpy-base-2.0.1-py310hb5e798b_1
  openh264           pkgs/main/linux-64::openh264-2.1.1-h4ff587b_0
  openjpeg           pkgs/main/linux-64::openjpeg-2.5.2-he7f1fd0_0
  pillow             pkgs/main/linux-64::pillow-10.4.0-py310h5eee18b_0
  pysocks            pkgs/main/linux-64::pysocks-1.7.1-py310h06a4308_0
  pytorch            pytorch/linux-64::pytorch-2.3.0-py3.10_cuda12.1_cudnn8.9.2_0
  pytorch-cuda       pytorch/linux-64::pytorch-cuda-12.1-ha16c6d3_5
  pytorch-mutex      pytorch/noarch::pytorch-mutex-1.0-cuda
  pyyaml             pkgs/main/linux-64::pyyaml-6.0.1-py310h5eee18b_0
  requests           pkgs/main/linux-64::requests-2.32.3-py310h06a4308_0
  sympy              pkgs/main/linux-64::sympy-1.13.2-py310h06a4308_0
  tbb                pkgs/main/linux-64::tbb-2021.8.0-hdb19cb5_0
  torchaudio         pytorch/linux-64::torchaudio-2.3.0-py310_cu121
  torchtriton        pytorch/linux-64::torchtriton-2.3.0-py310
  torchvision        pytorch/linux-64::torchvision-0.18.0-py310_cu121
  typing_extensions  pkgs/main/linux-64::typing_extensions-4.11.0-py310h06a4308_0
  urllib3            pkgs/main/linux-64::urllib3-2.2.2-py310h06a4308_0
  yaml               pkgs/main/linux-64::yaml-0.2.5-h7b6447c_0
  zstd               pkgs/main/linux-64::zstd-1.5.5-hc292b87_2



Downloading and Extracting Packages:

Preparing transaction: done
Verifying transaction: done
Executing transaction: done
```
3. Install Gradio for UI
```
(deepseek) [glogin01]$ pip install gradio
Looking in indexes: https://pypi.org/simple, https://pypi.ngc.nvidia.com
Collecting gradio
  Downloading gradio-5.14.0-py3-none-any.whl.metadata (16 kB)
Collecting aiofiles<24.0,>=22.0 (from gradio)
  Downloading aiofiles-23.2.1-py3-none-any.whl.metadata (9.7 kB)
Collecting anyio<5.0,>=3.0 (from gradio)
  Downloading anyio-4.8.0-py3-none-any.whl.metadata (4.6 kB)
.
.
.
Installing collected packages: pytz, pydub, websockets, tzdata, tqdm, tomlkit, sniffio, six, shellingham, semantic-version, ruff, python-multipart, pygments, pydantic-core, packaging, orjson, mdurl, h11, fsspec, ffmpy, click, annotated-types, aiofiles, uvicorn, python-dateutil, pydantic, markdown-it-py, huggingface-hub, httpcore, anyio, starlette, rich, pandas, httpx, typer, safehttpx, gradio-client, fastapi, gradio
Successfully installed aiofiles-23.2.1 annotated-types-0.7.0 anyio-4.8.0 click-8.1.8 fastapi-0.115.8 ffmpy-0.5.0 fsspec-2025.2.0 gradio-5.14.0 gradio-client-1.7.0 h11-0.14.0 httpcore-1.0.7 httpx-0.28.1 huggingface-hub-0.28.1 markdown-it-py-3.0.0 mdurl-0.1.2 orjson-3.10.15 packaging-24.2 pandas-2.2.3 pydantic-2.10.6 pydantic-core-2.27.2 pydub-0.25.1 pygments-2.19.1 python-dateutil-2.9.0.post0 python-multipart-0.0.20 pytz-2025.1 rich-13.9.4 ruff-0.9.4 safehttpx-0.1.6 semantic-version-2.10.0 shellingham-1.5.4 six-1.17.0 sniffio-1.3.1 starlette-0.45.3 tomlkit-0.13.2 tqdm-4.67.1 typer-0.15.1 tzdata-2025.1 uvicorn-0.34.0 websockets-14.2
```

## Running Gradio UI along with launching Ollama and Gradio server on compute node
This section describes how to run the Gradio UI along with launching the Ollama server and Gradio server on a compute node. The following Slurm script will start both servers and output a port forwarding command, which you can use to connect remotely.

### Slurm Script (ollama_gradio_run.sh)
```bash
#!/bin/bash

#SBATCH --comment=pytorch
##SBATCH --partition=mig_amd_a100_4
##SBATCH --partition=gh200_1
##SBATCH --partition=eme_h200nv_8
#SBATCH --partition=amd_a100nv_8
##SBATCH --partition=cas_v100nv_8
##SBATCH --partition=cas_v100nv_4
##SBATCH --partition=cas_v100_4
##SBATCH --partition=bigmem
##SBATCH --partition=gdebug01
#SBATCH --time=48:00:00        # walltime
##SBATCH --time=12:00:00        # walltime
#SBATCH --nodes=1             # the number of nodes
#SBATCH --ntasks-per-node=1   # number of tasks per node
#SBATCH --gres=gpu:1          # number of gpus per node
#SBATCH --cpus-per-task=8     # number of cpus per task

# Check and remove existing port forwarding command file
if [ -e port_forwarding_command ]; then
  rm port_forwarding_command
fi

# Getting the port and node name
SERVER="`hostname`"
PORT_GRADIO=$(($RANDOM + 10000)) # Generate a random port number greater than 10000
PORT_GRADIO=7860

echo $SERVER
echo $PORT_GRADIO

# Create port forwarding command and display it
echo "ssh -L localhost:7860:${SERVER}:${PORT_GRADIO} ${USER}@neuron.ksc.re.kr" > port_forwarding_command
echo "ssh -L localhost:7860:${SERVER}:${PORT_GRADIO} ${USER}@neuron.ksc.re.kr"

# Load necessary modules
echo "Load module-environment"
module load gcc/10.2.0 cuda/12.1

# Activate the Conda environment
echo "Activating Conda environment..."
source ~/.bashrc
conda activate deepseek

# Navigate to the workspace directory
cd /scratch/$USER/deepseek

# Log files
GRADIO_LOG="gradio_server.log"
OLLAMA_LOG="ollama_server.log"

# ============================
# Manage Ollama Server
# ============================
OLLAMA_PORT=11434
OLLAMA_PID=$(lsof -t -i:$OLLAMA_PORT)
OLLAMA_PID=$(ps aux | grep ollama | grep -v grep | awk '{print $2}' )

if [ -n "$OLLAMA_PID" ]; then
  echo "Ollama server is already running with PID $OLLAMA_PID. Killing the process..."
  kill -9 $OLLAMA_PID
  echo "Ollama process killed."
fi

# Remove old Ollama log file if it exists
if [ -e "$OLLAMA_LOG" ]; then
  rm "$OLLAMA_LOG"
  echo "Old $OLLAMA_LOG file removed."
fi

# Start Ollama server in the background
echo "Starting Ollama server..."
OLLAMA_MODELS="/scratch/$USER/ollama/models"
OLLAMA_ENV_VARS=(
  "OLLAMA_HOST=127.0.0.1:11434"
  "OLLAMA_MAX_LOADED_MODELS=2"
  "OLLAMA_NUM_PARALLEL=4"
  "OLLAMA_FLASH_ATTENTION=1"
  "OLLAMA_KV_CACHE_TYPE=f16"
  "OLLAMA_GPU_OVERHEAD=104857600"
  "OLLAMA_MODELS=$OLLAMA_MODELS"
)

# Export environment variables and run Ollama
for VAR in "${OLLAMA_ENV_VARS[@]}"; do
  export $VAR
done

ollama serve > "$OLLAMA_LOG" 2>&1 &
echo "Ollama logs are being written to $OLLAMA_LOG"

# ============================
# Manage Gradio Server
# ============================

# Check if a Gradio server is already running and kill it
GRADIO_PID=$(lsof -t -i:$PORT_GRADIO)
if [ -n "$GRADIO_PID" ]; then
  echo "Gradio server is already running with PID $GRADIO_PID. Killing the process..."
  kill -9 $GRADIO_PID
  echo "Gradio process killed."
fi

# Remove old Gradio log file if it exists
if [ -e "$GRADIO_LOG" ]; then
  rm "$GRADIO_LOG"
  echo "Old $GRADIO_LOG file removed."
fi

# Start Gradio in the background and log output
echo "Starting Gradio..."
#python gradio_chatbot.py --server_name=0.0.0.0 --server_port=${PORT_GRADIO} > "$GRADIO_LOG" 2>&1 &
python ollama_web.py --host=0.0.0.0 --port=${PORT_GRADIO} > "$GRADIO_LOG" 2>&1
#python ollama_web.py > "$GRADIO_LOG" 2>&1 &
echo "Gradio logs are being written to $GRADIO_LOG"

# Notify user of successful launch
echo "Ollama and Gradio have been started."
echo "Gradio is running at: http://localhost:$PORT_GRADIO (port-forwarded)"
```

### Submitting the Slurm Script
- to launch both Ollama and Gradio server
```
(deepseek) [glogin01]$ sbatch ollama_gradio_run.sh
Submitted batch job XXXXXX
```
- to check if the servers are up and running
```
(deepseek) [glogin01]$ squeue -u $USER
             JOBID       PARTITION     NAME     USER    STATE       TIME TIME_LIMI  NODES NODELIST(REASON)
            XXXXXX    amd_a100nv_8  ollama_g    $USER  RUNNING       0:02   2-00:00:00      1 gpu##
```
- to check the SSH tunneling information generated by the ollama_gradio_run.sh script 
```
(deepseek) [glogin01]$ cat port_forwarding_command
ssh -L localhost:7860:gpu32:7860 $USER@neuron.ksc.re.kr
```

### Connecting to the Gradio UI
- Once the job starts, open a a new SSH client (e.g., Putty, MobaXterm, PowerShell, Command Prompt, etc) on your local machine and run the port forwarding command displayed in port_forwarding_command:

<img width="787" alt="Image" src="https://github.com/user-attachments/assets/25b218f2-c188-43a0-8081-2814ba9044b4" />


- Then, open http://localhost:7860 in your browser to access the Gradio UI and pull a DeepSeek-R1 model (for example, 'deepseek-r1:14b') to the ollama server models directory (i.e., /scratch/$USER/ollama/models) from the [Ollama models site](https://ollama.com/search) 

<img width="1231" alt="gradio_ui" src="https://github.com/user-attachments/assets/006ea85b-3535-4f2b-9f39-144ef26446bf" />


Once deepseek-r1 is successfully pulled, it will be shown in the model dropdown menu. You can start chatting with the deepseek-r1:14b model. You could also pull and chat with other models (e.g., llama3, mistral, etc) from the Ollama models site. 

<img width="1178" alt="gradio_ui2" src="https://github.com/user-attachments/assets/291e20f0-a901-48f8-bb46-a0f667dc79f6" />


