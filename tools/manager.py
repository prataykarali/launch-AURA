import datetime
from tools.base import Tool
# Fix your imports to match your actual file names!

try:

    from tools.note_taker import NoteTool

    from tools.Todo_tool import TodoTool # Check capitalization in your folder



except ImportError:

    # Fallback if specific tools aren't found, prevents crash

    print("⚠️ Warning: NoteTool or TodoTool not found. Manager will run with limited features.")

    NoteTool = None

    TodoTool = None
    
class WorkflowManager(Tool):
    def __init__(self):
        super().__init__()
        self.name = "WorkflowManager"
        self.description = "Safely handles all Todo and Note updates."
        self.category = "System"
        self.toolkit = {
            "todotool": TodoTool() if TodoTool else None,
            "notetool": NoteTool() if NoteTool else None
        }

    def execute(self, bundle=None, **kwargs):
        # If the LLM sends a single task instead of a bundle, wrap it
        if not bundle:
            # Check if LLM sent loose params instead of a bundle
            if 'name' in kwargs:
                bundle = [kwargs]
            else:
                return "✅ Manager: No tasks provided."

        final_results = ["\n📁 **FILE ORGANIZATION REPORT**\n━━━━━━━━━━━━━━━━━━━━"]

        for i, task in enumerate(bundle, 1):
            name = task.get('name', '').lower()
            params = task.get('params', task) # Fallback to task itself if no 'params' key
            
            # 🛡️ FIX HALLUCINATIONS: Force 'add' if the user meant to add
            if "add" in str(params).lower() or "create" in str(params).lower():
                params['action'] = 'add'
            
            tool = self.toolkit.get(name)
            if tool:
                try:
                    # Filter params to match tool's execute method
                    import inspect
                    sig = inspect.signature(tool.execute)
                    valid_params = {k: v for k, v in params.items() if k in sig.parameters}
                    
                    result = tool.execute(**valid_params)
                    final_results.append(f"🔹 Step {i} [{name}]: {result}")
                except Exception as e:
                    final_results.append(f"❌ Step {i} Failed: {e}")
            else:
                final_results.append(f"⚠️ Unknown Tool: {name}")

        return "\n".join(final_results)