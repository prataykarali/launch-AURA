import sys
import os

# Add parent directory to path to import db and vector_store
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from AURA_Memory.sql_memory import DatabaseManager
from AURA_Memory.vector_db import VectorStore
from tools.base import Tool

class MemoryTool(Tool):
    """
    🧠 PASSIVE MEMORY SYSTEM
    Automatically saves and retrieves context from SQL + ChromaDB
    """
    
    name = "MemoryTool"
    description = "Passive memory system - auto-saves conversations and retrieves context"
    category = "Passive"  # ⚡ This makes it run automatically!
    
    def __init__(self):
        super().__init__()
        self.db = DatabaseManager()
        self.vector_store = VectorStore()
        
        # Start/resume conversation
        try:
            self.conversation_id = self.db.start_conversation(user_id=1, title="AURA Session")
        except:
            self.conversation_id = 1
    
    def execute(self, user_input: str = "", assistant_response: str = "", action: str = "auto"):
        """
        Actions:
        - 'auto': Save user input + retrieve context
        - 'save_assistant': Save assistant response
        - 'recall': Only retrieve context
        """
        
        try:
            # === ACTION 1: Save User Input ===
            if user_input and action in ["auto", "save_user"]:
                msg_id = self.db.add_message(self.conversation_id, "user", user_input)
                self.vector_store.add_memory(
                    memory_id=f"msg_{msg_id}",
                    text=user_input,
                    metadata={'role': 'user', 'conv_id': self.conversation_id}
                )
            
            # === ACTION 2: Save Assistant Response ===
            if assistant_response and action == "save_assistant":
                msg_id = self.db.add_message(self.conversation_id, "assistant", assistant_response)
                self.vector_store.add_memory(
                    memory_id=f"msg_{msg_id}",
                    text=assistant_response,
                    metadata={'role': 'assistant', 'conv_id': self.conversation_id}
                )
            
            # === ACTION 3: Retrieve Context ===
            if user_input and action in ["auto", "recall"]:
                results = self.vector_store.search_memory(user_input, n_results=2)
                if results['documents'] and results['documents'][0]:
                    context = results['documents'][0][:2]  # Top 2 memories
                    return f"🧠 Context recalled: {len(context)} relevant memories"
            
            return "✅ Memory updated"
            
        except Exception as e:
            return f"⚠️ Memory system: {str(e)}"