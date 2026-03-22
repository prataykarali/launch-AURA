from AURA_Memory.vector_db import VectorStore
from AURA_Memory.sql_memory import DatabaseManager

class ContextRetriever:
    def __init__(self):
        # Connect to the Brain (ChromaDB) and the Notebook (SQL)
        self.brain = VectorStore()
        self.notebook = DatabaseManager()

    def get_relevant_context(self, query, top_k=3):
        """
        Finds the most similar past conversations to the current query.
        """
        # 1. Search the Vector Database for semantic matches
        results = self.brain.search_memory(query, n_results=top_k)
        
        context_lines = []
        
        # 2. Extract and format the findings
        if results and results['documents']:
            documents = results['documents'][0]
            metadatas = results['metadatas'][0]
            
            for doc, meta in zip(documents, metadatas):
                role = meta.get('role', 'unknown').upper()
                context_lines.append(f"- {role}: {doc}")
        
        # Join into a single block of text for the LLM
        return "\n".join(context_lines) if context_lines else ""