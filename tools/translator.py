import json
import os
from tools.base import Tool

# Try to import the library
try:
    from deep_translator import GoogleTranslator
    HAS_LIB = True
except ImportError:
    HAS_LIB = False

CACHE_FILE = "data/languages.json"

# ==========================================
# 🧠 SMART ALIAS LIST (The Fix)
# ==========================================
# We manually map common "wrong" codes to the "correct" Google codes
MANUAL_ALIASES = {
    "chinese": "zh-CN",
    "zh": "zh-CN",
    "mandarin": "zh-CN",
    "japanese": "ja",
    "jp": "ja",
    "hindi": "hi",
    "spanish": "es",
    "french": "fr",
    "german": "de",
    "russian": "ru"
}

def get_language_map():
    """Loads language codes and merges them with our manual aliases."""
    lang_map = {}
    
    # 1. Load from Cache or Download
    if HAS_LIB:
        if os.path.exists(CACHE_FILE):
            try:
                with open(CACHE_FILE, 'r') as f:
                    lang_map = json.load(f)
            except: pass
        
        if not lang_map:
            try:
                # Download fresh list
                lang_map = GoogleTranslator().get_supported_languages(as_dict=True)
                os.makedirs("data", exist_ok=True)
                with open(CACHE_FILE, 'w') as f:
                    json.dump(lang_map, f)
            except: pass

    # 2. 🛡️ FORCE MERGE ALIASES (This fixes your error)
    # This ensures 'zh' -> 'zh-CN' even if Google didn't send it.
    lang_map.update(MANUAL_ALIASES)
    
    return lang_map

# Load once
LANG_MAP = get_language_map()

# ==========================================
# 🛠️ TRANSLATOR TOOL
# ==========================================
class TranslatorTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "TranslatorTool"
        self.description = "Translate text (e.g. 'Hello' to Chinese/Spanish). ONLY use this if the user explicitly asks to 'Translate' text."
        self.category = "General"

    def _resolve_code(self, user_lang):
        """Helper to find the correct code (e.g. 'zh' -> 'zh-CN')"""
        clean = user_lang.lower().strip()
        
        # 1. Direct Lookup (e.g. 'chinese' -> 'zh-CN')
        if clean in LANG_MAP:
            return LANG_MAP[clean]
            
        # 2. Reverse Lookup (e.g. user typed 'fr', check if it's a valid value)
        if clean in LANG_MAP.values():
            return clean
            
        return clean # Hope for the best

    # ✅ EXPLICIT TYPE HINTING
    def execute(self, text: str, lang: str = "en"):
        """
        params:
        - text (str): The sentence to translate.
        - lang (str): Target language (e.g. "Chinese", "es", "Japanese").
        """
        if not HAS_LIB:
            return "❌ Error: Library missing. Run `pip install deep-translator`"
            
        if not text: return "❌ Error: No text provided."

        try:
            # Fix the code before sending (The Magic Step)
            target_code = self._resolve_code(lang)
            
            translator = GoogleTranslator(source='auto', target=target_code)
            result = translator.translate(text)
            
            return f"🗣️ **Translation ({target_code}):**\n{result}"
            
        except Exception as e:
            return f"❌ Error: Could not translate to '{lang}' (Try using the full name like 'Simplified Chinese')."