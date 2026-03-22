import datetime
import requests
from tools.base import Tool

class WeatherTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "WeatherTool"
        self.description = "Get Live Weather. Robust Geocoding for neighborhoods (e.g., 'Newtown, Kolkata')."
        self.category = "Utility"

    def _get_condition_text(self, wmo_code):
        """Standard WMO Weather interpretation."""
        codes = {
            0: "Clear Sky ☀️", 1: "Mainly Clear 🌤️", 2: "Partly Cloudy ⛅", 3: "Overcast ☁️",
            45: "Fog 🌫️", 48: "Rime Fog 🌫️",
            51: "Light Drizzle 🌧️", 53: "Drizzle 🌧️", 55: "Dense Drizzle 🌧️",
            61: "Slight Rain ☔", 63: "Moderate Rain ☔", 65: "Heavy Rain ☔",
            71: "Snow ❄️", 73: "Moderate Snow ❄️", 75: "Heavy Snow ❄️",
            80: "Showers 🚿", 81: "Moderate Showers 🚿", 82: "Violent Showers ⛈️",
            95: "Thunderstorm ⚡", 96: "Thunderstorm + Hail ⛈️", 99: "Heavy Thunderstorm ⛈️"
        }
        return codes.get(wmo_code, "Unknown Conditions ❓")

    def _smart_geocode(self, user_query):
        """
        City-First Geocoding Strategy
        
        Philosophy: Neighborhoods aren't in databases, but cities ALWAYS are.
        
        Strategy:
        1. Identify if query has a recognizable city name
        2. Search for the CITY directly (most reliable)
        3. Fall back to full query only if no city detected
        4. Store neighborhood name for response display
        """
        user_query = user_query.lower().strip()
        original_query = user_query  # Store for neighborhood display
        
        # ============================================
        # UNIVERSAL CITY DETECTION STRATEGY
        # ============================================
        
        detected_city = None
        neighborhood = None
        
        # Clean up query
        query_clean = user_query.replace(',', ' ').strip()
        query_words = query_clean.split()
        
        # ============================================
        # STOPWORDS - NOT cities, but descriptors
        # ============================================
        # These words should NEVER be treated as cities
        LOCATION_STOPWORDS = {
            'pass', 'valley', 'range', 'mountain', 'peak', 'hill', 'lake',
            'river', 'beach', 'island', 'desert', 'forest', 'national', 'park',
            'station', 'airport', 'road', 'street', 'avenue', 'highway',
            'north', 'south', 'east', 'west', 'central', 'upper', 'lower',
            'weather', 'temperature', 'climate', 'forecast'
        }
        
        # ============================================
        # STRATEGY 1: COMMA-BASED PARSING (Most Reliable)
        # ============================================
        # Format: "Newtown, Kolkata" or "Brooklyn, New York"
        if ',' in user_query:
            parts = [p.strip() for p in user_query.split(',')]
            if len(parts) == 2:
                neighborhood = parts[0]
                detected_city = parts[1]
                print(f"🔍 Comma detected: neighborhood='{neighborhood}' | city='{detected_city}'")
            elif len(parts) > 2:
                # Format: "neighborhood, city, country" or "street, neighborhood, city"
                neighborhood = ', '.join(parts[:-1])
                detected_city = parts[-1]
                print(f"🔍 Multi-comma: neighborhood='{neighborhood}' | city='{detected_city}'")
        
        # ============================================
        # STRATEGY 2: KEYWORD DETECTION
        # ============================================
        # Words that indicate the next/previous word is a city
        CITY_INDICATORS = {
            'in', 'near', 'around', 'at', 'city', 'downtown', 'metro'
        }
        
        if not detected_city and len(query_words) > 1:
            for i, word in enumerate(query_words):
                if word in CITY_INDICATORS:
                    # City is likely the next word(s)
                    if i + 1 < len(query_words):
                        # Check if it's a multi-word city (e.g., "in New York")
                        if i + 2 < len(query_words) and query_words[i + 1] not in LOCATION_STOPWORDS:
                            # Try two-word city
                            two_word_city = f"{query_words[i + 1]} {query_words[i + 2]}"
                            detected_city = two_word_city
                            neighborhood = ' '.join([w for j, w in enumerate(query_words) 
                                                    if j != i and j != i + 1 and j != i + 2])
                            print(f"🔍 Keyword '{word}' + multi-word city: city='{detected_city}' | neighborhood='{neighborhood}'")
                            break
                        else:
                            # Single word city
                            detected_city = query_words[i + 1]
                            neighborhood = ' '.join([w for j, w in enumerate(query_words) if j != i and j != i + 1])
                            print(f"🔍 Keyword '{word}' detected: city='{detected_city}' | neighborhood='{neighborhood}'")
                            break
        
        # ============================================
        # STRATEGY 3: MULTI-WORD LOCATION HANDLING
        # ============================================
        # For queries like "Leh Ladakh", "Nathula Pass", treat as FULL location name
        # Don't try to split them unless there's clear indication
        if not detected_city and len(query_words) >= 2:
            # Check if last word is a stopword (e.g., "pass", "valley")
            last_word = query_words[-1].lower()
            
            if last_word in LOCATION_STOPWORDS:
                # Use the FULL query as location name (e.g., "Nathula Pass")
                detected_city = query_clean
                print(f"🔍 Multi-word location (with stopword): city='{detected_city}'")
            else:
                # Check if any word is a stopword - if so, keep everything together
                has_stopword = any(word.lower() in LOCATION_STOPWORDS for word in query_words)
                
                if has_stopword:
                    detected_city = query_clean
                    print(f"🔍 Contains stopword - using full name: city='{detected_city}'")
                else:
                    # Last word heuristic (only if no stopwords)
                    detected_city = query_words[-1]
                    neighborhood = ' '.join(query_words[:-1])
                    print(f"🔍 Last word heuristic: city='{detected_city}' | neighborhood='{neighborhood}'")
        
        # ============================================
        # STRATEGY 4: SINGLE WORD (Just the City)
        # ============================================
        if not detected_city and len(query_words) == 1:
            detected_city = query_words[0]
            print(f"🔍 Single word query: city='{detected_city}'")
        
        # ============================================
        # STRATEGY 5: FALLBACK - USE FULL QUERY
        # ============================================
        if not detected_city:
            detected_city = query_clean
            print(f"🔍 Fallback: using full query as city='{detected_city}'")
        
        print(f"🎯 Final decision: City='{detected_city}' | Neighborhood='{neighborhood or 'None'}'")
        
        # ============================================
        # STEP 2: PRIORITIZED SEARCH
        # ============================================

        # ============================================
        # HELPER: Multi-API Search Strategy
        # ============================================
        def search_google_geocoding(search_term):
            """
            Try Google's Geocoding API first (better coverage for obscure places)
            Fallback to Open-Meteo if Google fails
            """
            try:
                # Google's Geocoding API (free tier, no key needed for basic use)
                # Using Nominatim (OpenStreetMap) which is free and has great coverage
                url = "https://nominatim.openstreetmap.org/search"
                params = {
                    "q": search_term,
                    "format": "json",
                    "limit": 5,
                    "addressdetails": 1
                }
                headers = {"User-Agent": "WeatherTool/1.0"}  # Required by Nominatim
                
                res = requests.get(url, params=params, headers=headers, timeout=5)
                data = res.json()
                
                if data:
                    # Convert to our format
                    results = []
                    for item in data:
                        addr = item.get('address', {})
                        result = {
                            'name': item.get('display_name', '').split(',')[0],
                            'latitude': float(item.get('lat', 0)),
                            'longitude': float(item.get('lon', 0)),
                            'country': addr.get('country', ''),
                            'country_code': addr.get('country_code', '').upper(),
                            'admin1': addr.get('state', ''),
                            'admin2': addr.get('state_district', ''),
                            'display_name': item.get('display_name', ''),
                            '_source': 'nominatim'
                        }
                        results.append(result)
                    return results
            except Exception as e:
                print(f"   ⚠️ Nominatim failed: {e}")
            
            return []
        
        def search_open_meteo(search_term, count=10):
            """Fallback to Open-Meteo geocoding"""
            try:
                url = "https://geocoding-api.open-meteo.com/v1/search"
                params = {"name": search_term, "count": count, "format": "json"}
                res = requests.get(url, params=params, timeout=5).json()
                results = res.get("results", [])
                for r in results:
                    r['_source'] = 'open-meteo'
                return results
            except:
                return []
        
        # ============================================
        # STEP 3: EXECUTE MULTI-SOURCE SEARCH
        # ============================================
        candidates = []
        
        # Search for the detected city
        if detected_city:
            print(f"🌍 Searching for: '{detected_city}'")
            
            # TRY 1: Nominatim (OpenStreetMap) - Best coverage
            print(f"   🔍 Trying Nominatim (OpenStreetMap)...")
            candidates = search_google_geocoding(detected_city)
            
            if candidates:
                print(f"   ✅ Found {len(candidates)} results from Nominatim")
            else:
                # TRY 2: Open-Meteo as fallback
                print(f"   🔍 Trying Open-Meteo...")
                candidates = search_open_meteo(detected_city)
                if candidates:
                    print(f"   ✅ Found {len(candidates)} results from Open-Meteo")
            
            # RETRY STRATEGY: If full name fails, try individual words
            if not candidates and ' ' in detected_city:
                print(f"🔄 No results for full name, trying individual words...")
                
                words = detected_city.split()
                for word in reversed(words):  # Try from right to left (city usually last)
                    if word.lower() not in LOCATION_STOPWORDS and len(word) > 2:
                        print(f"   Trying: '{word}'")
                        
                        # Try Nominatim first
                        candidates = search_google_geocoding(word)
                        if not candidates:
                            candidates = search_open_meteo(word)
                        
                        if candidates:
                            print(f"   ✅ Found results for '{word}'")
                            # Store full original name for display
                            neighborhood = detected_city.replace(word, '').strip()
                            break
            
            # Show results
            if candidates:
                print(f"📍 Top {min(5, len(candidates))} results:")
                for i, cand in enumerate(candidates[:5], 1):
                    source = cand.get('_source', '?')
                    country = cand.get('country', 'Unknown')
                    admin1 = cand.get('admin1', '')
                    
                    # For Nominatim results, show display_name
                    if cand.get('display_name'):
                        display = cand.get('display_name')
                    else:
                        display = f"{cand.get('name')}"
                        if admin1:
                            display += f", {admin1}"
                        display += f", {country}"
                    
                    print(f"  {i}. [{source}] {display} [{cand.get('country_code', '??')}]")
                
                # Return the best match (first result is usually most relevant)
                result = candidates[0]
                result_name = result.get('display_name', result.get('name', 'Unknown'))
                print(f"  ✅ Selected: {result_name}")
                
                # Store neighborhood for display
                if neighborhood:
                    result['_neighborhood'] = neighborhood.title()
                
                return result
            else:
                print(f"  ❌ No results found for '{detected_city}'")
        
        # ============================================
        # FALLBACK: No results - provide helpful error
        # ============================================
        print(f"❌ Could not find location: '{user_query}'")
        return None

    def execute(self, city: str):
        """
        Main execution method for WeatherTool
        
        Args:
            city (str): Location query (e.g., "Newtown, Kolkata", "Mukundapur")
        
        Returns:
            str: Formatted weather report or error message
        """
        if not city:
            return "❌ Error: Please provide a location."

        # ============================================
        # STEP 1: GEOCODE THE LOCATION
        # ============================================
        loc = self._smart_geocode(city)
        
        if not loc:
            return f"❌ **Location Not Found:** I couldn't pinpoint '{city}'. Try adding the region/country (e.g., 'Mukundapur, India')."

        # ============================================
        # STEP 2: FETCH WEATHER DATA
        # ============================================
        try:
            w_url = "https://api.open-meteo.com/v1/forecast"
            params = {
                "latitude": loc["latitude"],
                "longitude": loc["longitude"],
                "timezone": loc.get("timezone", "auto"),
                "current": "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m",
                "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            }
            
            data = requests.get(w_url, params=params, timeout=5).json()
            curr = data.get("current", {})
            daily = data.get("daily", {})

            # ============================================
            # STEP 3: FORMAT THE REPORT
            # ============================================
            cond = self._get_condition_text(curr.get("weather_code"))
            temp = curr.get("temperature_2m")
            feels = curr.get("apparent_temperature")
            humidity = curr.get("relative_humidity_2m")
            wind = curr.get("wind_speed_10m")
            
            # Build location display
            city_name = loc.get("name")
            admin = loc.get("admin1") or loc.get("country")
            
            # If we detected a neighborhood, show it in the header
            neighborhood_info = loc.get('_neighborhood', '')
            if neighborhood_info:
                location_header = f"{neighborhood_info} ({city_name}), {admin}"
            else:
                location_header = f"{city_name}, {admin}"
            
            # Generate 3-day forecast
            forecast = ""
            for i in range(3):
                date_obj = datetime.datetime.strptime(daily["time"][i], "%Y-%m-%d")
                day = date_obj.strftime("%a")
                rain_chance = daily["precipitation_probability_max"][i]
                icon = "🌧️" if rain_chance > 40 else "☀️"
                max_temp = daily['temperature_2m_max'][i]
                min_temp = daily['temperature_2m_min'][i]
                forecast += f"📅 `{day}`: {icon} {max_temp}°/{min_temp}°\n"

            # ============================================
            # STEP 4: RETURN FORMATTED REPORT
            # ============================================
            return (
                f"🌍 **Live Weather: {location_header}**\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🌡️ **Now:** {temp}°C (Feels {feels}°C)\n"
                f"👀 **Condition:** {cond}\n"
                f"💧 **Humidity:** {humidity}% | 💨 **Wind:** {wind} km/h\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🔮 **3-Day Forecast:**\n{forecast}"
            )

        except Exception as e:
            return f"❌ Weather API Error: {e}"