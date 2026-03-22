import chromadb
from sentence_transformers import SentenceTransformer
import os

class VectorStore:
    def __init__(self, collection_name="aura_memory"):
        # 1. Calculate path to 'Data' folder
        script_dir = os.path.dirname(os.path.abspath(__file__))
        # Go UP one level (to AURA-Proj) then DOWN into 'Data'
        data_dir = os.path.join(os.path.dirname(script_dir), "Data")
        
        # 2. SAFETY CHECK: Create 'Data' folder if it is missing
        if not os.path.exists(data_dir):
            os.makedirs(data_dir)
            print(f"📁 Created missing Data directory at: {data_dir}")
        
        # 3. Define path for ChromaDB inside Data
        # Result: AURA-Proj/Data/chroma_db_data
        db_path = os.path.join(data_dir, "chroma_db_data")
        
        # 4. Setup ChromaDB (Persistent storage in the right place)
        self.client = chromadb.PersistentClient(path=db_path)
        
        # 5. Load Embedding Model
        print("⏳ Loading AI Model (this happens once)...")
        self.model = SentenceTransformer('all-MiniLM-L6-v2')
        print("✅ Model Loaded!")
        
        # 6. Create/Get Collection
        self.collection = self.client.get_or_create_collection(name=collection_name)

    def add_memory(self, memory_id, text, metadata=None):
        """
        Stores a memory.
        memory_id: Unique ID (usually from SQLite)
        text: The sentence to remember
        metadata: Extra info (e.g., {'role': 'user', 'timestamp': '...'})
        """
        # Convert text to vector
        vector = self.model.encode(text).tolist()
        
        # Add to database
        self.collection.add(
            ids=[str(memory_id)],
            embeddings=[vector],
            documents=[text],
            metadatas=[metadata] if metadata else None
        )

    def search_memory(self, query_text, n_results=3):
        """
        Finds the most similar memories to the query.
        """
        # Convert query to vector
        query_vector = self.model.encode(query_text).tolist()
        
        # Search
        results = self.collection.query(
            query_embeddings=[query_vector],
            n_results=n_results
        )
        
        return results