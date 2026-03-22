import os
import sys
import subprocess
import datetime
from io import StringIO
from tools.base import StorageTool
from rich.console import Console
from rich.table import Table

class NoteTool(StorageTool):
    def __init__(self):
        super().__init__("notes.json")
        self.name = "NoteTool"
        self.description = "Advanced Notes: Add, List, Modify, Delete, Open."
        self.category = "Productivity"

    # ✅ FIXED: Explicit arguments for the Registry Menu
    def execute(self, action: str = "list", content: str = "", id: str = None):
        """
        params:
        - action (str): The command (add, list, modify, delete, open).
        - content (str): The text content of the note (used for 'add' or 'modify').
        - id (str): The ID number of the note (used for 'modify', 'delete').
        """
        action = action.lower()
        note_id = id

        data = self._load_data()

        # 1. ADD
        if action == 'add':
            if not content: return "❌ Error: Content is empty."
            entry = {
                "id": len(data) + 1,
                "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
                "content": content
            }
            data.append(entry)
            self._save_data(data)
            return f"✅ Note saved! (ID: {len(data)})"

        # 2. LIST (Capture Table to String)
        elif action == 'list':
            if not data: return "📂 Notebook is empty."
            
            capture_buffer = StringIO()
            temp_console = Console(file=capture_buffer, force_terminal=True)
            
            table = Table(title="📒 Personal Notes", show_header=True, header_style="bold magenta")
            table.add_column("ID", style="cyan", width=4)
            table.add_column("Time", style="dim", width=20)
            table.add_column("Content", style="white")

            for i, note in enumerate(data, 1):
                time_str = str(note.get('timestamp', ''))
                content_str = str(note.get('content', ''))
                table.add_row(str(i), time_str, content_str)

            temp_console.print(table)
            return capture_buffer.getvalue()

        # 3. MODIFY
        elif action == 'modify':
            if not note_id: return "❌ Error: Provide 'id'."
            try:
                idx = int(note_id) - 1
                if 0 <= idx < len(data):
                    data[idx]['content'] = content
                    data[idx]['timestamp'] += " (edited)"
                    self._save_data(data)
                    return f"✏️ Note {note_id} updated."
                return "❌ ID not found."
            except: return "❌ ID must be a number."

        # 4. DELETE
        elif action == 'delete':
            if not note_id: return "❌ Error: Provide 'id'."
            try:
                idx = int(note_id) - 1
                if 0 <= idx < len(data):
                    removed = data.pop(idx)
                    self._save_data(data)
                    return f"🗑️ Deleted: '{removed.get('content', 'Unknown')}'"
                return "❌ ID not found."
            except: return "❌ ID must be a number."

        # 5. OPEN
        elif action == 'open':
            try:
                if os.name == 'nt': 
                    os.startfile(self.filepath)
                elif hasattr(sys, 'getandroidapilevel') or 'ANDROID_ROOT' in os.environ:
                    subprocess.call(['termux-open', self.filepath])
                else: 
                    opener = "open" if sys.platform == "darwin" else "xdg-open"
                    subprocess.call([opener, self.filepath])
                return "🖥️ Opening editor..."
            except Exception as e:
                return f"❌ Error opening file: {e}"

        return "❌ Unknown action. Use: add, list, modify, delete, open"