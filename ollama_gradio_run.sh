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

# Exit on any error
#set -e

# Cleanup function
#cleanup() {
#    echo "Cleaning up processes..."
#    if [ -n "$OLLAMA_PID" ]; then
#        kill -TERM $OLLAMA_PID 2>/dev/null || true
#    fi
#    if [ -n "$GRADIO_PID" ]; then
#        kill -TERM $GRADIO_PID 2>/dev/null || true
#    fi
#    exit 0
#}
#trap cleanup EXIT INT TERM

# Port and paths
SERVER="$(hostname)"
PORT_GRADIO=7860
OLLAMA_PORT=11434

GRADIO_LOG="gradio_server.log"
OLLAMA_LOG="ollama_server.log"
OLLAMA_MODELS="/scratch/$USER/ollama/models"

echo "========================================"
echo "Starting Ollama + Gradio on $SERVER"
echo "Gradio Port: $PORT_GRADIO"
echo "Ollama Port: $OLLAMA_PORT"
echo "========================================"

# Create port forwarding command and display it
echo "ssh -L localhost:7860:${SERVER}:${PORT_GRADIO} ${USER}@neuron.ksc.re.kr" > port_forwarding_command
echo "ssh -L localhost:7860:${SERVER}:${PORT_GRADIO} ${USER}@neuron.ksc.re.kr"

# Load modules and env
echo "📦 Loading modules..."
module load gcc/10.2.0 cuda/12.1

echo "🔍 GPU Information:"
nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader,nounits

echo "🐍 Activating Conda environment..."
source ~/.bashrc
conda activate deepseek

echo "Python version: $(python --version)"
echo "Ollama path: $(which ollama 2>/dev/null || echo 'Not found in PATH')"

# Navigate to the workspace directory
cd /scratch/$USER/deepseek


echo "🧹 Cleaning up existing processes..."
pkill -f "ollama serve" 2>/dev/null || true
pkill -f "ollama_web.py" 2>/dev/null || true
sleep 2

# Remove old Ollama log file if it exists
if [ -e "$OLLAMA_LOG" ]; then
  rm "$OLLAMA_LOG"
  echo "Old $OLLAMA_LOG file removed."
fi

# Remove old Gradio log file if it exists
if [ -e "$GRADIO_LOG" ]; then
  rm "$GRADIO_LOG"
  echo "Old $GRADIO_LOG file removed."
fi

# Prepare Ollama environment
mkdir -p "$OLLAMA_MODELS"
export OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT"
export OLLAMA_MODELS="$OLLAMA_MODELS"
export OLLAMA_MAX_LOADED_MODELS=3
export OLLAMA_NUM_PARALLEL=6
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE=f16
export OLLAMA_GPU_OVERHEAD=209715200
export OLLAMA_KEEP_ALIVE=30m
export OLLAMA_MAX_QUEUE=128
export CUDA_VISIBLE_DEVICES=0

echo "🚀 Starting Ollama server..."
ollama serve > "$OLLAMA_LOG" 2>&1 &
OLLAMA_PID=$!
echo "Ollama PID: $OLLAMA_PID"

echo "⏳ Waiting for Ollama server to start..."
for attempt in {1..30}; do
    if curl -s http://127.0.0.1:$OLLAMA_PORT/api/tags >/dev/null; then
        echo "✅ Ollama server is ready!"
        break
    fi
    echo "Attempt $attempt/30 - waiting for Ollama..."
    sleep 2
done

if ! curl -s http://127.0.0.1:$OLLAMA_PORT/api/tags >/dev/null; then
    echo "❌ Ollama server failed to start."
    tail -20 "$OLLAMA_LOG"
    exit 1
fi

echo "📋 Available models:"
ollama list || echo "No models found"

# Gradio setup
echo "🌐 Starting Gradio web interface..."

export XDG_CACHE_HOME=/tmp/${USER}/.gradio_cache
export TMPDIR=/tmp/${USER}/tmp
mkdir -p $XDG_CACHE_HOME $TMPDIR

#python ollama_web.py --host=0.0.0.0 --port=${PORT_GRADIO} > "$GRADIO_LOG" 2>&1 &
python ollama_web.py --host=0.0.0.0 --port=${PORT_GRADIO} --share > "$GRADIO_LOG" 2>&1 & 
GRADIO_PID=$!
echo "Gradio PID: $GRADIO_PID"

# Wait and verify
echo "⏳ Waiting for Gradio to start..."
sleep 5

if kill -0 $GRADIO_PID 2>/dev/null; then
    echo "✅ Gradio is running!"
else
    echo "❌ Gradio failed to start"
    tail -20 "$GRADIO_LOG"
    exit 1
fi

# Final status
echo ""
echo "🎉 All services started successfully!"
echo "📊 Access Gradio at: http://localhost:7860 (after port forwarding)"
echo "🔧 Ollama API at: http://127.0.0.1:$OLLAMA_PORT"
echo ""
echo "📝 Log files:"
echo "  Ollama: $OLLAMA_LOG"
echo "  Gradio: $GRADIO_LOG"
echo ""
echo "🔗 Port forwarding command:"
echo "ssh -L localhost:7860:${SERVER}:${PORT_GRADIO} ${USER}@neuron.ksc.re.kr"
echo ""

#echo "🕓 Waiting for servers to finish... Press Ctrl+C to terminate."
#wait $GRADIO_PID

