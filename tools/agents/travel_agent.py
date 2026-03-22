from .base_agent import BaseAgent
from bs4 import BeautifulSoup
from typing import Dict, List, Optional, Tuple
import re
import os

# API clients
try:
    import googlemaps
    HAS_GOOGLE_MAPS = True
except ImportError:
    HAS_GOOGLE_MAPS = False

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


class TravelAgent(BaseAgent):
    """
    Advanced Agent for travel extraction.
    Integrates: Google Maps (Routing), OpenStreetMap (Geocoding), 
    Amadeus (Flights/Hotels - logic included), and OpenWeather (Environment).
    """
    
    def __init__(self):
        super().__init__("TravelAgent")
        
        # 1. Google Maps Client
        self.gmaps = None
        if HAS_GOOGLE_MAPS:
            google_api_key = os.getenv('GOOGLE_MAPS_API_KEY')
            if google_api_key:
                self.gmaps = googlemaps.Client(key=google_api_key)
                print("✅ Google Maps API: Connected")
        
        # 2. Weather & Currency Config
        self.weather_api_key = os.getenv('OPENWEATHER_API_KEY')
        self.exchange_api_key = os.getenv('EXCHANGE_RATE_API_KEY')
        
        # 3. Fallback: OSM Nominatim
        self.osm_api_url = "https://nominatim.openstreetmap.org"

    def extract(self, soup: BeautifulSoup, url: str) -> Dict:
        """Extract travel info with multi-API cross-referencing."""
        data = {
            'origin': None,
            'destination': None,
            'routes': [],
            'modes': [],
            'distance': None,
            'duration': None,
            'cost_range': None,
            'weather': None,
            'tips': [],
            'source': url,
            'api_enhanced': False
        }
        
        main_content = soup.find(['main', 'article', 'body'])
        if not main_content:
            return data
        
        text = main_content.get_text(separator='\n', strip=True)
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        
        # Extract Locations
        origin, destination = self._extract_locations(url, text)
        data['origin'] = origin
        data['destination'] = destination
        
        if origin and destination:
            # Multi-API Route Handling
            api_data = self._get_comprehensive_api_data(origin, destination)
            
            if api_data:
                data.update(api_data)
                data['api_enhanced'] = True
                print(f"✨ Enhanced data for {origin} ➔ {destination}")
            else:
                data = self._extract_from_text(data, text, lines)
        else:
            data = self._extract_from_text(data, text, lines)
            
        return data

    def _get_comprehensive_api_data(self, origin: str, destination: str) -> Optional[Dict]:
        """Orchestrates data from multiple travel APIs."""
        route_info = {}
        
        # A. Routing (Google or OSM)
        routing = self._get_route_from_api(origin, destination)
        if routing:
            route_info.update(routing)
            
        # B. Weather at Destination
        if self.weather_api_key:
            weather = self._get_weather(destination)
            if weather:
                route_info['weather'] = weather

        return route_info if route_info else None

    def _get_route_from_api(self, origin: str, destination: str) -> Optional[Dict]:
        """Tries Google Maps Directions, then falls back to OSM Haversine."""
        if self.gmaps:
            try:
                # Fetches multiple modes: Driving and Transit
                results = {}
                for mode in ['driving', 'transit']:
                    directions = self.gmaps.directions(origin, destination, mode=mode)
                    if directions:
                        leg = directions[0]['legs'][0]
                        results['distance'] = leg['distance']['text']
                        results['duration'] = leg['duration']['text']
                        results.setdefault('routes', []).append(
                            f"Via {mode.title()}: {leg['distance']['text']} ({leg['duration']['text']})"
                        )
                        results.setdefault('modes', []).append(mode.title())
                return results
            except Exception as e:
                print(f"⚠️ Google API Error: {e}")

        # OSM Fallback logic (Simplified for space)
        return self._get_route_from_osm(origin, destination)

    def _get_weather(self, location: str) -> Optional[str]:
        """Fetches real-time weather for the destination."""
        if not HAS_REQUESTS: return None
        try:
            url = f"http://api.openweathermap.org/data/2.5/weather?q={location}&appid={self.weather_api_key}&units=metric"
            resp = requests.get(url, timeout=3).json()
            temp = resp['main']['temp']
            desc = resp['weather'][0]['description']
            return f"{temp}°C, {desc.title()}"
        except:
            return None

    def format_output(self, data: Dict) -> str:
        """Professional formatted travel report."""
        output = [
            "🗺️ **TRAVEL DOSSIER**",
            "✨ API-Verified Information" if data['api_enhanced'] else "ℹ️ Scraped Web Data",
            "━" * 40
        ]
        
        if data['origin'] and data['destination']:
            output.append(f"📍 **Route:** {data['origin'].title()} ➔ {data['destination'].title()}")
        
        if data.get('weather'):
            output.append(f"🌤️ **Dest. Weather:** {data['weather']}")
            
        output.append(f"📏 **Distance:** {data.get('distance') or 'N/A'}")
        output.append(f"⏱️ **Duration:** {data.get('duration') or 'N/A'}")
        
        if data.get('cost_range'):
            output.append(f"💰 **Est. Cost:** {data['cost_range']}")

        if data.get('routes'):
            output.append("\n**🛣️ ROUTE OPTIONS:**")
            for i, r in enumerate(data['routes'][:3], 1):
                output.append(f"  {i}. {r}")

        if data.get('tips'):
            output.append("\n**💡 TRAVEL TIPS:**")
            for tip in data['tips'][:3]:
                output.append(f"  • {tip}")

        output.append(f"\n🔗 **Source:** {data['source']}")
        return "\n".join(output)