import gradio as gr
import ollama
import io
import base64  # Added for base64 encoding
from PIL import Image

# Configuration
MODEL_NAME = "llama3.2-vision"
API_RETRIES = 3
RESPONSE_STYLES = ["Detailed", "Concise", "Creative"]

# Utility function: Convert image to bytes, preserving its format
def image_to_bytes(image):
    buffered = io.BytesIO()
    image_format = image.format if image.format else "PNG"  # Preserve original format or default to PNG
    image.save(buffered, format=image_format)
    return buffered.getvalue()

# Chatbot class
class Chatbot:
    def __init__(self, model_name, retries):
        self.client = ollama.Client()
        self.model_name = model_name
        self.retries = retries
        self.history = []

    def add_user_message(self, text_input, image_input, response_style):
        message = {'role': 'user', 'content': text_input.strip()}

        # Append response style preference
        if response_style == "Detailed":
            message['content'] += " Please provide a detailed response."
        elif response_style == "Concise":
            message['content'] += " Keep the response concise."
        elif response_style == "Creative":
            message['content'] += " Provide a creative response."

        # Handle image input
        if image_input:
            image_bytes = image_to_bytes(image_input)
            base64_image = base64.b64encode(image_bytes).decode('utf-8')
            message['images'] = [base64_image]

        self.history.append(message)

    def generate_response(self):
        for attempt in range(self.retries):
            try:
                response = self.client.chat(
                    model=self.model_name, messages=self.history
                )

                if 'message' not in response or 'content' not in response['message']:
                    print(f"Unexpected API response: {response}")
                    return "Error: Unexpected API response."

                assistant_message = {'role': 'assistant', 'content': response['message']['content']}
                self.history.append(assistant_message)
                return assistant_message['content']
            except Exception as e:
                print(f"Error generating response (Attempt {attempt + 1}): {e}")
        return "Error: Unable to generate response after multiple attempts."

    def clear_history(self):
        """ Clears chat history """
        self.history = []

# Instantiate chatbot
chatbot = Chatbot(model_name=MODEL_NAME, retries=API_RETRIES)

def handle_user_input(text_input, image_input, response_style):
    if not text_input.strip() and not image_input:
        return "Please provide either text or an image.", ""

    chatbot.add_user_message(text_input, image_input, response_style)
    generated_text = chatbot.generate_response()

    history_display = "\n".join(
        [f"{msg['role'].capitalize()}: {msg['content']}" for msg in chatbot.history]
    )

    return generated_text, history_display

def clear_chat():
    """ Clears the chat and resets the UI """
    chatbot.clear_history()
    return "", ""  # Clears response and history display

# Gradio interface
with gr.Blocks() as demo:
    gr.Markdown("# Enhanced Multimodal Chatbot with Llama 3.2 Vision")
    gr.Markdown("Upload an image or enter a text prompt, choose a response style, and view the generated response along with the interaction history.")

    with gr.Row():
        with gr.Column():
            text_input = gr.Textbox(lines=2, placeholder="Enter your question here...", label="Text Input")
            image_input = gr.Image(type="pil", label="Image Input (Optional)")
            response_style = gr.Dropdown(RESPONSE_STYLES, label="Response Style", value="Detailed")
            submit_button = gr.Button("Submit")
            #clear_button = gr.Button("Clear History")  # New Clear History button

        with gr.Column():
            generated_response = gr.Textbox(label="Generated Response")
            history_display = gr.Textbox(label="Conversation History", interactive=False)
            clear_button = gr.Button("Clear History")  # New Clear History button

    submit_button.click(
        fn=handle_user_input,
        inputs=[text_input, image_input, response_style],
        outputs=[generated_response, history_display]
    )

    clear_button.click(
        fn=clear_chat,
        inputs=[],
        outputs=[generated_response, history_display]
    )

demo.launch(server_name="0.0.0.0", share=True)
