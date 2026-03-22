from abc import ABC, abstractmethod
from typing import Dict, List, Optional
from bs4 import BeautifulSoup
import re

class BaseAgent(ABC):
    """Base class for all extraction agents."""
    
    def __init__(self, name: str):
        self.name = name
    
    @abstractmethod
    def extract(self, soup: BeautifulSoup, url: str) -> Dict:
        """Extract structured data from HTML."""
        pass
    
    def clean_text(self, text: str) -> str:
        """Clean and normalize text."""
        if not text:
            return ""
        # Remove extra whitespace
        text = re.sub(r'\s+', ' ', text).strip()
        # Remove special characters but keep basic punctuation
        text = re.sub(r'[^\w\s.,!?₹$€-]', '', text)
        return text
    
    def extract_rating(self, text: str) -> Optional[float]:
        """Extract rating from text (e.g., '4.5/5', '4.5 stars')."""
        patterns = [
            r'(\d+\.?\d*)\s*(?:/\s*5|out of 5|stars?)',
            r'rating[:\s]+(\d+\.?\d*)',
            r'(\d+\.?\d*)\s*★'
        ]
        for pattern in patterns:
            match = re.search(pattern, text, re.I)
            if match:
                try:
                    return float(match.group(1))
                except:
                    pass
        return None
    
    def extract_price(self, text: str) -> Optional[str]:
        """Extract price from text."""
        patterns = [
            r'₹\s*[\d,]+(?:\.\d{2})?',
            r'\$\s*[\d,]+(?:\.\d{2})?',
            r'€\s*[\d,]+(?:\.\d{2})?',
            r'price[:\s]+₹?\s*[\d,]+',
            r'cost[:\s]+₹?\s*[\d,]+'
        ]
        for pattern in patterns:
            match = re.search(pattern, text, re.I)
            if match:
                return match.group(0)
        return None
    
    def format_output(self, data: Dict) -> str:
        """Format extracted data for display."""
        pass