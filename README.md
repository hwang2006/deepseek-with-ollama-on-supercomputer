# Running DeepSeek-R1 with Ollama on a Supercomputer

DeepSeek-R1, the recently released AI reasoning model from the Chinese AI startup DeepSeek, has gained significant attention for its performance, comparable to leading models like OpenAI's o1 reasoning model. It is open-source and free to use, allowing users to download, modify, and run it for their own purposes.
  
This repository demonstrates how to run and test DeepSeek-R1 using [Ollama](https://ollama.com/) with an individual's own account on a SLURM-managed supercomputer. Ollama provides a lightweight framework for downloading and running AI models locally, making AI deployment and management easier across different platforms, including macOS, Linux, and Windows. You can also access the Gradio UI to chat interactively with the DeepSeek-R1 model.


## KISTI Neuron GPU Cluster
Neuron is a KISTI GPU cluster system consisting of 65 nodes with 300 GPUs (40 of NVIDIA H200 GPUs, 120 of NVIDIA A100 GPUs and 140 of NVIDIA V100 GPUs). [Slurm](https://slurm.schedmd.com/) is adopted for cluster/resource management and job scheduling.

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
Install Ollama on your own scratch directory (i.e., /scratch/$USER) with the installation scripts.

- to run the install_ollama.sh script
```
[glogin01]$ chmod +x install_ollama.sh
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
Ollama path added to ~/.bashrc.  source ~/.bashrc or restart your terminal for changes to take effect.
Ollama installation complete.

[glogin01]$ source ~/.bashrc
[glogin01]$ ollama -v
Warning: could not connect to a running Ollama instance
Warning: client version is 0.5.7
```

- to install **specific versions** using the install_ollama_user.sh script
Use OLLAMA_VERSION environment variable with the install script to install a specific version of Ollama, including pre-releases. You can find the version numbers in the [releases page](https://github.com/ollama/ollama/releases).  
```
[glogin01]$ chmod +x install_ollama_user.sh
[glogin01]$ OLLAMA_VERSION=0.5.7 ./install_ollama_user.sh
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
(deepseek) [glogin01]$ pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu121
Looking in indexes: https://download.pytorch.org/whl/cu121, https://pypi.ngc.nvidia.com
Requirement already satisfied: torch==2.4.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (2.4.0+cu121)
Requirement already satisfied: torchvision==0.19.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (0.19.0+cu121)
Requirement already satisfied: torchaudio==2.4.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (2.4.0+cu121)
.
.
.
Requirement already satisfied: nvidia-nvjitlink-cu12 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from nvidia-cusolver-cu12==11.4.5.107->torch==2.4.0) (12.9.86)
Requirement already satisfied: MarkupSafe>=2.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from jinja2->torch==2.4.0) (2.1.5)
Requirement already satisfied: mpmath<1.4,>=1.1.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from sympy->torch==2.4.0) (1.3.0)
```
3. Install Gradio for UI
```
(deepseek) [glogin01]$ pip install gradio
Looking in indexes: https://pypi.org/simple, https://pypi.ngc.nvidia.com
Collecting gradio
  Downloading gradio-5.41.1-py3-none-any.whl.metadata (16 kB)
Requirement already satisfied: aiofiles<25.0,>=22.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from gradio) (23.2.1)
Requirement already satisfied: anyio<5.0,>=3.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from gradio) (4.10.0)
Requirement already satisfied: brotli>=1.1.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from gradio) (1.1.0)
.
.
.
Requirement already satisfied: pygments<3.0.0,>=2.13.0 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from rich>=10.11.0->typer<1.0,>=0.12->gradio) (2.19.2)
Requirement already satisfied: mdurl~=0.1 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from markdown-it-py>=2.2.0->rich>=10.11.0->typer<1.0,>=0.12->gradio) (0.1.2)
Requirement already satisfied: charset_normalizer<4,>=2 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from requests->huggingface-hub<1.0,>=0.33.5->gradio) (3.4.2)
Requirement already satisfied: urllib3<3,>=1.21.1 in /scratch/qualis/miniconda3/envs/deepseek/lib/python3.11/site-packages (from requests->huggingface-hub<1.0,>=0.33.5->gradio) (2.5.0)
Downloading gradio-5.41.1-py3-none-any.whl (59.7 MB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 59.7/59.7 MB 41.0 MB/s eta 0:00:00
Installing collected packages: gradio
Successfully installed gradio-5.41.1
```

## Running Gradio UI along with launching Ollama and Gradio server on compute node
This section describes how to run the Gradio UI along with launching the Ollama server and Gradio server on a compute node. The following Slurm script will start both servers and output a port forwarding command, which you can use to connect remotely.

### Slurm Script (ollama_gradio_run.sh)
```
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


- Then, open http://localhost:7860 in your browser to access the Gradio UI and pull a DeepSeek-R1 model (for example, 'deepseek-r1:14b') to the ollama server models directory (e.g., OLLAMA_MODELS="/scratch/$USER/ollama/models" in the slurm script) from the [Ollama models site](https://ollama.com/search) 

<img width="1231" alt="gradio_ui" src="https://github.com/user-attachments/assets/006ea85b-3535-4f2b-9f39-144ef26446bf" />


#### Once the deepseek-r1 model is successfully downloaded, it will be listed in the 'Select Model' dropdown menu on the top right of the Gradio UI. You can start chatting with the deepseek-r1:14b model. You could also pull and chat with other models (e.g., llama3, mistral, etc) by pulling them from the Ollama models list site. 

<img width="1178" alt="gradio_ui2" src="https://github.com/user-attachments/assets/291e20f0-a901-48f8-bb46-a0f667dc79f6" />


