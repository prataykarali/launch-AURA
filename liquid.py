import sys

from llama_cpp import Llama

from main import ToolRegistry

# Import optimized yapper

try:

from tools.AURA import get_yapper

USE_YAPPER = True

except ImportError:

USE_YAPPER = False

print("⚠️ AURA yapper not found, using basic responses")

# 🛑 DISABLE OUTPUT BUFFERING for streaming

sys.stdout.reconfigure(line_buffering=True)

# ==========================================

# 1. SETUP & DYNAMIC TOOL LOADING

# ==========================================

print("🔧 Initializing Tool Registry...")

registry = ToolRegistry(max_workers=5) # ⚡ Optimized worker count

registry.register_all()

# 🔍 DYNAMICALLY GET ALL TOOLS

tool_menu = registry.get_registry_menu()

print(f"✅ Loaded {len(tool_menu)} tools into AURA's brain.")

# Load yapper if available

if USE_YAPPER:

yapper = get_yapper()

# ==========================================

# 2. LOAD ROUTING MODEL (The Brain)

# ==========================================

print("\nLoading Routing Model...")

llm = Llama(

model_path="./models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf",

n_ctx=1024,

n_threads=6,  # ⚡ Optimized for speed

n_batch=512,  # ⚡ Batch processing

verbose=False

)

print("Ready!\n")

# ==========================================

# 3. 🎨 DYNAMICALLY BUILD SYSTEM PROMPT

# ==========================================

def build_dynamic_system_prompt(tool_menu):

"""

🔥 FULLY DYNAMIC PROMPT BUILDER

Automatically generates the system prompt from discovered tools

"""

# Build tool descriptions from actual discovered tools

tools_desc = []

for tool in tool_menu:

tool_name = tool['tool_name']

description = tool['description']

args = tool['arguments']

if args:

args_str = ", ".join([

f"{name}: {info['type']}" + (" (required)" if info['required'] else "")

for name, info in args.items()

])

tools_desc.append(f"- {tool_name}: {description}\n  Args: {args_str}")

else:

tools_desc.append(f"- {tool_name}: {description}")

tools_text = "\n".join(tools_desc)

return f"""You are AURA, an AI assistant.

You have access to these TOOLS:

{tools_text}

🔴 RULES:

1. ONLY output JSON for tools.

2. If the user is just chatting or no tool is required, you MUST output:

{{"name": "NO_TOOL", "params": {{}}}}

3. Format: {{"name": "tool_name", "params": {{...}}}}

4. If asking about MONEY (usd, eur, rs) -> Use 'UnitConverterTool'.

5. If asking about MATH -> Use 'calc_expression'.

6. If asking about TIME -> Use 'TimeTool'.

7. If asking about WEATHER -> Use 'WeatherTool'.

✅ EXAMPLES:

User: "Hi"

AURA: {{"name": "NO_TOOL", "params": {{}}}}

User: "Tell me a story about a cat."

AURA: {{"name": "StoryTool", "params": {{"topic": "a cat", "genre": "Fiction"}}}}

User: "Narrate a conversation between two AI robots."

AURA: {{"name": "NarrateTool", "params": {{"scene_idea": "conversation between two AI robots"}}}}

User: "Tell me a scary story about a haunted coding bootcamp."

AURA: {{"name": "StoryTool", "params": {{"topic": "a scary story about a haunted coding bootcamp","genre": "Sci-Fi"}}}}

User: "What is 5 times 10?"

AURA: {{"name": "calc_expression", "params": {{"expression": "5 * 10"}}}}

User: "Check weather in Kolkata"

AURA: {{"name": "WeatherTool", "params": {{"city": "Kolkata"}}}}

"""

system_prompt = build_dynamic_system_prompt(tool_menu)

# ==========================================

# 4. HELPER FUNCTIONS

# ==========================================

def extract_json(text):

"""

Robustly finds the FIRST valid JSON object in text.

"""

text = text.strip()

start_index = text.find('{')

if start_index == -1: return None

balance = 0

for i in range(start_index, len(text)):

char = text[i]

if char == '{': balance += 1

elif char == '}': balance -= 1

if balance == 0:

json_str = text[start_index : i+1]

try: return json.loads(json_str)

except: return None

return None

# ==========================================

# 5. 🚀 FINAL FIXED CHAT LOOP

# ==========================================

while True:

try:

print() # spacer

user_input = input("You: ").strip()

except EOFError:

break

if user_input.lower() in ['exit', 'quit', 'bye']:

if USE_YAPPER:

print("AURA: ", end='', flush=True)

for token in yapper.yap_stream("bye"):

print(token, end='', flush=True)

print()

break

if not user_input:

continue

llm.reset()

prompt = f"{system_prompt}\n\nUser: {user_input}\nAURA:"

try:

# --- STEP 1: BRAIN (GET INTENT) ---

output = llm(

prompt,

max_tokens=150,

temperature=0.1,

stop=["\nUser:", "User:", "}}", "}\n"],

echo=False

)

full_response = output['choices'][0]['text']

if "{" in full_response and not full_response.endswith("}"):

full_response += "}}"

tool_call = extract_json(full_response)

# Guard against hallucinations

valid_tools = [t['tool_name'] for t in tool_menu]

raw_name = tool_call.get("name") if tool_call else "NO_TOOL"

tool_name = raw_name if raw_name in valid_tools else "NO_TOOL"

# --- STEP 2: VOICE (THE YAPPER) ---

# Runs EVERY time.

if USE_YAPPER:

print("AURA: ", end='', flush=True)

# Context logic:

# If tool is NO_TOOL -> Yapper sees 'None' -> Uses Chat History Logic

# If tool is Real -> Yapper sees 'ToolName' -> Uses Dynamic Confirmation Logic

context = tool_name if tool_name != "NO_TOOL" else None

for token in yapper.yap_stream(user_input, context):

print(token, end='', flush=True)

sys.stdout.flush()

print()

# --- STEP 3: HANDS (THE REGISTRY) ---

if tool_name != "NO_TOOL":

print("─" * 50, flush=True)

# 🕵️ DEBUG: Uncomment to see raw JSON

# print(f"🕵️ DEBUG: {json.dumps(tool_call)}")

# Use the smart swarm to execute the tool

registry.run_smart_swarm([tool_call], user_input)

except KeyboardInterrupt:

print("\n👋 Goodbye!")

break

except Exception as e:

print(f"\n❌ System Error: {e}")