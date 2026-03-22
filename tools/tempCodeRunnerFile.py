# tools/base.py
import os
import json
class Tool:
    def __init__(self):
        self.name = ""
        self.description = ""
        self.category = ""

    def execute(self, **kwargs):
        raise NotImplementedError
    
class StorageTool(Tool):
    def __init__(self,filename):
        super().__init__()
        self.filepath = os.path.join("data", filename)
        self._ensure_file()
    
    def _ensure_file(self):
        if not os.path.exists(self.filepath):
            folder = os.path.dirname(self.filepath)
            if folder and not os.path.exists(folder):
                os.makedirs(folder)
            with open(self.filepath, 'w') as f:
                json.dump([], f)

    def _load_data(self):
        try:
            with open(self.filepath, 'r') as f:
                    return json.load(f)
        except:
                return []
            
    def _save_data(self, data):
            with open(self.filepath, 'w') as f:
               json.dump(data, f, indent=4)