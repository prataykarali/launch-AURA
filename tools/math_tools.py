from tools.base import Tool

# ==========================================
# 🧮 CALCULATOR TOOL (Smart Cleaning Version)
# ==========================================
class calc_expression(Tool):
    def __init__(self):
        super().__init__()
        self.name = "calc_expression"
        self.description = "Calculates math expressions (e.g. '5 times 10', '50/2')."
        self.category = "Mathematics"

    def solve(self, expression_str):
        """
        PURE LOGIC: Cleans natural language math and returns a number.
        """
        if not expression_str:
            return None
            
        # 1. SMART CLEANING 🧼 (Fixes LLM quirks)
        expr = str(expression_str).lower()
        expr = expr.replace(" times ", "*").replace(" x ", "*")
        expr = expr.replace(" divided by ", "/").replace(" over ", "/")
        expr = expr.replace(" plus ", "+").replace(" minus ", "-")
        
        # 2. Filter dangerous characters (Security)
        allowed_chars = "0123456789+-*/.() "
        clean_expr = "".join([char for char in expr if char in allowed_chars]).strip()
        
        if not clean_expr:
            return None
            
        try:
            # 3. Eval is safe-ish because we stripped all letters
            return eval(clean_expr)
        except Exception:
            return None

    # ✅ EXPLICIT TYPE HINTING (Crucial for Registry Menu)
    def execute(self, expression: str):
        """
        params:
        - expression (str): The math string to solve (e.g., "5 times 10")
        """
        # Call internal logic
        result = self.solve(expression)
        
        if result is None:
            return "That expression is a bit tangled! 🤦‍♀️ (Try: '5 * 10')"
            
        return f"The answer is 📱: {result}"


# ==========================================
# 🔢 EVEN/ODD CHECKER TOOL
# ==========================================
class check_even_odd(Tool):
    def __init__(self):
        super().__init__()
        self.name = "check_even_odd"
        self.description = "Checks if a number is even or odd."
        self.category = "Mathematics"

    def is_even(self, value):
        """
        PURE LOGIC: Returns True/False
        """
        try:
            n = int(value)
            return n % 2 == 0
        except ValueError:
            return None

    # ✅ EXPLICIT TYPE HINTING
    def execute(self, user_input: str):
        """
        params:
        - user_input (str): The text containing the number (e.g., "Is 50 even?")
        """
        # Extract just digits (Handles "Is 50 even?" -> "50")
        nums = "".join([c for c in str(user_input) if c.isdigit()]).strip()
        
        if not nums:
            return "I need a number to check! 🔢"

        # Call logic
        result = self.is_even(nums)
        
        if result is True:
            return f"{nums} is Even 😊"
        elif result is False:
            return f"{nums} is Odd 😊"
        else:
            return "That doesn't look like a valid number."