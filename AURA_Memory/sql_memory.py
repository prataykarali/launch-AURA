import sqlite3
import os
from datetime import datetime

class DatabaseManager:
    def __init__(self, db_filename="aura_memory.db"):
        # 1. Store the name (Fixes the AttributeError)
        self.db_name = db_filename
        
        # 2. Calculate Paths
        # script_dir = .../AURA-Proj/AURA_Memory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        
        # data_dir = .../AURA-Proj/Data
        self.data_dir = os.path.join(os.path.dirname(script_dir), "Data")
        
        # schema_path = .../AURA-Proj/AURA_Memory/schema.sql
        self.schema_path = os.path.join(script_dir, "schema.sql")
        
        # 3. Create 'Data' folder if it is missing
        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)
            print(f"📁 Created missing Data directory at: {self.data_dir}")

        # 4. Set full path for the DB file
        self.db_path = os.path.join(self.data_dir, db_filename)
        
        self.initialize_db()

    def connect(self):
        """Establish connection using the FULL PATH"""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self.conn

    def initialize_db(self):
        """Create tables if they don't exist using schema.sql"""
        # Robust check using absolute path
        if not os.path.exists(self.schema_path):
            print(f"❌ Error: schema.sql not found at {self.schema_path}")
            return

        with self.connect() as conn:
            with open(self.schema_path, "r") as f:
                conn.executescript(f.read())
            
            # Create a default user if none exists
            cursor = conn.cursor()
            cursor.execute("INSERT OR IGNORE INTO users (username) VALUES (?)", ("default_user",))
            conn.commit()
            print(f"✅ Database {self.db_name} initialized successfully.")

    def start_conversation(self, user_id=1, title="New Chat"):
        """Start a new conversation session"""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO conversations (user_id, title) VALUES (?, ?)", 
                (user_id, title)
            )
            return cursor.lastrowid

    def add_message(self, conversation_id, role, content):
        """Save a message to the database"""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO messages (conversation_id, role, content) VALUES (?, ?, ?)",
                (conversation_id, role, content)
            )
            # Update last_active_at in conversation
            cursor.execute(
                "UPDATE conversations SET last_active_at = CURRENT_TIMESTAMP WHERE conversation_id = ?",
                (conversation_id,)
            )
            return cursor.lastrowid

    def get_history(self, conversation_id, limit=10):
        """Retrieve recent messages"""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT role, content, timestamp 
                FROM messages 
                WHERE conversation_id = ? 
                ORDER BY timestamp ASC 
                LIMIT ?
            """, (conversation_id, limit))
            return [dict(row) for row in cursor.fetchall()]

    def save_preference(self, key, value, user_id=1):
        """Save a fact about the user (e.g., favorite_color)"""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT pref_id FROM user_preferences WHERE user_id = ? AND key = ?",
                (user_id, key)
            )
            existing = cursor.fetchone()
            
            if existing:
                cursor.execute(
                    "UPDATE user_preferences SET value = ? WHERE pref_id = ?",
                    (value, existing['pref_id'])
                )
            else:
                cursor.execute(
                    "INSERT INTO user_preferences (user_id, key, value) VALUES (?, ?, ?)",
                    (user_id, key, value)
                )

    def get_preference(self, key, user_id=1):
        """Retrieve a specific fact"""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT value FROM user_preferences WHERE user_id = ? AND key = ?",
                (user_id, key)
            )
            row = cursor.fetchone()
            return row['value'] if row else None

    def search_messages(self, query):
        """Basic text search (We will upgrade this to Vector Search tomorrow)"""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT content, timestamp FROM messages WHERE content LIKE ?",
                (f'%{query}%',)
            )
            return [dict(row) for row in cursor.fetchall()]