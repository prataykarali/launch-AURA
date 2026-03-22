import datetime
import os
import sys
import subprocess
from io import StringIO
from tools.base import StorageTool, Tool
from rich.console import Console
from rich.table import Table

# ==========================================
# 📝 TODO TOOL (Fuzzy & Robust Version)
# ==========================================
class TodoTool(StorageTool):
    def __init__(self):
        super().__init__("aura_todos.json")
        self.name = "TodoTool"
        self.description = "Advanced Task Manager: Add, List, Done, Modify, Delete, Open, Clear."
        self.category = "Productivity"

    def execute(self, action: str = "list", task: str = "", id: str = None):
        action = action.lower()
        if action == "create": action = "add"
        
        data = self._load_data()

        # 1. ➕ ADD
        if action == 'add':
            if not task: return "❌ Error: Provide task name."
            data.append({"task": task, "status": "pending", "created": datetime.datetime.now().strftime("%Y-%m-%d")})
            self._save_data(data)
            return f"✅ Added task: '{task}'"

        # 2. 🗑️ DELETE / DONE (Now supports BATCH delete)
        elif action in ['done', 'delete']:
            # Normalize query (lowercase and no underscores)
            query = (task or str(id or "")).lower().replace("_", " ").strip()
            
            if not query: return "❌ Error: What should I delete?"

            initial_count = len(data)
            
            if action == 'delete':
                # FILTER logic: keep only tasks that DON'T match the query
                new_data = [t for t in data if query not in t['task'].lower().replace("_", " ")]
                deleted_count = initial_count - len(new_data)
                
                if deleted_count > 0:
                    self._save_data(new_data)
                    return f"🗑️ Mass Cleanup: Removed {deleted_count} tasks matching '{query}'."
            
            else: # DONE (Just marks the first one found)
                for t in data:
                    if query in t['task'].lower().replace("_", " "):
                        t['status'] = 'done'
                        self._save_data(data)
                        return f"🎉 Marked '{t['task']}' as done!"
            
            return f"❌ Could not find any tasks matching '{query}'."

        # 3. 🧹 DEDUPE (Bonus: Removes all exact duplicates)
        elif action == 'dedupe':
            seen = set()
            new_data = []
            for t in data:
                if t['task'] not in seen:
                    new_data.append(t)
                    seen.add(t['task'])
            
            diff = len(data) - len(new_data)
            self._save_data(new_data)
            return f"🧼 Deduplication complete! Removed {diff} duplicate tasks."

        # 4. LIST
        elif action == 'list':
            if not data: return "📝 Todo list empty."
            capture_buffer = StringIO()
            temp_console = Console(file=capture_buffer, force_terminal=True)
            table = Table(title="📋 My Todo List", show_header=True, header_style="bold cyan")
            table.add_column("ID", style="dim", width=4)
            table.add_column("Status", justify="center", width=8)
            table.add_column("Task", style="white")

            pending_count = 0
            for i, t in enumerate(data, 1):
                is_done = t.get('status') == 'done'
                status_icon = "✅" if is_done else "🔲"
                style = "dim strike" if is_done else "bold white"
                if not is_done: pending_count += 1
                table.add_row(str(i), status_icon, t.get('task', ''), style=style)

            temp_console.print(table)
            temp_console.print(f"[dim]Remaining: {pending_count} tasks[/dim]")
            return capture_buffer.getvalue()

        # 5. MODIFY
        elif action == 'modify':
            if not id: return "❌ Error: Provide 'id'."
            try:
                idx = int(id) - 1
                if 0 <= idx < len(data):
                    old_task = data[idx]['task']
                    data[idx]['task'] = task
                    self._save_data(data)
                    return f"✏️ Updated ID {id}: '{old_task}' ➝ '{task}'"
                return "❌ ID not found."
            except: return "❌ ID must be a number."

        # 6. OPEN
        elif action == 'open':
            try:
                if os.name == 'nt': os.startfile(self.filepath)
                else:
                    opener = "open" if sys.platform == "darwin" else "xdg-open"
                    subprocess.call([opener, self.filepath])
                return "🖥️ Opening Todo list..."
            except Exception as e:
                return f"❌ Error opening file: {e}"

        return "❌ Unknown action. Use: add, list, done, modify, delete, clear, open"


# ==========================================
# ⏱️ TIMER TOOL (Fixed)
# ==========================================
class TimerTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "TimerTool"
        self.description = "Set a countdown timer in minutes."
        self.category = "Productivity"

    def execute(self, minutes: float = 0.0):
        """
        params:
        - minutes (float): countdown time (e.g., 5 or 0.5).
        """
        try:
            mins = float(minutes)
            if mins <= 0:
                return "❌ Error: Please provide a positive number of minutes."
            
            end_time = datetime.datetime.now() + datetime.timedelta(minutes=mins)
            time_str = end_time.strftime("%I:%M %p").lower().lstrip('0')
            
            return f"⏱️ Timer set for {mins} minutes. Rings at **{time_str}**."
        except (ValueError, TypeError):
            return "❌ Error: 'minutes' must be a number."