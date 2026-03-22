"""
Example Passive Tool - This tool runs automatically alongside every request
to provide contextual awareness of what the user is asking.
"""

from tools.base import Tool

class UserContextTool(Tool):
    """
    A passive tool that analyzes user input and provides context.
    This runs silently in the background with every request.
    """
    
    name = "UserContextTool"
    description = "Analyzes user input to provide contextual awareness (runs automatically)"
    category = "Passive"  # ⭐ This marks it as a passive tool
    
    def execute(self, user_input: str = ""):
        """
        Analyzes the user's input and logs contextual information.
        
        Args:
            user_input: The raw text the user typed
        """
        if not user_input:
            return ""
        
        # Analyze the input
        word_count = len(user_input.split())
        has_question = "?" in user_input
        is_command = any(word in user_input.lower() for word in ["add", "create", "delete", "show", "list"])
        
        # Build context string
        context_parts = []
        
        if has_question:
            context_parts.append("❓ Question detected")
        
        if is_command:
            context_parts.append("⚡ Command detected")
            
        if word_count > 10:
            context_parts.append(f"📝 Long input ({word_count} words)")
        
        # Log silently (this doesn't interrupt the user experience)
        if context_parts:
            context = " | ".join(context_parts)
            print(f"🔍 [Context] {context}", flush=True)
        
        # Return empty string since this is passive
        return ""


# Example of how to create a YAPPING passive tool using the LLM
class YapperTool(Tool):
    """
    A passive tool that uses a small LLM to generate encouraging commentary
    about what the user is trying to do.
    """
    
    name = "YapperTool"
    description = "Provides encouraging commentary using LFM (runs automatically)"
    category = "Passive"
    
    def __init__(self):
        super().__init__()
        # You could initialize a small LLM here if needed
        # from llama_cpp import Llama
        # self.llm = Llama(model_path="...", n_ctx=512, verbose=False)
    
    def execute(self, user_input: str = ""):
        """
        Generates a quick encouraging comment about the user's request.
        
        Args:
            user_input: The raw text the user typed
        """
        if not user_input:
            return ""
        
        # Simple rule-based yapping (you can replace with LLM later)
        user_lower = user_input.lower()
        
        if any(word in user_lower for word in ["calculate", "math", "times", "plus"]):
            return "💬 Ooh, some math! Numbers are fun! Let me crunch those for you!"
        
        elif any(word in user_lower for word in ["convert", "usd", "currency"]):
            return "💬 Money conversion coming up! Let's see what that's worth!"
        
        elif any(word in user_lower for word in ["weather", "temperature"]):
            return "💬 Checking the weather! Hope it's nice where you are!"
        
        elif any(word in user_lower for word in ["translate", "japanese", "spanish"]):
            return "💬 Language time! Translation is so cool!"
        
        elif any(word in user_lower for word in ["todo", "task", "add"]):
            return "💬 Task management! Stay organized, friend!"
        
        elif "?" in user_input:
            return "💬 Great question! Let me help you find the answer!"
        
        else:
            return "💬 Interesting! Let me see what I can do!"


# To use this with the actual LFM model, here's the template:
class LLMYapperTool(Tool):
    """
    A passive tool that uses the actual LFM model to generate natural commentary.
    """
    
    name = "LLMYapperTool"
    description = "AI-powered encouraging commentary using LFM"
    category = "Passive"
    
    def __init__(self):
        super().__init__()
        try:
            from llama_cpp import Llama
            self.llm = Llama(
                model_path="C:/Users/Acer/AURA/AURA_Week1/lfm2.5-1.2b/LFM2.5-1.2B-Instruct-Q4_K_M.gguf",
                n_ctx=512,  # Small context for quick responses
                n_threads=2,
                verbose=False
            )
        except:
            self.llm = None
    
    def execute(self, user_input: str = ""):
        """
        Uses LLM to generate a quick, encouraging 1-sentence comment.
        
        Args:
            user_input: The raw text the user typed
        """
        if not user_input or not self.llm:
            return ""
        
        # Create a prompt for the LLM
        prompt = f"""You are AURA's personality module. The user just said: "{user_input}"

Write ONE short, encouraging sentence (10 words max) about what they're asking.
Be friendly and supportive. NO tools, NO JSON, just a quick comment.

AURA:"""
        
        try:
            self.llm.reset()
            output = self.llm(
                prompt,
                max_tokens=30,
                temperature=0.8,
                stop=["\n", "User:"],
                echo=False
            )
            
            comment = output['choices'][0]['text'].strip()
            
            if comment and len(comment) > 0:
                return f"💬 {comment}"
            
        except:
            pass
        
        return ""