import gradio as gr
import requests
from requests.adapters import HTTPAdapter, Retry
import subprocess
import os
import argparse
import json
import sys
import html
import time

class OllamaChat:
    def __init__(self, ollama_url="http://localhost:11434"):
        self.base_url = ollama_url
        self.models_dir = os.getenv("OLLAMA_MODELS", "/scratch/qualis/workspace/ollama/models")
        self.session = requests.Session()

        # Configure retries for API calls
        retries = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
        self.session.mount("http://", HTTPAdapter(max_retries=retries))

    def get_available_models(self):
        """Get the list of available models from the Ollama server."""
        try:
            response = self.session.get(f"{self.base_url}/api/tags", timeout=30)
            if response.status_code == 200:
                models = response.json()
                return [model['name'] for model in models.get('models', [])]
            return []
        except requests.exceptions.RequestException as e:
            print(f"Error fetching models: {str(e)}")
            return []

    def is_model_local(self, model_name):
        """Check if the model appears in Ollama's list of installed models."""
        return model_name in self.get_available_models()

    def pull_model(self, model_name, progress=gr.Progress()):
        """Pull a model from the Ollama site using the 'ollama pull' command."""
        try:
            progress(0, desc="Starting model pull...")
            print(f"Pulling model: {model_name}")
            result = subprocess.run(
                ["ollama", "pull", model_name],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            if result.returncode == 0:
                print(f"Model pull successful. Output: {result.stdout}")
                retries = 3
                for _ in range(retries):
                    print("Checking available models...")
                    available_models = self.get_available_models()
                    print(f"Available models: {available_models}")

                    prefix_available_models = [model.split(":")[0] for model in available_models]
                    print(f"Available models w/o version number: {prefix_available_models}")
                    
                    if model_name in available_models or model_name in prefix_available_models:
                        progress(1, desc="Model pull complete.")
                        return f"Successfully pulled model '{model_name}'."
                    time.sleep(2)

                return f"Model '{model_name}' pulled but not found locally after {retries} attempts."
            else:
                return f"Error pulling model '{model_name}': {result.stderr}"
        except Exception as e:
            return f"Error during model pull: {str(e)}"

    def generate_response_stream(self, message, history, model_name, temperature):
        """Generate streaming response from the Ollama model."""
        try:
            url = f"{self.base_url}/api/generate"
            data = {
                "model": model_name.strip(),
                "prompt": message.strip(),
                "stream": True,
                "temperature": float(temperature)
            }

            print(f"Sending request to {url} with payload: {data}")

            response = self.session.post(url, json=data, stream=True, timeout=100)
            if response.status_code == 200:
                for line in response.iter_lines():
                    if line:
                        chunk = json.loads(line.decode("utf-8"))
                        decoded_response = html.unescape(chunk["response"])

                        if decoded_response == "<think>":
                            print("Model is thinking...")
                            yield "Thinking..."
                            continue
                        else:
                            yield decoded_response
            else:
                yield f"Error: Server returned status code {response.status_code} - {response.text}"
        except requests.exceptions.RequestException as e:
            yield f"Error: {str(e)}"

def create_interface(ollama_url):
    # Initialize the OllamaChat class
    chat = OllamaChat(ollama_url)

    # Get available models
    models = chat.get_available_models()
    default_model = models[0] if models else ""

    # Define the interface
    with gr.Blocks(title="Ollama Chat Interface") as iface:
        gr.Markdown("# Ollama Chat Interface")

        with gr.Row():
            with gr.Column(scale=4):
                #chatbot = gr.Chatbot(height=400)
                chatbot = gr.Chatbot(height=400, type="messages")
                message = gr.Textbox(label="Message", placeholder="Type your message here...")
                submit = gr.Button("Send")

            with gr.Column(scale=1):
                model_dropdown = gr.Dropdown(
                    choices=models,
                    value=default_model,
                    label="Select Model",
                    interactive=True,
                    elem_id="model_dropdown"
                )
                model_name_input = gr.Textbox(
                    label="Model Name to Pull from the Ollama site",
                    placeholder="Enter the model name to pull..."
                )
                pull_button = gr.Button("Pull Model")
                pull_status = gr.Textbox(label="Pull Status", interactive=False)

                temperature = gr.Slider(
                    minimum=0.0,
                    maximum=1.0,
                    value=0.7,
                    step=0.1,
                    label="Temperature"
                )
                clear = gr.Button("Clear Chat")

        def respond(message, chat_history, model_name, temp):
            print(f"[Prompt] User said: {message}") #for debugging purpose

            if not message.strip():
                return "", chat_history

            new_chat_history = chat_history + [{"role": "user", "content": message}]
            assistant_message = ""

            for chunk in chat.generate_response_stream(message, chat_history, model_name, temp):
                assistant_message += chunk
                yield "", new_chat_history + [
                    {"role": "assistant", "content": assistant_message}]
        
        def update_model_list():
            """Updates the model list and returns it."""
            print("Updating Model List")
            return chat.get_available_models()

        def pull_model_action(model_name):
            """Handles the model pulling action and updates the dropdown."""
            print("pull_model_action() started...")
            if not model_name.strip():
                return "Error: Please specify a model name.", gr.update(choices=update_model_list())

            status = chat.pull_model(model_name)
            updated_models = update_model_list()
            print(f"Updated models list after pull: {updated_models}")

            return (
                status,
                gr.update(choices=updated_models, value=model_name if model_name in updated_models else updated_models[0])
            )

        submit.click(
            respond,
            [message, chatbot, model_dropdown, temperature],
            [message, chatbot]
        )

        message.submit(
            respond,
            [message, chatbot, model_dropdown, temperature],
            [message, chatbot]
        )

        pull_button.click(
            pull_model_action,
            inputs=[model_name_input],
            outputs=[pull_status, model_dropdown]
        )

        clear.click(
            lambda: ([], ""),
            None,
            [chatbot, message],
            queue=False
        )

    return iface

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ollama Web Interface")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to run the server on (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=7860, help="Port to run the server on (default: 7860)")
    parser.add_argument("--share", action="store_true", help="Create a public URL (default: False)")
    parser.add_argument("--ollama-url", type=str, default="http://localhost:11434", help="Ollama API URL (default: http://localhost:11434)")

    args = parser.parse_args()

    iface = create_interface(args.ollama_url)
    iface.launch(server_name=args.host, server_port=args.port, share=args.share)


