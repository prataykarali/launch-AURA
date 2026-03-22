from .base_agent import BaseAgent
from bs4 import BeautifulSoup
from typing import Dict, List
import re
from datetime import datetime

class NewsAgent(BaseAgent):
    """Agent for extracting news information."""
    
    def __init__(self):
        super().__init__("NewsAgent")
    
    def extract(self, soup: BeautifulSoup, url: str) -> Dict:
        """Extract news: headlines, date, summary."""
        
        data = {
            'headline': None,
            'date': None,
            'summary': None,
            'key_points': [],
            'source': url
        }
        
        # Headline
        headline_tag = soup.find('h1') or soup.find(['h2', 'h3'], class_=re.compile(r'headline|title', re.I))
        if headline_tag:
            data['headline'] = self.clean_text(headline_tag.get_text())
        
        # Date
        date_tag = soup.find(['time', 'span'], class_=re.compile(r'date|time|published', re.I))
        if date_tag:
            data['date'] = self.clean_text(date_tag.get_text())
        
        # Summary/Description
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        if meta_desc:
            data['summary'] = meta_desc.get('content', '')
        
        # Key points (look for paragraphs)
        paragraphs = soup.find_all('p', limit=5)
        for p in paragraphs:
            text = self.clean_text(p.get_text())
            if len(text) > 50:
                data['key_points'].append(text)
        
        return data
    
    def format_output(self, data: Dict) -> str:
        """Format news data."""
        output = ["📰 **NEWS SUMMARY**", "━" * 70, ""]
        
        if data.get('headline'):
            output.append(f"**{data['headline']}**")
            output.append("")
        
        if data.get('date'):
            output.append(f"📅 Published: {data['date']}")
            output.append("")
        
        if data.get('summary'):
            output.append(f"**Summary:** {data['summary']}")
            output.append("")
        
        if data.get('key_points'):
            output.append("**KEY POINTS:**")
            for point in data['key_points'][:5]:
                output.append(f"• {point[:200]}...")
            output.append("")
        
        output.append(f"📍 Source: {data['source']}")
        
        return "\n".join(output)