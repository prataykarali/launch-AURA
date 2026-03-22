import time
import re
import json
import undetected_chromedriver as uc
from bs4 import BeautifulSoup
from ddgs import DDGS
from tools.base import Tool

# ==========================================
# 🏨 HOTEL AGENT (Advanced Extraction)
# ==========================================
class HotelAgent(Tool):
    def __init__(self):
        super().__init__()
        self.name = "HotelAgent"
        self.description = "Advanced hotel finder. Searches for hotels and extracts: name, rating, reviews, price, amenities, location, contact, and more."
        self.category = "Agents"

    def is_url(self, text):
        """Check if input is a URL"""
        return text.startswith("http://") or text.startswith("https://") or "www." in text

    def smart_search(self, query):
        """
        Enhanced search for hotel listings
        """
        print(f"🔎 AURA: Searching for hotels: '{query}'...")
        
        try:
            # Add "hotels" if not present
            if "hotel" not in query.lower():
                query = f"best hotels {query}"
            
            with DDGS() as ddgs:
                results = list(ddgs.text(query, max_results=5))
            
            if results:
                # Prioritize hotel booking platforms
                priority_domains = ['booking.com', 'makemytrip.com', 'goibibo.com', 'tripadvisor.com', 'agoda.com', 'hotels.com']
                
                for domain in priority_domains:
                    for result in results:
                        if domain in result['href']:
                            print(f"🎯 Found: {result['href']}")
                            return result['href']
                
                print(f"🎯 Found: {results[0]['href']}")
                return results[0]['href']
            
            return None

        except Exception as e:
            print(f"❌ Search Error: {e}")
            return None

    def detect_platform(self, url):
        """Identify hotel booking platform"""
        url_lower = url.lower()
        
        platforms = {
            'booking': 'booking.com',
            'makemytrip': 'makemytrip.com',
            'goibibo': 'goibibo.com',
            'tripadvisor': 'tripadvisor.com',
            'agoda': 'agoda.com',
            'oyo': 'oyorooms.com',
            'hotels.com': 'hotels.com',
            'expedia': 'expedia.com'
        }
        
        for key, domain in platforms.items():
            if domain in url_lower or key in url_lower:
                return key
        
        return 'generic'

    def extract_rating(self, text):
        """Extract numeric rating"""
        # Handle different rating formats: 4.5/5, 4.5 out of 5, 4.5★
        match = re.search(r'(\d+\.?\d*)\s*(?:out of|/|★|stars?)?', text, re.IGNORECASE)
        if match:
            rating = float(match.group(1))
            # Normalize to 5-star scale
            if rating > 5:
                rating = rating / 2  # Convert 10-point to 5-point
            return round(rating, 1)
        return None

    def extract_price(self, text):
        """Extract price information"""
        # Patterns: ₹4,500, $150, €120
        match = re.search(r'[₹$€£]\s*(\d+(?:,\d+)?(?:\.\d+)?)', text)
        if match:
            return match.group(0)
        return None

    def extract_amenities(self, text):
        """Extract hotel amenities from text"""
        common_amenities = [
            'wifi', 'parking', 'pool', 'swimming pool', 'gym', 'fitness center',
            'spa', 'restaurant', 'bar', 'room service', 'breakfast', 'ac', 'air conditioning',
            'airport shuttle', 'pet friendly', 'laundry', 'conference room', 'beach access'
        ]
        
        found_amenities = []
        text_lower = text.lower()
        
        for amenity in common_amenities:
            if amenity in text_lower:
                found_amenities.append(amenity.title())
        
        return list(set(found_amenities))[:8]  # Return unique, max 8

    def scrape_hotels(self, url):
        """
        Scrape hotel information with stealth browser
        """
        print(f"🕵️ AURA: Extracting hotel data from {url}...")
        
        driver = None
        try:
            # Stealth browser setup
            options = uc.ChromeOptions()
            options.headless = False
            options.add_argument('--no-first-run')
            options.add_argument('--password-store=basic')
            options.add_argument('--disable-blink-features=AutomationControlled')

            driver = uc.Chrome(options=options, use_subprocess=True, version_main=144)
            driver.set_page_load_timeout(60)
            driver.get(url)
            
            # Wait for dynamic content
            time.sleep(6)
            
            # Scroll to load all hotels
            for _ in range(4):
                driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(2)

            # Parse HTML
            soup = BeautifulSoup(driver.page_source, 'html.parser')
            
            # Detect platform
            platform = self.detect_platform(url)
            print(f"📍 Detected Platform: {platform.upper()}")
            
            # Extract hotels
            hotels = self.extract_hotel_data(soup, platform)
            
            return hotels

        except Exception as e:
            print(f"❌ Scraping Error: {e}")
            return None
        finally:
            if driver:
                driver.quit()

    def extract_hotel_data(self, soup, platform):
        """
        Extract structured hotel data based on platform
        """
        hotels = []
        
        # Remove noise
        for tag in soup(["script", "style", "svg", "nav", "footer", "iframe", "noscript"]):
            tag.decompose()
        
        # Try to find hotel cards/listings
        hotel_cards = soup.find_all(['div', 'article', 'li'], 
                                     class_=re.compile(r'hotel|property|listing|card|result', re.I),
                                     limit=15)
        
        if not hotel_cards:
            # Fallback: look for any divs with data attributes
            hotel_cards = soup.find_all(['div'], attrs={'data-testid': True, 'data-hotel': True})[:15]
        
        for card in hotel_cards:
            hotel = self.extract_hotel_from_card(card, platform)
            
            # Only add if we extracted meaningful data
            if hotel.get('name') and len(hotel.get('name', '')) > 2:
                hotels.append(hotel)
        
        return hotels[:10]  # Return top 10

    def extract_hotel_from_card(self, card, platform):
        """
        Extract hotel information from a single card/element
        """
        hotel = {}
        
        # Get all text from the card
        card_text = card.get_text(separator=' | ', strip=True)
        
        # 1. HOTEL NAME
        name_elem = card.find(['h1', 'h2', 'h3', 'h4', 'a'], class_=re.compile(r'name|title|hotel', re.I))
        if name_elem:
            name = name_elem.get_text(strip=True)
            # Filter out obvious non-hotel names
            if len(name) > 3 and len(name) < 100 and not name.lower() in ['filter', 'sort', 'search']:
                hotel['name'] = name
        
        # 2. RATING
        rating_elem = card.find(['span', 'div'], class_=re.compile(r'rating|score|review-score', re.I))
        if rating_elem:
            rating = self.extract_rating(rating_elem.get_text(strip=True))
            if rating:
                hotel['rating'] = rating
        
        # If no rating element found, try to extract from text
        if not hotel.get('rating'):
            rating = self.extract_rating(card_text)
            if rating:
                hotel['rating'] = rating
        
        # 3. PRICE
        price_elem = card.find(['span', 'div'], class_=re.compile(r'price|cost|rate', re.I))
        if price_elem:
            price = self.extract_price(price_elem.get_text(strip=True))
            if price:
                hotel['price'] = price
        
        # Fallback: extract from full text
        if not hotel.get('price'):
            price = self.extract_price(card_text)
            if price:
                hotel['price'] = price
        
        # 4. LOCATION/ADDRESS
        location_elem = card.find(['span', 'div', 'address'], class_=re.compile(r'location|address|area|city', re.I))
        if location_elem:
            location = location_elem.get_text(strip=True)
            if len(location) < 200:  # Avoid getting too much text
                hotel['location'] = location
        
        # 5. REVIEWS COUNT
        review_elem = card.find(['span', 'div'], string=re.compile(r'\d+\s*reviews?', re.I))
        if review_elem:
            review_text = review_elem.get_text(strip=True)
            review_match = re.search(r'(\d+(?:,\d+)?)', review_text)
            if review_match:
                hotel['reviews_count'] = review_match.group(1)
        
        # 6. AMENITIES
        amenities = self.extract_amenities(card_text)
        if amenities:
            hotel['amenities'] = amenities
        
        # 7. HOTEL TYPE/CATEGORY
        type_keywords = ['resort', 'boutique', 'luxury', 'budget', 'homestay', 'villa', 'apartment']
        for keyword in type_keywords:
            if keyword in card_text.lower():
                hotel['type'] = keyword.title()
                break
        
        # 8. DISTANCE (if available)
        distance_match = re.search(r'(\d+\.?\d*)\s*(km|miles?|mi)', card_text, re.I)
        if distance_match:
            hotel['distance'] = f"{distance_match.group(1)} {distance_match.group(2)}"
        
        return hotel

    def format_output(self, hotels, source_url):
        """
        Format hotel data into readable output
        """
        if not hotels:
            return "🤷‍♂️ Couldn't find any hotels from this page."
        
        output = f"🏨 **Found {len(hotels)} Hotels**\n"
        output += f"📍 **Source:** {source_url}\n"
        output += "=" * 60 + "\n\n"
        
        for idx, hotel in enumerate(hotels, 1):
            output += f"**{idx}. {hotel.get('name', 'Unknown Hotel')}**\n"
            
            if hotel.get('type'):
                output += f"   🏛️ Type: {hotel['type']}\n"
            
            if hotel.get('rating'):
                stars = "⭐" * int(hotel['rating'])
                output += f"   {stars} Rating: {hotel['rating']}/5\n"
            
            if hotel.get('reviews_count'):
                output += f"   💬 Reviews: {hotel['reviews_count']}\n"
            
            if hotel.get('price'):
                output += f"   💰 Price: {hotel['price']}\n"
            
            if hotel.get('location'):
                output += f"   📍 Location: {hotel['location']}\n"
            
            if hotel.get('distance'):
                output += f"   📏 Distance: {hotel['distance']}\n"
            
            if hotel.get('amenities'):
                output += f"   ✨ Amenities: {', '.join(hotel['amenities'][:5])}\n"
            
            output += "\n"
        
        return output

    def execute(self, user_input: str):
        """
        Main execution: Search + Scrape + Extract + Format
        
        Usage:
        - "best hotels in Goa"
        - "luxury hotels in Mumbai"
        - "https://www.booking.com/..."
        """
        target_url = user_input.strip()
        
        # Step 1: Get URL (search if needed)
        if not self.is_url(target_url):
            found_url = self.smart_search(target_url)
            if not found_url:
                return "❌ Couldn't find any hotel listings for your query."
            target_url = found_url
        
        # Step 2: Scrape and extract
        hotels = self.scrape_hotels(target_url)
        
        # Step 3: Format and return
        if hotels:
            return self.format_output(hotels, target_url)
        else:
            return "🤷‍♂️ Found the page but couldn't extract hotel details."


# ==========================================
# 📊 EXPORT FOR TOOL REGISTRY
# ==========================================
def get_tool():
    """Required function for tool registry"""
    return HotelAgent()