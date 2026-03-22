import time
import sys
from AURA_Memory.sql_memory import DatabaseManager
from AURA_Memory.vector_db import VectorStore
from RAG.retriever import ContextRetriever
from RAG.prompt_engine import PromptEngine

class PassiveBrain:
    def __init__(self):
        print("🧠 Passive System: Initializing Memory & Senses...")
        
        # 1. Initialize Memory Systems
        self.sql_db = DatabaseManager()
        self.session_id = self.sql_db.start_conversation(title=f"Session {time.strftime('%H:%M')}")
        self.vector_db = VectorStore()
        
        # 2. Initialize RAG
        self.retriever = ContextRetriever()
        self.prompt_engine = PromptEngine()
        
        # 3. Voice (Lazy loaded later)
        self.yapper = None
        self.use_yapper = False
        
        print(f"✅ Passive System Active (Session: {self.session_id})")

    def setup_voice(self, llm_instance):
        """Connects the Yapper to the active LLM."""
        try:
            from tools.AURA import get_yapper
            self.yapper = get_yapper(llm_instance)
            self.use_yapper = True
            print("✅ Passive System: Voice Connected")
        except ImportError:
            print("⚠️ Passive System: Voice Module Not Found (Running Silent)")

    def read_memory(self, user_input):
        """RAG LAYER: Fetches relevant history before the AI thinks."""
        print("  └── 🧠 [Passive] Scanning Memories...")
        return self.retriever.get_relevant_context(user_input)

    def construct_prompt(self, user_input, tool_menu_prompt):
        """Combines User Input + Retrieved Memory + System Rules."""
        # 1. Get Context
        context = self.read_memory(user_input)
        
        # 2. Build Contextual Prompt
        rag_prompt = self.prompt_engine.build_prompt(user_input, context)
        
        # 3. Combine with Tool Definitions
        return f"{tool_menu_prompt}\n\n{rag_prompt}"

    def write_log(self, role, content, tool_used=None):
        """LOGGING LAYER: Saves interaction to SQL and Vector DB."""
        # 1. SQL Log (Hard Record)
        msg_id = self.sql_db.add_message(self.session_id, role, content)
        
        # 2. Vector Log (Semantic Idea) - Only if meaningful
        is_meaningful = len(content) > 5 and "NO_TOOL" not in content and tool_used != "System"
        if is_meaningful:
            self.vector_db.add_memory(msg_id, content, {"role": role, "session": self.session_id})

    def speak(self, text, context=None):
        """VOICE LAYER: Streams the output to the console."""
        if not text: return

        if self.use_yapper:
            sys.stdout.write("🤖 AURA: ")
            sys.stdout.flush()
            for token in self.yapper.yap_stream(text, context):
                sys.stdout.write(token)
                sys.stdout.flush()
            print() # Newline
        else:
            print(f"🤖 AURA: {text}")