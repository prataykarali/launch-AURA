import sys

class AURAYapper:
    """AURA's personality - Uses shared LLM (no extra loading!)"""
    
    def __init__(self, shared_llm):
        """
        ⚡ OPTIMIZATION: Receives already-loaded LLM instead of loading again
        """
        print("🌟 Connecting AURA's Personality to shared brain...")
        self.llm = shared_llm
        self.chat_history = []
        self.full_responses = []  # Track for memory saving

    def yap_stream(self, user_input, tool_name=None, context_memories=None):
        """
        Pure LLM responses with blindfold mode for tools
        Enhanced with memory context injection
        """
        self.llm.reset()
        
        # --- SCENARIO 1: TOOL EXECUTION (Blindfold Mode) ---
        if tool_name and tool_name != "NO_TOOL":
            readable_tool = tool_name.replace("Tool", "").replace("_", " ")
            
            prompt = f"""You are AURA, a friendly AI.

System: Running "{readable_tool}" tool.

Task: Write a brief, natural confirmation (under 10 words).

AURA:"""
            
            stream = self.llm(
                prompt, 
                max_tokens=15,  # Reduced for speed
                temperature=0.6,
                top_k=40,
                stop=["\n", "User:", "System:"], 
                stream=True
            )
            
            full_response = ""
            for chunk in stream:
                token = chunk['choices'][0]['text']
                if token:
                    full_response += token
                    yield token
            
            self.full_responses.append(full_response.strip())
            return

        # --- SCENARIO 2: CHAT MODE ---
        
        # Keep last 3 exchanges for speed
        self.chat_history = self.chat_history[-3:]
        history_text = "\n".join(self.chat_history) if self.chat_history else ""
        
        # Detect emotional context
        user_lower = user_input.lower()
        is_emotional = any(word in user_lower for word in 
            ['sad', 'depressed', 'crying', 'hurt', 'lonely', 'down', 'worried', 'scared', 'anxious'])
        is_greeting = len(user_input.split()) <= 3 and any(word in user_lower for word in 
            ['hi', 'hello', 'hey', 'sup', 'wassup', 'yo', 'thanks', 'thank'])
        
        # Adaptive parameters (optimized for speed)
        if is_emotional:
            max_tokens = 80
            temperature = 0.8
            instruction = "User needs emotional support. Be warm and empathetic."
        elif is_greeting:
            max_tokens = 20
            temperature = 0.7
            instruction = "Casual greeting. Be friendly and brief."
        else:
            max_tokens = 50
            temperature = 0.7
            instruction = "Natural conversation. Be friendly and concise."
        
        # Build prompt with optional memory context
        system_context = f"""Your name is AURA, a compassionate AI friend.

Personality: Warm, empathetic, witty, supportive.

{instruction}

"""
        
        # Inject memory context if available
        if context_memories:
            memory_text = "\n".join([f"[Memory: {m}]" for m in context_memories[:2]])
            system_context += f"\n{memory_text}\n"
        
        if history_text:
            prompt = f"{system_context}{history_text}\nUser: {user_input}\nAURA:"
        else:
            prompt = f"{system_context}User: {user_input}\nAURA:"

        try:
            stream = self.llm(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=0.9,
                top_k=40,
                repeat_penalty=1.1,
                stop=["User:", "\nUser", "System:"], 
                stream=True
            )
            
            full_response = ""
            token_count = 0
            
            for chunk in stream:
                token = chunk['choices'][0]['text']
                
                # Early exit on stop patterns
                if any(stop in token for stop in ["User:", "AURA:", "System:"]):
                    break
                
                # Prevent excessive rambling
                token_count += 1
                if token_count > max_tokens:
                    break
                
                if token:
                    full_response += token
                    yield token
            
            # Save to history
            if full_response.strip():
                clean_text = full_response.strip()
                self.chat_history.append(f"User: {user_input}")
                self.chat_history.append(f"AURA: {clean_text}")
                self.full_responses.append(clean_text)

        except Exception as e:
            error_prompt = "System: Error occurred. Say briefly you're here and ready.\nAURA:"
            try:
                for chunk in self.llm(error_prompt, max_tokens=15, temperature=0.5, stream=True):
                    yield chunk['choices'][0]['text']
            except:
                yield "I'm here! 😊"
    
    def get_last_response(self):
        """Returns the last complete response for memory saving"""
        return self.full_responses[-1] if self.full_responses else ""

# Singleton instance
_yapper_instance = None

def get_yapper(shared_llm):
    """
    ⚡ RECEIVES SHARED LLM - No duplicate loading!
    """
    global _yapper_instance
    if _yapper_instance is None:
        _yapper_instance = AURAYapper(shared_llm)
    return _yapper_instance