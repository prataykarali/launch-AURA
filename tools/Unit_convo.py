import json
import os
import time
import requests
from tools.base import Tool

# ==========================================
# 💸 INTELLIGENT CONVERTER (Real-Time Crypto)
# ==========================================
class UnitConverterTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "UnitConverterTool"
        self.description = "Convert Units, Money & Crypto (Live 5-min Cache)."
        self.category = "Utility"
        self.aliases = ["convert", "exchange"]
        
        # 📂 1. STATIC UNITS (Physics)
        self.conversions = {
            ("c", "f"): lambda x: (x * 9/5) + 32,
            ("f", "c"): lambda x: (x - 32) * 5/9,
            ("km", "miles"): lambda x: x * 0.621371,
            ("miles", "km"): lambda x: x / 0.621371,
            ("m", "ft"): lambda x: x * 3.28084,
            ("ft", "m"): lambda x: x / 3.28084,
            ("cm", "in"): lambda x: x * 0.393701,
            ("in", "cm"): lambda x: x / 0.393701,
            ("kg", "lbs"): lambda x: x * 2.20462,
            ("lbs", "kg"): lambda x: x / 2.20462,
        }

        # 🧠 2. DYNAMIC RATES
        self.rates_file = "data/rates.json"
        self.currency_rates = self._get_currency_rates()
        
        # 🗺️ 3. KNOWLEDGE BASE
        self.map_file = "data/currency_map.json"
        self.currency_map = self._load_learned_memory()
        self.ignored_codes = {'ALL', 'TRY', 'GET', 'SET', 'NEW', 'MAN', 'ARE', 'CAN', 'BET', 'WON', 'ONE', 'USE', 'FOR', 'AND', 'THE', 'OF', 'CUP'}

        # 🛡️ 4. THE IMMUTABLE TRUTH
        self.hardcoded_truth = {
            "btc": "BTC", "bitcoin": "BTC", "sats": "BTC",
            "eth": "ETH", "ethereum": "ETH",
            "doge": "DOGE", "dogecoin": "DOGE",
            "usd": "USD", "eur": "EUR", "jpy": "JPY", "gbp": "GBP", "inr": "INR", 
            "aud": "AUD", "cad": "CAD", "chf": "CHF", "cny": "CNY", "sek": "SEK", 
            "nzd": "NZD", "mxn": "MXN", "sgd": "SGD", "hkd": "HKD", "krw": "KRW", 
            "rub": "RUB", "brl": "BRL", "zar": "ZAR", "jmd": "JMD", "xpf": "XPF",
            "ron": "RON", "cop": "COP", "aed": "AED", "sar": "SAR", "try": "TRY", 
            "idr": "IDR", "thb": "THB", "myr": "MYR", "vnd": "VND", "php": "PHP", 
            "pln": "PLN", "mga": "MGA", "pkr": "PKR", "bdt": "BDT", "lkr": "LKR", 
            "mvr": "MVR", "mnt": "MNT", "btn": "BTN", "pgk": "PGK", "srd": "SRD", 
            "zwl": "ZWL", "egp": "EGP", "irr": "IRR",
            
            "dollar": "USD", "euro": "EUR", "yen": "JPY", "pound": "GBP", "rupee": "INR",
            "buck": "USD", "bucks": "USD", "quid": "GBP", "loonie": "CAD",
            
            "usa": "USD", "uk": "GBP", "japan": "JPY", "india": "INR", "china": "CNY",
            "germany": "EUR", "france": "EUR", "italy": "EUR", "spain": "EUR",
            "australia": "AUD", "australlia": "AUD", "canada": "CAD",
            "mexico": "MXN", "colombia": "COP", "brazil": "BRL", "south africa": "ZAR", 
            "egypt": "EGP", "iran": "IRR",
            "romania": "RON", "liechtenstein": "CHF", "switzerland": "CHF",
            "jamaica": "JMD", "tahiti": "XPF", "vietnam": "VND", "thailand": "THB",
            "dubai": "AED", "korea": "KRW", "russia": "RUB", "zimbabwe": "ZWL",
            "madagascar": "MGA", "pakistan": "PKR", "fiji": "FJD",
            "maldives": "MVR", "mongolia": "MNT", "bhutan": "BTN",
            "papua new guinea": "PGK", "suriname": "SRD"
        }

        # 📖 5. SEMANTIC MATCHING
        self.name_to_code = {
            "bitcoin": "BTC", "ethereum": "ETH", "dogecoin": "DOGE",
            "jamaican dollar": "JMD", "hong kong dollar": "HKD", "singapore dollar": "SGD",
            "australian dollar": "AUD", "canadian dollar": "CAD", "new zealand dollar": "NZD",
            "zimbabwe dollar": "ZWL", "cfp franc": "XPF", "swiss franc": "CHF",
            "mexican peso": "MXN", "philippine peso": "PHP", "colombian peso": "COP",
            "united states dollar": "USD", "euro": "EUR", "pound sterling": "GBP",
            "japanese yen": "JPY", "indian rupee": "INR", "won": "KRW", "yuan": "CNY",
            "ruble": "RUB", "real": "BRL", "malagasy ariary": "MGA", "romanian leu": "RON",
        }

    def _get_currency_rates(self):
        """
        ⚡ SMART CACHING STRATEGY (High Frequency):
        - Cache expires in 5 MINUTES (300s).
        - Keeps Bitcoin prices fresh.
        """
        rates = {}
        CACHE_DURATION = 300  # 👈 UPDATED: 5 Minutes
        file_exists = os.path.exists(self.rates_file)
        
        # 1. Try to load Cache
        if file_exists:
            try:
                last_modified = os.path.getmtime(self.rates_file)
                # If cache is fresh (less than 5 mins old)
                if (time.time() - last_modified) < CACHE_DURATION:
                    with open(self.rates_file, 'r') as f:
                        data = json.load(f)
                        if "rates" in data and len(data["rates"]) > 10:
                            return data["rates"]
            except: pass

        print("🌐 Downloading Fresh Rates (Fiat + Crypto)...")
        
        # 2. Fetch Fiat
        try:
            url = "https://api.exchangerate-api.com/v4/latest/USD"
            data = requests.get(url, timeout=3).json()
            rates.update(data.get("rates", {}))
        except:
            print("⚠️ Primary API failed. Trying Backup...")
            try:
                url = "https://open.er-api.com/v6/latest/USD"
                data = requests.get(url, timeout=3).json()
                rates.update(data.get("rates", {}))
            except:
                print("❌ ALL Fiat APIs failed.")

        # 3. Fetch Crypto (CoinGecko)
        try:
            # Simple price endpoint is robust and free
            crypto_url = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,dogecoin&vs_currencies=usd"
            c_data = requests.get(crypto_url, timeout=3).json()
            
            # Convert Price to Rate (1 USD = X Crypto)
            if "bitcoin" in c_data: rates["BTC"] = 1 / c_data["bitcoin"]["usd"]
            if "ethereum" in c_data: rates["ETH"] = 1 / c_data["ethereum"]["usd"]
            if "dogecoin" in c_data: rates["DOGE"] = 1 / c_data["dogecoin"]["usd"]
        except:
            print("⚠️ Crypto API failed.")

        # 4. Save Cache
        if len(rates) > 0:
            os.makedirs("data", exist_ok=True)
            with open(self.rates_file, 'w') as f:
                json.dump({"rates": rates}, f)
        elif file_exists:
            # Use old cache if internet is down
            try:
                with open(self.rates_file, 'r') as f:
                    return json.load(f).get("rates", {})
            except: pass
            
        return rates

    def _load_learned_memory(self):
        if os.path.exists(self.map_file):
            try:
                with open(self.map_file, 'r') as f:
                    return json.load(f)
            except: pass
        return {}

    def _resolve_currency(self, query):
        q = query.lower().strip()
        if q in self.hardcoded_truth: return self.hardcoded_truth[q]
        if q in self.currency_map: return self.currency_map[q]
        if q.upper() in self.currency_rates: return q.upper()
        return None 

    def execute(self, amount: float, from_unit: str, to_unit: str, action: str = None):
        """
        Convert between units, currencies, and cryptocurrencies.
        
        Args:
            amount: The numeric value to convert
            from_unit: Source unit/currency (e.g., 'usd', 'btc', 'celsius', 'km')
            to_unit: Target unit/currency (e.g., 'eur', 'eth', 'fahrenheit', 'miles')
            action: Optional action (e.g., 'list' to see supported conversions)
        """
        if action == 'list':
            return "⚖️ Supports: Physics & Smart Currency."

        try:
            amount = float(amount)
            from_u = str(from_unit).lower().strip().rstrip('s')
            to_u = str(to_unit).lower().strip().rstrip('s')
            
            if not from_u or not to_u:
                return "❌ Error: Must specify both 'from_unit' and 'to_unit'."
        except ValueError:
            return "❌ Error: Amount must be a number."
        except Exception as e:
            return f"❌ Error: {str(e)}"

        # LOGIC 1: PHYSICS
        phys_aliases = {"kilometer": "km", "mile": "miles", "kilogram": "kg", "pound": "lbs", "celsius": "c", "fahrenheit": "f"}
        p_from = phys_aliases.get(from_u, from_u)
        p_to = phys_aliases.get(to_u, to_u)

        if (p_from, p_to) in self.conversions:
            res = self.conversions[(p_from, p_to)](amount)
            return f"⚖️ **Physics:** {amount} {p_from.upper()} = {res:.2f} {p_to.upper()}"

        # LOGIC 2: SMART CURRENCY
        code_from = self._resolve_currency(from_u)
        code_to = self._resolve_currency(to_u)

        if code_from and code_to:
            if code_from not in self.currency_rates: return f"❌ Error: Rate missing for {code_from}."
            if code_to not in self.currency_rates: return f"❌ Error: Rate missing for {code_to}."

            rate_from = self.currency_rates[code_from]
            rate_to = self.currency_rates[code_to]
            
            # 🛑 DIRECT MATH (Faster & Safer than Tool Call)
            final_amount = amount * (rate_to / rate_from)
            
            # Smart Formatting (8 decimals for Crypto, 2 for Fiat)
            is_crypto = (final_amount < 0.01) or (code_to in ['BTC', 'ETH', 'DOGE'])
            fmt = "{:,.8f}" if is_crypto else "{:,.2f}"
            
            return (
                f"💸 **Smart Exchange:**\n"
                f"From: {code_from} ({from_u.title()})\n"
                f"To:   {code_to} ({to_u.title()})\n"
                f"━━━━━━━━━━━━━━━━\n"
                f"💰 **{amount} {code_from} = {fmt.format(final_amount)} {code_to}**"
            )

        return f"❌ Could not determine currency for: '{from_u}' or '{to_u}'."