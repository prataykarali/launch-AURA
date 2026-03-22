from tools.base import Tool
import sys
import gc
import time
from llama_cpp import Llama

# ANSI Color Codes for Script Mode
CYAN = "\033[96m"   # Character Names
WHITE = "\033[97m"  # Dialogue
GREY = "\033[90m"   # Stage Directions / Narrations
YELLOW = "\033[93m" # Scene Headers
RESET = "\033[0m"

class NarrateTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "NarrateTool"
        self.description = "Generates a detailed screenplay/play. Use for 'Narrate', 'Play', or 'Script' requests."
        self.category = "Creative"

    def generate_script_stream(self, scene_idea):
        print(f"\n🎬 [NarrateTool] Casting roles for: {scene_idea}...")
        
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

        # 🎭 ADVANCED SCRIPT PROMPT
        system_prompt = f"""You are an Award-Winning Playwright.
Scene Idea: {scene_idea}

TASK: Write a LONG, INTENSE SCENE in Script Format.

🚨 CRITICAL RULES:
1. **INVENT NAMES**: Do NOT use generic names (like Ari/Alia). Create names that fit the story context.
2. **SETTING**: Start with a detailed [SCENE START] block describing the room, lighting, and weather.
3. **ACTION BLOCKS**: Between dialogue, write descriptive paragraphs of action (Narrations).
4. **LENGTH**: The scene must be substantial (at least 20-30 exchanges).
5. **FORMAT**: 
   - NAMES in Uppercase.
   - Actions in (Parentheses).
   - Narrations in [Brackets].

Example Format:
[SCENE START]
The rain lashes against the window. A clock ticks loudly.

VIKTOR: (Cleaning his glasses) 
It didn't have to end this way.

[Viktor stands up and walks slowly to the fireplace, throwing a letter into the flames.]
"""

        print(f"🎭 [NarrateTool] Action!\n")
        print(f"{CYAN}─" * 60 + f"{RESET}")

        stream = llm(
            f"{system_prompt}\n\n[SCENE START]",
            max_tokens=2048,  # ⚡ Increased for longer scenes
            temperature=0.85, # High creativity for unique names
            stop=["\nUser:", "[SCENE END]"],
            stream=True
        )

        line_buffer = ""
        
        # Start with Scene Header color
        yield YELLOW
        yield "[SCENE START]"
        yield GREY # Default to Grey for the opening narration

        for chunk in stream:
            token = chunk['choices'][0]['text']
            
            # --- COLOR LOGIC ---
            if ":" in token and "\n" not in token:
                # Likely a Name (e.g., "SARAH:") -> Cyan
                yield RESET + CYAN + token + RESET + WHITE
            elif "(" in token:
                 # Parenthetical Action (e.g., "(Laughing)") -> Grey
                 yield GREY + token + RESET + WHITE
            elif "[" in token:
                 # Big Narration Block -> Grey/Yellow
                 yield YELLOW + token
            elif "]" in token:
                 # End of Narration Block
                 yield token + RESET + WHITE
            else:
                 # Normal text
                 yield token

            # Cinematic Delay
            line_buffer += token
            if "\n" in token:
                time.sleep(0.05) # Slight pause for readability
                line_buffer = ""

        yield RESET
        print("\n" + f"{CYAN}─" * 60 + f"{RESET}")
        
        del llm
        gc.collect()
        
        return "Scene complete."

    def execute(self, scene_idea: str):
        try:
            full_text = ""
            for token in self.generate_script_stream(scene_idea):
                print(token, end='', flush=True)
                full_text += token
            return "\n\n(Scene finished.)"
        except Exception as e:
            return f"Narration failed: {e}"

def get_tool():
    return NarrateTool()