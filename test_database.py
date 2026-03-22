from AURA_Memory.sql_memory import DatabaseManager

def test_system():
    print("🚀 STARTING DATABASE TEST...\n")
    
    # 1. Initialize DB
    db = DatabaseManager("test_aura.db")
    
    # 2. Start a Conversation
    conv_id = db.start_conversation(title="Day 1 Test Chat")
    print(f"✅ Conversation Started (ID: {conv_id})")
    
    # 3. Add Messages
    print("📝 Saving messages...")
    db.add_message(conv_id, "user", "Hello AURA, my name is Pratyay.")
    db.add_message(conv_id, "assistant", "Hello Pratyay! Nice to meet you.")
    db.add_message(conv_id, "user", "I love coding in Python.")
    db.add_message(conv_id, "assistant", "Python is a great language!")
    
    # 4. Retrieve History
    print("\n📜 Retrieving History:")
    history = db.get_history(conv_id)
    for msg in history:
        print(f"  [{msg['role'].upper()}]: {msg['content']}")
        
    if len(history) == 4:
        print("✅ History retrieval passed!")
    else:
        print("❌ History retrieval FAILED.")

    # 5. Test Preferences
    print("\n🧠 Testing Memory (Preferences)...")
    db.save_preference("favorite_language", "Python")
    saved_val = db.get_preference("favorite_language")
    
    if saved_val == "Python":
        print(f"✅ Preference Saved & Retrieved: {saved_val}")
    else:
        print("❌ Preference test FAILED.")

    # 6. Simple Search
    print("\n🔍 Testing Search...")
    results = db.search_messages("coding")
    if results:
        print(f"✅ Found {len(results)} message(s) containing 'coding'")
    else:
        print("❌ Search FAILED.")

    print("\n🎉 DAY 1 COMPLETE: Database System is operational!")

if __name__ == "__main__":
    test_system()