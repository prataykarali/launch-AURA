import datetime
from tools.base import Tool

class TimeTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "TimeTool"
        self.description = "Get the current time."
        self.category = "Time"

    def format_dt(self, dt_obj):
        day = dt_obj.day
        if 11 <= day <= 13: suffix = "th"
        else: suffix = {1: 'st', 2: 'nd', 3: 'rd'}.get(day % 10, "th")
        
        date_part = dt_obj.strftime("%B, %Y")
        time_part = dt_obj.strftime("%I:%M%p").lower()
        if time_part.startswith("0"): time_part = time_part[1:]
            
        return f"{day}{suffix} {date_part} at {time_part}"

    # ✅ FIX: Add **kwargs to catch "city" or other hallucinations
    def execute(self, **kwargs):
        """
        params: None
        """
        # We ignore kwargs (like 'city') because we only check Local System Time
        now = datetime.datetime.now()
        return f"🕒 **Current Time:** {self.format_dt(now)}"