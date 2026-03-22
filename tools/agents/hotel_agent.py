from .base_agent import BaseAgent
from bs4 import BeautifulSoup
from typing import Dict, List
import re

class HotelAgent(BaseAgent):
    """Specialized agent for extracting hotel information."""
    
    def __init__(self):
        super().__init__("HotelAgent")
        
    def extract(self, soup: BeautifulSoup, url: str) -> Dict:
        """Extract hotel details: name, rating, price, amenities, location."""
        
        data = {
            'hotels': [],
            'source': url
        }
        
        # Strategy 1: Look for hotel listings
        listings = self._find_listings(soup)
        
        if listings:
            print(f"🔎 Found {len(listings)} hotel listings")
            for i, listing in enumerate(listings[:15]):
                hotel = self._extract_hotel_data(listing)
                if hotel and hotel.get('name'):
                    print(f"  ✓ Extracted: {hotel['name']}")
                    data['hotels'].append(hotel)
        
        # Strategy 2: Text-based extraction fallback
        if len(data['hotels']) < 3:
            print("🔄 Trying text-based extraction...")
            text_hotels = self._extract_from_text(soup)
            data['hotels'].extend(text_hotels)
        
        # Strategy 3: Single hotel page
        if not data['hotels']:
            print("🔄 Trying single hotel extraction...")
            main_hotel = self._extract_single_hotel(soup)
            if main_hotel:
                data['hotels'].append(main_hotel)
        
        print(f"✅ Total hotels extracted: {len(data['hotels'])}")
        return data
    
    def _find_listings(self, soup: BeautifulSoup) -> List:
        """Find hotel listing containers."""
        all_listings = []
        
        # Booking.com, Agoda, Hotels.com patterns
        patterns = [
            {'data-testid': re.compile(r'property-card|hotel', re.I)},
            {'class': re.compile(r'hotel.*card|property.*card', re.I)},
            {'class': re.compile(r'sr_property_block|room.*item', re.I)},
            {'class': re.compile(r'listing|result.*item', re.I)},
            {'class': re.compile(r'card|item', re.I)}
        ]
        
        for pattern in patterns:
            listings = soup.find_all(['div', 'article', 'li'], pattern, limit=20)
            if listings:
                print(f"  Found {len(listings)} with pattern: {pattern}")
                all_listings.extend(listings)
        
        # Dedup
        unique_listings = []
        seen_text = set()
        for listing in all_listings:
            text_sample = listing.get_text()[:100]
            if text_sample not in seen_text and len(text_sample) > 20:
                seen_text.add(text_sample)
                unique_listings.append(listing)
        
        print(f"🎯 Unique listings after dedup: {len(unique_listings)}")
        return unique_listings[:20]
    
    def _extract_hotel_data(self, element: BeautifulSoup) -> Dict:
        """Extract data from a single hotel element."""
        hotel = {
            'name': None,
            'rating': None,
            'price': None,
            'stars': None,
            'reviews_count': None,
            'location': None,
            'amenities': []
        }
        
        text = element.get_text(separator=' ', strip=True)
        
        # Name - Multiple strategies
        name_tag = (
            element.find(['h1', 'h2', 'h3', 'h4']) or
            element.find('a', class_=re.compile(r'name|title|hotel', re.I)) or
            element.find('a', href=re.compile(r'hotel|property', re.I)) or
            element.find(['strong', 'b']) or
            element.find('a')
        )
        
        if name_tag:
            name_text = self.clean_text(name_tag.get_text())
            if len(name_text) > 3 and not name_text.isdigit():
                hotel['name'] = name_text[:150]
        
        # Rating
        hotel['rating'] = self.extract_rating(text)
        
        # Price
        hotel['price'] = self.extract_price(text)
        
        # Star rating (hotel stars)
        star_patterns = [
            r'(\d)\s*star',
            r'(\d)★',
            r'★{1,5}'
        ]
        for pattern in star_patterns:
            star_match = re.search(pattern, text, re.I)
            if star_match:
                if '★' in star_match.group(0):
                    hotel['stars'] = star_match.group(0).count('★')
                else:
                    hotel['stars'] = int(star_match.group(1))
                break
        
        # Reviews count
        reviews_patterns = [
            r'(\d+(?:,\d+)?)\s*(?:reviews?|ratings?)',
            r'(\d+(?:,\d+)?)\s*verified'
        ]
        for pattern in reviews_patterns:
            reviews_match = re.search(pattern, text, re.I)
            if reviews_match:
                hotel['reviews_count'] = reviews_match.group(1)
                break
        
        # Location
        location_tag = element.find(class_=re.compile(r'location|address|area', re.I))
        if location_tag:
            hotel['location'] = self.clean_text(location_tag.get_text())[:100]
        
        # Amenities
        amenity_keywords = [
            'wifi', 'pool', 'spa', 'gym', 'restaurant', 'bar',
            'parking', 'breakfast', 'ac', 'room service'
        ]
        text_lower = text.lower()
        found_amenities = [kw for kw in amenity_keywords if kw in text_lower]
        if found_amenities:
            hotel['amenities'] = found_amenities[:5]
        
        return hotel
    
    def _extract_from_text(self, soup: BeautifulSoup) -> List[Dict]:
        """Fallback: Extract hotels from plain text."""
        hotels = []
        
        main_content = soup.find('main') or soup.find('article') or soup.find('body')
        if not main_content:
            return hotels
        
        text = main_content.get_text(separator='\n', strip=True)
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        
        hotel_indicators = [
            'hotel', 'resort', 'lodge', 'inn', 'homestay', 'guesthouse',
            'palace', 'retreat', 'hostel', 'villa'
        ]
        
        for i, line in enumerate(lines):
            if len(line) < 5 or len(line) > 200:
                continue
            
            line_lower = line.lower()
            has_indicator = any(ind in line_lower for ind in hotel_indicators)
            
            context_lines = ' '.join(lines[i:i+4])
            has_rating = self.extract_rating(context_lines) is not None
            has_price = self.extract_price(context_lines) is not None
            
            if has_indicator or (has_rating and has_price):
                hotel = {
                    'name': self.clean_text(line),
                    'rating': self.extract_rating(context_lines),
                    'price': self.extract_price(context_lines),
                    'stars': None,
                    'reviews_count': None,
                    'location': None,
                    'amenities': []
                }
                
                if hotel['name'] and not any(h['name'] == hotel['name'] for h in hotels):
                    hotels.append(hotel)
                    if len(hotels) >= 10:
                        break
        
        return hotels
    
    def _extract_single_hotel(self, soup: BeautifulSoup) -> Dict:
        """Extract single hotel from dedicated page."""
        hotel = {
            'name': None,
            'rating': None,
            'price': None,
            'stars': None,
            'reviews_count': None,
            'location': None,
            'amenities': []
        }
        
        title_tag = soup.find('h1') or soup.find('title')
        if title_tag:
            hotel['name'] = self.clean_text(title_tag.get_text())
        
        main_content = soup.find('main') or soup.find('article') or soup.find('body')
        if main_content:
            text = main_content.get_text(separator=' ', strip=True)
            hotel['rating'] = self.extract_rating(text)
            hotel['price'] = self.extract_price(text)
        
        return hotel
    
    def format_output(self, data: Dict) -> str:
        """Format hotel data beautifully."""
        if not data.get('hotels'):
            return "No hotel data found."
        
        output = ["🏨 **HOTEL FINDINGS**", "━" * 70, ""]
        
        hotel_count = 0
        for i, hotel in enumerate(data['hotels'], 1):
            if not hotel.get('name'):
                continue
            
            # Skip generic names
            if len(hotel['name']) < 4 or hotel['name'].lower() in ['hotel', 'hotels', 'accommodation']:
                continue
            
            hotel_count += 1
            output.append(f"**{hotel_count}. {hotel['name']}**")
            
            if hotel.get('stars'):
                stars = "⭐" * hotel['stars']
                output.append(f"   Category: {hotel['stars']}-Star {stars}")
            
            if hotel.get('rating'):
                rating_stars = "⭐" * int(hotel['rating'])
                output.append(f"   Guest Rating: {hotel['rating']}/5 {rating_stars}")
            
            if hotel.get('price'):
                output.append(f"   Price: {hotel['price']}")
            
            if hotel.get('reviews_count'):
                output.append(f"   Reviews: {hotel['reviews_count']}")
            
            if hotel.get('location'):
                output.append(f"   Location: {hotel['location'][:80]}")
            
            if hotel.get('amenities'):
                output.append(f"   Amenities: {', '.join(hotel['amenities']).title()}")
            
            output.append("")
            
            if hotel_count >= 12:
                break
        
        if hotel_count == 0:
            return "No valid hotel data found."
        
        output.append(f"📍 Source: {data['source']}")
        output.append(f"📊 Total: {hotel_count} hotels found")
        
        return "\n".join(output)