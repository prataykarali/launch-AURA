import pkgutil
import importlib
import inspect
import sys
import json  # Added json for printing the menu nicely
from datetime import datetime 
import tools 
from tools.base import Tool 
from tools.manager import WorkflowManager 
from concurrent.futures import ThreadPoolExecutor, as_completed

# 🛑 DISABLE OUTPUT BUFFERING
sys.stdout.reconfigure(line_buffering=True)

class ToolRegistry:
    def __init__(self, max_workers=10):  
        self.tool_classes = {}
        self.executor = ThreadPoolExecutor(max_workers=max_workers, thread_name_prefix="Agent")

    def register_all(self):
        package_path = tools.__path__
        package_name = tools.__name__
        
        for _, module_name, _ in pkgutil.iter_modules(package_path):
            try:
                module = importlib.import_module(f"{package_name}.{module_name}")
                for name, obj in inspect.getmembers(module):
                    if inspect.isclass(obj) and issubclass(obj, Tool) and obj is not Tool:
                        self.tool_classes[obj.__name__.lower()] = obj
            except Exception as e:
                print(f"⚠️  Skipped {module_name}: {e}")
        
        # Explicitly Register the Manager
        self.tool_classes['workflowmanager'] = WorkflowManager

    # ✅ NEW: THIS IS THE MENU GENERATOR FOR THE LLM
    def get_registry_menu(self):
        """
        📖 MENU GENERATOR: Creates the System Prompt for the LLM.
        It describes every tool and exactly what arguments they need.
        """
        menu = []
        
        for name, tool_cls in self.tool_classes.items():
            # Skip the internal manager (LLM doesn't need to know about it)
            if name == 'workflowmanager': continue
            
            # 1. Get the tool instance
            try:
                tool = tool_cls()
            except:
                continue 
            
            # Skip passive tools from the menu (they run automatically)
            if getattr(tool, 'category', '') == 'Passive':
                continue
            
            # 2. Inspect the 'execute' method signature to find arguments
            method = tool.execute
            sig = inspect.signature(method)
            
            # 3. Build the Parameters Schema
            params_dict = {}
            for param_name, param in sig.parameters.items():
                if param_name == 'self': continue # Skip 'self'
                if param_name == 'kwargs': continue # Skip kwargs if present
                
                # Default to string if no type hint
                param_type = "string"
                if param.annotation == int: param_type = "integer"
                if param.annotation == bool: param_type = "boolean"
                if param.annotation == float: param_type = "number"
                
                params_dict[param_name] = {
                    "type": param_type,
                    "required": param.default == inspect.Parameter.empty
                }

            # 4. Add to the Menu
            entry = {
                "tool_name": tool.name,
                "description": tool.description,
                "arguments": params_dict
            }
            menu.append(entry)
            
        return menu

    def get_tool_category(self, tool_name):
        tool_cls = self.tool_classes.get(tool_name.lower())
        if tool_cls:
            try:
                temp = tool_cls()
                return getattr(temp, 'category', 'General')
            except:
                return 'General'
        return 'Unknown'

    def get_passive_tools(self):
        """Returns list of tools marked as passive (always run alongside other tools)"""
        passive = []
        for name, tool_cls in self.tool_classes.items():
            try:
                temp = tool_cls()
                if getattr(temp, 'category', '') == 'Passive':
                    passive.append(name)
            except:
                pass
        return passive

    def execute_task(self, task_name, params, execution_id):
        start_time = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"🟢 [STARTED] Task #{execution_id} ({task_name}) at {start_time}", flush=True)

        # 1. Normalize the name and handle Aliases
        clean_name = task_name.lower().strip()
        
        # 🛡️ INTERNAL ALIAS FIXER (Add this to handle LLM quirks)
        alias_map = {
            "webtool": "websearchtool",
            "calculator": "calc_expression",
            "math": "calc_expression"
        }
        clean_name = alias_map.get(clean_name, clean_name)

        tool_cls = self.tool_classes.get(clean_name)
        if not tool_cls:
            return f"❌ Tool '{task_name}' not found."

        try:
            # 🛡️ PARAMETER FIXER: Handle common LLM key mistakes
            # Fix UnitConverter: 'from' -> 'from_unit'
            if "from" in params:
                params["from_unit"] = params.pop("from")
            if "to" in params:
                params["to_unit"] = params.pop("to")
            
            # Fix Reminder: 'time' -> 'at'
            if "reminder" in clean_name and "time" in params:
                params["at"] = params.pop("time")

            # Initialize and run
            instance = tool_cls()
            
            # We use inspect to only pass the arguments the tool actually accepts
            sig = inspect.signature(instance.execute)
            valid_params = {k: v for k, v in params.items() if k in sig.parameters}
            
            return instance.execute(**valid_params)
            
        except Exception as e:
            return f"❌ Error in {task_name}: {e}"
    
    def execute_task_with_user_input(self, task_name, params, execution_id, user_input=""):
        """Extended execute that can pass user_input to passive tools"""
        start_time = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"🟢 [STARTED] Task #{execution_id} ({task_name}) at {start_time}", flush=True)

        # 1. Normalize the name and handle Aliases
        clean_name = task_name.lower().strip()
        
        # 🛡️ INTERNAL ALIAS FIXER (Add this to handle LLM quirks)
        alias_map = {
            "webtool": "websearchtool",
            "calculator": "calc_expression",
            "math": "calc_expression"
        }
        clean_name = alias_map.get(clean_name, clean_name)

        tool_cls = self.tool_classes.get(clean_name)
        if not tool_cls:
            return f"❌ Tool '{task_name}' not found."

        try:
            # 🛡️ PARAMETER FIXER: Handle common LLM key mistakes
            # Fix UnitConverter: 'from' -> 'from_unit'
            if "from" in params:
                params["from_unit"] = params.pop("from")
            if "to" in params:
                params["to_unit"] = params.pop("to")
            
            # Fix Reminder: 'time' -> 'at'
            if "reminder" in clean_name and "time" in params:
                params["at"] = params.pop("time")

            # Add user_input for passive tools
            if user_input:
                params["user_input"] = user_input

            # Initialize and run
            instance = tool_cls()
            
            # We use inspect to only pass the arguments the tool actually accepts
            sig = inspect.signature(instance.execute)
            valid_params = {k: v for k, v in params.items() if k in sig.parameters}
            
            return instance.execute(**valid_params)
            
        except Exception as e:
            return f"❌ Error in {task_name}: {e}"
            
    def run_smart_swarm(self, raw_tasks, user_input=""):
        print(f"\n🚀 System Received {len(raw_tasks)} Raw Tasks...", flush=True)
        
        parallel_pool = []
        sequential_bundle = []
        passive_tools = self.get_passive_tools()
        
        # 1. SORTING HAT LOGIC 🎩
        for task in raw_tasks:
            name = task['name']
            category = self.get_tool_category(name)
            
            # ROUTING: Productivity tools go to the Manager
            if category == "Productivity":
                sequential_bundle.append(task)
            elif category == "Passive":
                continue  # Passive tools are injected automatically
            else:
                parallel_pool.append(task)
        
        # 2. INJECT PASSIVE TOOLS (always run alongside everything)
        for passive_tool in passive_tools:
            passive_task = {
                "name": passive_tool, 
                "params": {"user_input": user_input}
            }
            parallel_pool.append(passive_task)

        final_execution_list = list(parallel_pool)
        
        # 3. BUNDLE PRODUCTIVITY TASKS
        if sequential_bundle:
            print(f"👉 Detected {len(sequential_bundle)} Productivity Tasks. Routing to Manager Agent.", flush=True)
            manager_task = {
                "name": "WorkflowManager",
                "params": {"bundle": sequential_bundle}
            }
            final_execution_list.append(manager_task)

        # 4. EXECUTE
        print(f"🔥 Executing {len(final_execution_list)} threads (1 Manager + {len(parallel_pool)} Fast Workers)...\n", flush=True)
        print("─" * 60, flush=True)
        
        futures = {}
        for i, task in enumerate(final_execution_list):
            f = self.executor.submit(
                self.execute_task_with_user_input, 
                task['name'], 
                task.get('params', {}), 
                i+1,
                user_input
            )
            futures[f] = i+1

        # 5. STREAM RESULTS
        for future in as_completed(futures):
            task_id = futures[future]
            try:
                result = future.result()
                end_time = datetime.now().strftime("%H:%M:%S.%f")[:-3]
                
                output = (
                    f"🔔 [FINISHED] Task #{task_id} at {end_time}\n"
                    f"{result}\n"
                    f"────────────────────────────────────────────────────────────"
                )
                print(output, flush=True)
                
            except Exception as e:
                print(f"❌ [FAILED] Task #{task_id}: {e}", flush=True)

# --- Execution ---
if __name__ == "__main__":
    registry = ToolRegistry(max_workers=10)
    registry.register_all()

    # ==========================================
    # 📖 GENERATE THE MENU FOR THE LLM
    # ==========================================
    print("--- 🧠 GENERATING LLM SYSTEM PROMPT ---")
    menu = registry.get_registry_menu()
    
    # This JSON string is exactly what you will paste into your LLM System Prompt
    print(json.dumps(menu, indent=4))
    print("---------------------------------------\n")

    # [OPTIONAL] Run the swarm test below to ensure execution still works...
    user_input_tasks = [
        {"name": "UnitConverterTool", "params": {"amount": 1, "from": "btc", "to": "usd"}},
        # Add your other tasks here...
    ]

    # registry.run_smart_swarm(user_input_tasks)