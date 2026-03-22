from tools.base import Tool

class greet(Tool):
    def __init__(self):
        super().__init__()
        self.name = "greet"
        self.description = "Use this tool if user gives very first prompt or seem to be a chat"
        self.category = "Interaction"

    def execute(self, **kwargs):
        # Default to 'Traveller' if no name is provided
        name = kwargs.get('name', 'Traveller')
        t = int(kwargs.get('t', 1)) # Default to t=1 for active greeting
        
        if t == 0:
            return "🩵  AURA is active, Wanna Introduce Yourself? 😍"
        
        elif t == 1:
            # Logic: If name is 'Traveller', just say Hello Traveller.
            # If name is a real name (like 'Alice'), say Hello Traveller Alice.
            if name == 'Traveller':
                greeting = "Hello Traveller"
            else:
                greeting = f"Hello Traveller {name}"
            
            return f"{greeting}, It's a pleasure to meet you 😁"
        
        elif t == -1:
            return f"Hey stop Joking! 🫡. {name} is NOT a name"
        
        return "I'm AURA, I don't know yet and I'm curious to learn 😊"