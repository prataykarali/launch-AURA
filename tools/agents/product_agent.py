from .base_agent import BaseAgent
from bs4 import BeautifulSoup
from typing import Dict, List
import re

class ProductAgent(BaseAgent):
    """Agent for extracting product information."""
    
    def __init__(self):
        super().__init__("ProductAgent")
    
    def extract(self, soup: BeautifulSoup, url: str) -> Dict:
        """Extract product info: name, price, rating, reviews."""
        
        data = {
            'products': [],
            'source': url
        }
        
        # Look for product listings
        listings = soup.find_all(['div', 'article'], class_=re.compile(r'product|item', re.I))
        
        for listing in listings[:10]:
            product = self._extract_product(listing)
            if product and product.get('name'):
                data['products'].append(product)
        
        return data
    
    def _extract_product(self, element: BeautifulSoup) -> Dict:
        """Extract single product data."""
        product = {
            'name': None,
            'price': None,
            'rating': None,
            'reviews_count': None
        }
        
        text = element.get_text(separator=' ', strip=True)
        
        # Name
        name_tag = element.find(['h2', 'h3', 'h4', 'a'])
        if name_tag:
            product['name'] = self.clean_text(name_tag.get_text())
        
        product['rating'] = self.extract_rating(text)
        product['price'] = self.extract_price(text)
        
        reviews_match = re.search(r'(\d+)\s*reviews?', text, re.I)
        if reviews_match:
            product['reviews_count'] = reviews_match.group(1)
        
        return product
    
    def format_output(self, data: Dict) -> str:
        """Format product data."""
        if not data.get('products'):
            return "No product data found."
        
        output = ["🛍️ **PRODUCT FINDINGS**", "━" * 70, ""]
        
        for i, prod in enumerate(data['products'][:8], 1):
            if not prod.get('name'):
                continue
            
            output.append(f"**{i}. {prod['name']}**")
            
            if prod.get('price'):
                output.append(f"   Price: {prod['price']}")
            
            if prod.get('rating'):
                stars = "⭐" * int(prod['rating'])
                output.append(f"   Rating: {prod['rating']}/5 {stars}")
            
            if prod.get('reviews_count'):
                output.append(f"   Reviews: {prod['reviews_count']}")
            
            output.append("")
        
        output.append(f"📍 Source: {data['source']}")
        
        return "\n".join(output)