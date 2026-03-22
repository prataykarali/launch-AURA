from AURA_Memory.vector_db import VectorStore

def test_brain():
    print("🚀 STARTING VECTOR MEMORY TEST...\n")
    
    # 1. Initialize
    brain = VectorStore()
    
    # 2. Teach AURA some facts (Simulating past conversations)
    print("📝 Teaching AURA...")
    memories = [
        (1, "I love eating pepperoni pizza.", {"role": "user"}),
        (2, "My favorite coding language is Python.", {"role": "user"}),
        (3, "The weather in Kolkata is very humid today.", {"role": "user"}),
        (4, "I hate waking up early in the morning.", {"role": "user"}),
        (5, "Artificial Intelligence is the future of humanity.", {"role": "assistant"})
    ]

    for mem_id, text, meta in memories:
        brain.add_memory(mem_id, text, meta)
    
    print(f"✅ Stored {len(memories)} memories.")

    # 3. Test Semantic Search
    # NOTICE: We search for "food", but the memory says "pizza". 
    # A standard database would FAIL this. A Vector DB should PASS.
    query = "Tell me about food preference"
    print(f"\n🔍 Searching for: '{query}'")
    
    results = brain.search_memory(query, n_results=1)
    
    # Extract result
    found_text = results['documents'][0][0]
    found_meta = results['metadatas'][0][0]
    distance = results['distances'][0][0] # Lower distance = Better match
    
    print(f"👉 Found: \"{found_text}\"")
    print(f"   (Role: {found_meta['role']})")
    
    if "pizza" in found_text:
        print("🎉 SUCCESS! AURA understood that 'pizza' is 'food'.")
    else:
        print("❌ FAILED. AURA did not connect the concepts.")

    # 4. Another Test
    query2 = "What tech stack do I like?"
    print(f"\n🔍 Searching for: '{query2}'")
    results2 = brain.search_memory(query2, n_results=1)
    print(f"👉 Found: \"{results2['documents'][0][0]}\"")

if __name__ == "__main__":
    test_brain()