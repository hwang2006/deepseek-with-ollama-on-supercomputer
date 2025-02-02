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

