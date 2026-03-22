from tools.base import Tool
import sys
import gc
import time
from llama_cpp import Llama

# ANSI Color Codes
YELLOW = "\033[93m"
RESET = "\033[0m"

class StoryTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "StoryTool"
        self.description = "Generates long, detailed stories with dialogue and formatting."
        self.category = "Creative"

    def generate_story_stream(self, topic, genre):
        print(f"\n🎬 [StoryTool] Action! Theme: {topic} ({genre})")
        
        try:
            llm = Llama(
                model_path="./models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf",
                n_ctx=4096, 
                n_threads=4,
                n_batch=512,
                verbose=False
            )
        except Exception as e:
            yield f"Error loading model: {e}"
            return

        # 🎭 EXTENDED CINEMATIC PROMPT
        system_prompt = f"""You are a Best-Selling Author.
Action: Write a LONG, IMMERSIVE story about: {topic}
Genre: {genre}

RULES:
1. START IMMEDIATELY with the Title.
2. LENGTH: Write at least 6-8 paragraphs.
3. PACING: Do NOT rush. Describe the atmosphere, sounds, and lighting in detail.
4. DIALOGUE: Include real conversations between characters.
5. FORMATTING: Use emojis 👻 and clear paragraph breaks.

"""

        print(f"🖋️  [StoryTool] AURA is writing your novel...\n")
        print(f"{YELLOW}─" * 60) 

        # Force the start with TITLE:
        final_prompt = f"{system_prompt}\n\nTITLE:"

        stream = llm(
            final_prompt,
            max_tokens=2500,  # ⚡ DOUBLED LENGTH
            temperature=0.85, 
            stop=["\nUser:", "(End of story)"],
            stream=True
        )

        paragraph_buffer = ""
        
        # Start Yellow
        yield YELLOW 
        yield "TITLE:" 

        for chunk in stream:
            token = chunk['choices'][0]['text']
            paragraph_buffer += token
            
            yield token

            # Dramatic Pause
            if "\n\n" in paragraph_buffer:
                time.sleep(0.3) 
                paragraph_buffer = ""

        # Reset Color
        yield RESET
        print("\n" + f"{YELLOW}─" * 60 + f"{RESET}")
        
        del llm
        gc.collect()
        
        return "Story complete."

    def execute(self, topic: str, genre: str = "General"):
        try:
            full_text = ""
            for token in self.generate_story_stream(topic, genre):
                print(token, end='', flush=True)
                full_text += token
            return "\n\n(Story generation complete.)"
        except Exception as e:
            return f"Story generation failed: {e}"

def get_tool():
    return StoryTool()