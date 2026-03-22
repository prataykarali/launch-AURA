class PromptEngine:
    def build_prompt(self, user_query, retrieved_context):
        """
        Glues the system rules, the memories, and the user's question together.
        """
        
        system_instruction = """
        You are AURA, an advanced AI agent. 
        Use the 'RELEVANT PAST MEMORIES' to inform your answer. 
        If the memory doesn't help, use your general knowledge.
        """

        if retrieved_context:
            # Memory Injection Mode
            return f"""
{system_instruction}

🧠 RELEVANT PAST MEMORIES:
{retrieved_context}

👤 USER: {user_query}
🤖 AURA:
""".strip()
        else:
            # Standard Chat Mode (No relevant memories found)
            return f"""
{system_instruction}

👤 USER: {user_query}
🤖 AURA:
""".strip()