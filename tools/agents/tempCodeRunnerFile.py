import json
import re
import os
from typing import Dict, List, Optional
from bs4 import BeautifulSoup

# Base agent import (assuming it exists)
try:
    from .base_agent import BaseAgent
except:
    class BaseAgent:
        def __init__(self, name):
            self.name = name
        def clean_text(self, text):
            return ' '.join(text.split()).strip()
        def extract_rating(self, text):
            match = re.search(r'(\d\.\d)', text)
            return match.group(1) if match else None
        def extract_price(self, text):
            match = re.search(r'₹\s*\d+(?:,\d+)?', text)
            return match.group(0) if match else None

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


class RestaurantAgentEnhanced(BaseAgent):
    """API-Enhanced Restaurant Agent with Google Places & Foursquare integration."""
    
    def __init__(self):
        super().__init__("RestaurantAgentEnhanced")
        self.nav_junk = [
            'near me', 'delivery', 'explore', 'trending', 'locations', 
            'view all', 'offers', 'login', 'signup', 'menu', 'sign in'
        ]
        
        # Initialize Google Maps API
        self.gmaps = None
        if HAS_GOOGLE_MAPS:
            google_api_key = os.getenv('GOOGLE_MAPS_API_KEY')
            if google_api_key:
                self.gmaps = googlemaps.Client(key=google_api_key)
                print("✅ Google Places API initialized for restaurants")
        
        # Foursquare API
        self.foursquare_api_key = os.getenv('FOURSQUARE_API_KEY')

    def extract(self, soup: BeautifulSoup, url: str) -> Dict:
        """Main extraction with API enhancement."""
        data = {'restaurants': [], 'source': url, 'api_enhanced': False}
        
        if not soup:
            return data

        # Try to detect location from URL/content
        location = self._detect_location(url, soup)
        keyword = self._detect_keyword(url, soup)
        
        # Strategy 1: Use API if location detected
        if location and (self.gmaps or self.foursquare_api_key):
            api_results = self._get_restaurants_from_api(location, keyword)
            if api_results:
                data['restaurants'].extend(api_results)
                data['api_enhanced'] = True
                print(f"✅ API returned {len(api_results)} restaurants")
        
        # Strategy 2: JSON-LD extraction (scraping fallback)
        json_results = self._extract_json_ld(soup)
        if json_results:
            data['restaurants'].extend(json_results)
            print(f"✅ JSON-LD extracted {len(json_results)} restaurants")

        # Strategy 3: DOM SIGNAL DISCOVERY (final fallback)
        if len(data['restaurants']) < 5:
            dom_results = self._extract_from_dom(soup)
            data['restaurants'].extend(dom_results)
            print(f"✅ DOM extraction found {len(dom_results)} restaurants")

        data['restaurants'] = self._cleanup(data['restaurants'])
        return data
    
    def _detect_location(self, url: str, soup: BeautifulSoup) -> Optional[tuple]:
        """Detect geographic location from URL or page content."""
        
        # Common Indian cities
        cities = {
            'kolkata': (22.5726, 88.3639),
            'delhi': (28.7041, 77.1025),
            'mumbai': (19.0760, 72.8777),
            'bangalore': (12.9716, 77.5946),
            'chennai': (13.0827, 80.2707),
            'hyderabad': (17.3850, 78.4867),
            'pune': (18.5204, 73.8567),
            'garia': (22.4697, 88.3958)
        }
        
        # Check URL
        url_lower = url.lower()
        for city, coords in cities.items():
            if city in url_lower:
                print(f"📍 Detected location from URL: {city.title()}")
                return coords
        
        # Check page content
        if soup:
            text = soup.get_text()[:2000].lower()
            for city, coords in cities.items():
                if city in text:
                    print(f"📍 Detected location from content: {city.title()}")
                    return coords
        
        return None
    
    def _detect_keyword(self, url: str, soup: BeautifulSoup) -> Optional[str]:
        """Detect search keyword (cuisine, dish) from URL or content."""
        
        keywords = ['biryani', 'pizza', 'chinese', 'italian', 'north indian', 
                   'south indian', 'fast food', 'cafe', 'restaurant']
        
        url_lower = url.lower()
        for keyword in keywords:
            if keyword in url_lower:
                print(f"🔍 Detected keyword: {keyword}")
                return keyword
        
        return None
    
    def _get_restaurants_from_api(self, location: tuple, keyword: Optional[str] = None) -> List[Dict]:
        """Get restaurant data from Google Places or Foursquare API."""
        
        restaurants = []
        
        # Try Google Places first (best quality)
        if self.gmaps:
            try:
                restaurants.extend(self._get_from_google_places(location, keyword))
            except Exception as e:
                print(f"⚠️ Google Places error: {e}")
        
        # Try Foursquare as backup
        if not restaurants and self.foursquare_api_key:
            try:
                restaurants.extend(self._get_from_foursquare(location, keyword))
            except Exception as e:
                print(f"⚠️ Foursquare error: {e}")
        
        return restaurants
    
    def _get_from_google_places(self, location: tuple, keyword: Optional[str] = None) -> List[Dict]:
        """Get restaurants from Google Places API."""
        
        restaurants = []
        
        try:
            # Nearby search
            results = self.gmaps.places_nearby(
                location=location,
                radius=2000,  # 2km radius
                type='restaurant',
                keyword=keyword
            )
            
            for place in results.get('results', [])[:10]:
                # Get detailed info
                place_id = place['place_id']
                details = self.gmaps.place(
                    place_id=place_id,
                    fields=['name', 'rating', 'user_ratings_total', 'price_level',
                           'formatted_address', 'formatted_phone_number', 'website',
                           'opening_hours', 'types']
                )
                
                detail = details.get('result', {})
                
                # Format price level
                price_level = detail.get('price_level')
                price_text = None
                if price_level:
                    # Convert 0-4 scale to rupee estimate
                    price_ranges = {
                        1: '₹500 for two',
                        2: '₹1,000 for two',
                        3: '₹2,000 for two',
                        4: '₹3,000+ for two'
                    }
                    price_text = price_ranges.get(price_level)
                
                # Extract cuisine from types
                cuisine_types = detail.get('types', [])
                cuisine = ', '.join([t.replace('_', ' ').title() for t in cuisine_types 
                                    if 'food' in t or 'restaurant' in t])[:50]
                
                restaurant = {
                    'name': detail.get('name'),
                    'rating': detail.get('rating'),
                    'reviews': detail.get('user_ratings_total'),
                    'price': price_text,
                    'address': detail.get('formatted_address'),
                    'phone': detail.get('formatted_phone_number'),
                    'website': detail.get('website'),
                    'cuisine': cuisine or None,
                    'open_now': detail.get('opening_hours', {}).get('open_now'),
                    'source': 'Google Places API'
                }
                
                restaurants.append(restaurant)
            
            print(f"✅ Google Places API returned {len(restaurants)} restaurants")
            
        except Exception as e:
            print(f"⚠️ Google Places API error: {e}")
        
        return restaurants
    
    def _get_from_foursquare(self, location: tuple, keyword: Optional[str] = None) -> List[Dict]:
        """Get restaurants from Foursquare API."""
        
        if not HAS_REQUESTS or not self.foursquare_api_key:
            return []
        
        restaurants = []
        
        try:
            headers = {'Authorization': self.foursquare_api_key}
            
            params = {
                'll': f"{location[0]},{location[1]}",
                'radius': 2000,
                'categories': '13065',  # Restaurant category
                'limit': 10
            }
            
            if keyword:
                params['query'] = keyword
            
            response = requests.get(
                'https://api.foursquare.com/v3/places/search',
                headers=headers,
                params=params,
                timeout=10
            )
            
            if response.status_code == 200:
                results = response.json().get('results', [])
                
                for place in results:
                    restaurant = {
                        'name': place.get('name'),
                        'rating': place.get('rating'),
                        'reviews': place.get('stats', {}).get('total_ratings'),
                        'price': f"₹{place.get('price', 2) * 500} for two",  # Estimate
                        'address': place.get('location', {}).get('formatted_address'),
                        'cuisine': ', '.join([c['name'] for c in place.get('categories', [])][:3]),
                        'source': 'Foursquare API'
                    }
                    
                    restaurants.append(restaurant)
                
                print(f"✅ Foursquare API returned {len(restaurants)} restaurants")
        
        except Exception as e:
            print(f"⚠️ Foursquare API error: {e}")
        
        return restaurants

    def _extract_json_ld(self, soup: BeautifulSoup) -> List[Dict]:
        """Extracts structured data from <script type='application/ld+json'>."""
        found = []
        scripts = soup.find_all('script', type='application/ld+json')
        for script in scripts:
            try:
                if not script.string: continue
                payload = json.loads(script.string)
                
                items = payload if isinstance(payload, list) else [payload]
                
                for item in items:
                    if item.get('@type') == 'Restaurant':
                        found.append(self._parse_json_item(item))
                    elif item.get('@type') == 'ItemList' and 'itemListElement' in item:
                        for sub_item in item['itemListElement']:
                            res = sub_item.get('item', {})
                            if res.get('@type') == 'Restaurant':
                                found.append(self._parse_json_item(res))
            except: continue
        return [f for f in found if f.get('name')]

    def _parse_json_item(self, item: Dict) -> Dict:
        """Helper to map JSON-LD fields to our schema."""
        address = item.get('address', {})
        if isinstance(address, dict):
            address = address.get('streetAddress', '')
        
        return {
            'name': item.get('name'),
            'rating': item.get('aggregateRating', {}).get('ratingValue'),
            'reviews': item.get('aggregateRating', {}).get('reviewCount'),
            'price': item.get('priceRange'),
            'address': address,
            'phone': item.get('telephone'),
            'cuisine': item.get('servesCuisine'),
            'source': 'JSON-LD'
        }

    def _extract_from_dom(self, soup: BeautifulSoup) -> List[Dict]:
        """DOM-based extraction fallback."""
        found = []
        
        listings = soup.find_all(['div', 'article', 'li', 'section'], 
            class_=re.compile(r'card|item|listing|jumbo|result|store|res-card|content', re.I))
        
        if not listings:
            listings = soup.find_all(['div', 'section'], recursive=True)

        for element in listings[:50]:
            try:
                if not element: continue
                
                text_content = element.get_text()
                if not any(sig in text_content for sig in ['₹', 'Rating', '⭐', 'Reviews']):
                    continue

                resto = self._smart_parse(element)
                if self._is_verified(resto):
                    found.append(resto)
            except Exception:
                continue

        return found

    def _smart_parse(self, element: BeautifulSoup) -> Dict:
        """Extracts data by identifying 'Signals' in the text."""
        full_text = element.get_text(separator=' | ', strip=True) if element else ""
        
        name = None
        name_tag = element.find(['h2', 'h3', 'h4', 'b', 'strong', 'span'], 
                               class_=re.compile(r'title|name|heading', re.I))
        if name_tag:
            name = name_tag.get_text(strip=True)
        
        rating_match = re.search(r'([3-5]\.\d)', full_text)
        price_match = re.search(r'((?:₹|Rs\.?)\s*\d+[\s\w]*)', full_text, re.I)
        address = re.search(r'([^|]*(?:Road|Street|Kolkata|Block|Sector|Ruby|Bypass)[^|]*)', 
                          full_text, re.I)

        return {
            'name': name,
            'rating': rating_match.group(1) if rating_match else None,
            'price': price_match.group(1) if price_match else None,
            'address': address.group(1).strip() if address else None,
            'source': 'Web Scraping'
        }

    def _is_verified(self, resto: Dict) -> bool:
        """Strict validation to ensure the result is a real restaurant."""
        name = resto.get('name')
        if not name or not isinstance(name, str) or len(name.strip()) < 3:
            return False
        
        name_lower = name.lower()
        if any(junk in name_lower for junk in self.nav_junk):
            return False
            
        return any([resto.get('rating'), resto.get('price'), 
                   (resto.get('address') and len(resto.get('address', '')) > 8)])

    def _cleanup(self, restaurants: List[Dict]) -> List[Dict]:
        """Removes duplicates and normalizes names."""
        seen = set()
        unique = []
        for r in restaurants:
            name = str(r.get('name', ''))
            norm_name = re.sub(r'[^a-z0-9]', '', name.lower())
            if norm_name and norm_name not in seen and len(norm_name) > 3:
                seen.add(norm_name)
                unique.append(r)
        return unique

    def format_output(self, data: Dict) -> str:
        """Generates the final UI-friendly response."""
        if not data or not data.get('restaurants'):
            return "❌ No restaurant data found."
        
        try:
            domain = data['source'].split('/')[2].replace('www.', '').upper()
        except:
            domain = "SOURCE"

        output = [f"🍽️ **RESTAURANT RESULTS FROM {domain}**"]
        
        if data.get('api_enhanced'):
            output.append("✨ Enhanced with Real-Time API Data")
        
        output.append("━" * 70)
        output.append("")
        
        for i, r in enumerate(data['restaurants'][:12], 1):
            # Name and rating
            row = f"**{i}. {r['name']}**"
            if r.get('rating'):
                stars = "⭐" * int(float(r['rating']))
                row += f" | {r['rating']}/5 {stars}"
                if r.get('reviews'):
                    row += f" ({r['reviews']} reviews)"
            output.append(row)
            
            # Details line
            details = []
            if r.get('cuisine'):
                details.append(f"🍴 {r['cuisine']}")
            if r.get('price'):
                details.append(f"💰 {r['price']}")
            if r.get('open_now') is not None:
                status = "🟢 Open Now" if r['open_now'] else "🔴 Closed"
                details.append(status)
            
            if details:
                output.append("   " + " | ".join(details))
            
            # Address
            if r.get('address'):
                output.append(f"   📍 {r['address'][:80]}")
            
            # Contact
            contact = []
            if r.get('phone'):
                contact.append(f"📞 {r['phone']}")
            if r.get('website'):
                contact.append(f"🌐 {r['website'][:50]}")
            if contact:
                output.append(f"   {' | '.join(contact)}")
            
            # Data source indicator
            if r.get('source'):
                source_emoji = "🔌" if 'API' in r['source'] else "🌐"
                output.append(f"   {source_emoji} Source: {r['source']}")
            
            output.append("")
        
        # Footer
        if data.get('api_enhanced'):
            output.append("✅ Real-time data from Google Places / Foursquare API")
        else:
            output.append("ℹ️ Data extracted from website content")
        
        output.append(f"📊 Total: {len(data['restaurants'])} restaurants found")
            
        return "\n".join(output)