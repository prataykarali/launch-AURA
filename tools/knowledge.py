import json
import asyncio
import requests
from datetime import datetime
from typing import Dict, List, Optional
from bs4 import BeautifulSoup
from tools.base import Tool
import re

# Import agents
# Import agents
from tools.agents import RestaurantAgent, TravelAgent, ProductAgent, NewsAgent, HotelAgent

# DuckDuckGo Search - NEW PACKAGE
try:
    from ddgs import DDGS
    HAS_DDGS = True
except ImportError:
    HAS_DDGS = False

# Crawl4AI for deep scraping
try:
    from crawl4ai import WebCrawler
    HAS_CRAWLER = True
except:
    HAS_CRAWLER = False

class WebSearchTool(Tool):
    def __init__(self):
        super().__init__()
        self.name = "WebSearchTool"
        self.description = "Universal web search with AI-powered extraction agents for structured data."
        self.category = "Information"
        
        # Initialize specialized extraction agents
        self.agents = {
            'food': RestaurantAgent(),
            'restaurants': RestaurantAgent(),
            'travel': TravelAgent(),
            'shopping': ProductAgent(),
            'product_reviews': ProductAgent(),
            'news': NewsAgent()
        }
        
        # Intelligent query enhancement patterns
        self.query_patterns = {
            # News & Current Events
            "news": ["latest news", "breaking news", "today", "current"],
            "politics": ["political news", "government", "election"],
            "world_news": ["international news", "global news"],
            
            # Sports & Esports
            "sports": ["sports news", "match results", "scores"],
            "esports": ["esports", "gaming tournament", "competitive gaming"],
            "cricket": ["cricket match", "cricket score", "IPL"],
            "football": ["football match", "soccer", "premier league"],
            "basketball": ["NBA", "basketball game"],
            
            # Travel & Tourism
            "travel": ["travel guide", "how to reach", "best route"],
            "destinations": ["tourist destination", "places to visit"],
            "hotels": ["best hotels", "accommodation", "booking"],
            "flights": ["flight tickets", "airfare", "flight booking"],
            
            # Food & Dining
            "restaurants": ["best restaurants", "dining", "food"],
            "food": ["restaurants", "dining", "food places"],
            "recipes": ["recipe", "how to cook", "cooking"],
            "food_delivery": ["food delivery", "order online"],
            
            # Shopping & Reviews
            "shopping": ["buy online", "shopping", "price comparison"],
            "product_reviews": ["review", "rating", "comparison"],
            "deals": ["discount", "offer", "deal"],
            
            # Entertainment
            "movies": ["movie review", "film", "cinema"],
            "music": ["song", "music", "album"],
            "tv_shows": ["TV series", "show", "streaming"],
            "events": ["events", "concerts", "shows"],
            
            # Technology
            "tech_news": ["technology news", "tech update", "gadget"],
            "software": ["software", "app", "download"],
            "gaming": ["video game", "game review", "gaming"],
            
            # Finance & Business
            "finance": ["stock market", "financial news", "investment"],
            "crypto": ["cryptocurrency", "bitcoin", "crypto news"],
            "business": ["business news", "company", "startup"],
            
            # Health & Wellness
            "health": ["health tips", "medical", "wellness"],
            "fitness": ["workout", "exercise", "fitness"],
            "diet": ["diet plan", "nutrition", "weight loss"],
            
            # Education & Learning
            "education": ["learn", "tutorial", "course"],
            "careers": ["jobs", "career", "employment"],
            
            # Weather & Geography
            "weather": ["weather forecast", "temperature", "climate"],
            "geography": ["location", "geography", "map"],
            
            # General Knowledge
            "facts": ["facts about", "information", "details"],
            "how_to": ["how to", "guide", "tutorial"],
            "definitions": ["what is", "define", "meaning"],
        }
        
        # Domain authority ranking (prioritize quality sources)
        self.trusted_domains = {
            # News
            "reuters.com": 10, "apnews.com": 10, "bbc.com": 9, "theguardian.com": 9,
            "cnn.com": 8, "nytimes.com": 9, "washingtonpost.com": 9,
            
            # Sports
            "espn.com": 10, "espncricinfo.com": 10, "goal.com": 8, "skysports.com": 9,
            
            # Travel
            "lonelyplanet.com": 9, "tripadvisor.com": 9, "booking.com": 8,
            "expedia.com": 8, "makemytrip.com": 7, "cleartrip.com": 7,
            
            # Food
            "zomato.com": 8, "eazydiner.com": 7, "swiggy.com": 7,
            
            # Tech
            "techcrunch.com": 9, "theverge.com": 9, "wired.com": 8, "arstechnica.com": 9,
            
            # Finance
            "bloomberg.com": 10, "cnbc.com": 9, "forbes.com": 8, "marketwatch.com": 8,
            
            # Health
            "mayoclinic.org": 10, "webmd.com": 8, "healthline.com": 8,
            
            # General
            "wikipedia.org": 7, "reddit.com": 6
        }
        
        # Enhanced ad/spam detection (AGGRESSIVE)
        self.spam_keywords = [
            "sponsored", "advertisement", "ad", "promoted", "partner content",
            "affiliate", "buy now", "click here", "limited offer", "casino",
            "dating", "adult", "porn", "xxx", "promotion", "shop now",
            "order now", "deal alert", "best price", "discount code"
        ]
        
        # Ad-related HTML patterns to remove
        self.ad_patterns = [
            r'advertisement', r'sponsored', r'promo', r'ad-container',
            r'banner', r'popup', r'modal', r'newsletter', r'subscribe'
        ]

    def _detect_category(self, query: str) -> str:
        """AI-like category detection based on query content."""
        query_lower = query.lower()
        
        # Keyword matching with scoring
        category_scores = {}
        
        for category, keywords in self.query_patterns.items():
            score = sum(1 for kw in keywords if kw in query_lower)
            if score > 0:
                category_scores[category] = score
        
        # Intent-based detection (high priority)
        if any(word in query_lower for word in ["how to reach", "route", "travel to", "getting to"]):
            return "travel"
        elif any(word in query_lower for word in ["best restaurant", "where to eat", "food near", "dining", "restaurant"]):
            return "food"
        elif any(word in query_lower for word in ["score", "match", "vs", "game"]):
            return "sports"
        elif any(word in query_lower for word in ["news", "latest", "today", "breaking"]):
            return "news"
        elif any(word in query_lower for word in ["weather", "temperature", "forecast"]):
            return "weather"
        elif any(word in query_lower for word in ["where is", "location", "situated", "geography"]):
            return "geography"
        elif any(word in query_lower for word in ["buy", "shopping", "product", "price"]):
            return "shopping"
        
        # Return highest scoring category or general
        if category_scores:
            return max(category_scores, key=category_scores.get)
        return "general"

    def _enhance_query(self, query: str, category: str) -> str:
        """Enhance query with category-specific modifiers."""
        enhancements = self.query_patterns.get(category, [])
        
        # Add temporal context for time-sensitive queries
        time_sensitive = ["news", "weather", "sports", "stock", "crypto"]
        if category in time_sensitive:
            current_year = datetime.now().year
            query = f"{query} {current_year}"
        
        # Don't add enhancement if query already has one
        query_lower = query.lower()
        for enhancement in enhancements:
            if enhancement in query_lower:
                return query
        
        # Add best enhancement
        if enhancements:
            return f"{enhancements[0]} {query}"
        
        return query

    def _rank_result(self, result: Dict) -> float:
        """Score results based on relevance and domain authority."""
        score = 5.0  # Base score
        
        # Domain authority bonus
        url = result.get('href', '') or result.get('link', '')
        for domain, authority in self.trusted_domains.items():
            if domain in url:
                score += authority
                break
        
        # Spam/ad penalty (AGGRESSIVE)
        title = result.get('title', '').lower()
        body = result.get('body', '').lower()
        
        spam_count = 0
        for spam_word in self.spam_keywords:
            if spam_word in title:
                spam_count += 2  # Title spam is worse
            if spam_word in body:
                spam_count += 1
        
        score -= spam_count * 10  # Heavy penalty
        
        # Length bonus (longer descriptions = more content)
        if len(body) > 200:
            score += 2
        
        return score

    def _is_spam(self, result: Dict) -> bool:
        """Filter out spam and low-quality results (AGGRESSIVE)."""
        title = result.get('title', '').lower()
        body = result.get('body', '').lower()
        url = result.get('href', '') or result.get('link', '')
        
        # Check for spam keywords
        for spam_word in self.spam_keywords:
            if spam_word in title or spam_word in url:
                return True
        
        # Check for suspicious patterns
        if len(title) < 10 or title.count('!') > 3 or title.count('?') > 2:
            return True
        
        # Check for spammy URLs
        if any(x in url for x in ['click', 'track', 'redirect', 'promo', 'deal']):
            return True
            
        return False

    def _clean_html_content(self, soup: BeautifulSoup) -> BeautifulSoup:
        """Aggressively remove ads, scripts, and junk from HTML."""
        # Remove scripts, styles, and tracking
        for tag in soup(['script', 'style', 'noscript', 'iframe', 'embed']):
            tag.decompose()
        
        # Remove navigation, headers, footers
        for tag in soup(['nav', 'header', 'footer', 'aside', 'menu']):
            tag.decompose()
        
        # Remove elements with ad-related classes/IDs
        for pattern in self.ad_patterns:
            for tag in soup.find_all(class_=re.compile(pattern, re.I)):
                tag.decompose()
            for tag in soup.find_all(id=re.compile(pattern, re.I)):
                tag.decompose()
        
        # Remove common ad containers
        for tag in soup.find_all(['div', 'section'], class_=re.compile(r'ad|sponsor|promo|banner', re.I)):
            tag.decompose()
        
        return soup

    async def _deep_scrape(self, url: str, category: str = "general") -> Optional[str]:
        """Advanced scraping with agent-based extraction."""
        if not HAS_CRAWLER:
            return await self._fallback_scrape(url, category)
        
        try:
            async with WebCrawler() as crawler:
                result = await crawler.arun(
                    url=url,
                    bypass_cache=True,
                    word_count_threshold=50,
                    exclude_external_links=True,
                    remove_overlay_elements=True
                )
                
                if result.success and result.markdown:
                    # Try agent-based extraction first
                    if category in self.agents:
                        # Parse HTML for agent
                        soup = BeautifulSoup(result.html, 'html.parser')
                        agent = self.agents[category]
                        print(f"🤖 Using {agent.name} for extraction...")
                        extracted_data = agent.extract(soup, url)
                        formatted = agent.format_output(extracted_data)
                        return formatted
                    
                    # Fallback to markdown content
                    content = result.markdown.strip()
                    content = '\n'.join(line.strip() for line in content.split('\n') if line.strip())
                    return content[:2500]
                
        except Exception as e:
            print(f"⚠️ Crawl4AI error: {e}")
        
        return await self._fallback_scrape(url, category)

    async def _fallback_scrape(self, url: str, category: str = "general") -> Optional[str]:
        """Fallback scraping with agent-based extraction."""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'DNT': '1'
            }
            response = requests.get(url, headers=headers, timeout=15)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            soup = self._clean_html_content(soup)
            
            # Use agent if available for category
            if category in self.agents:
                agent = self.agents[category]
                print(f"🤖 Using {agent.name} for extraction...")
                extracted_data = agent.extract(soup, url)
                formatted = agent.format_output(extracted_data)
                return formatted
            
            # Fallback to generic extraction
            main_content = soup.find('main') or soup.find('article') or soup.find('body')
            if main_content:
                text = main_content.get_text(separator='\n', strip=True)
                lines = [line.strip() for line in text.split('\n') if line.strip() and len(line) > 20]
                return '\n'.join(lines[:30])
                
        except Exception as e:
            print(f"⚠️ Scrape error: {e}")
        
        return None

    def _search_logic(self, query: str, category: str, max_results: int = 10) -> Optional[List[Dict]]:
        """Enhanced search with filtering and ranking."""
        if not HAS_DDGS:
            print("❌ DDGS package not available")
            return None
        
        results = []
        enhanced_query = self._enhance_query(query, category)
        
        print(f"🔎 Enhanced query: {enhanced_query}")
        
        try:
            with DDGS() as ddgs:
                raw_results = list(ddgs.text(enhanced_query, max_results=max_results * 3))
                
                print(f"📥 Got {len(raw_results)} raw results")
                
                for result in raw_results:
                    if self._is_spam(result):
                        print(f"🚫 Filtered spam: {result.get('title', 'N/A')[:50]}")
                        continue
                    
                    result['_score'] = self._rank_result(result)
                    results.append(result)
                
                results.sort(key=lambda x: x.get('_score', 0), reverse=True)
                
                print(f"✅ Kept {len(results)} quality results after filtering")
                
                return results[:max_results]
                
        except Exception as e:
            print(f"⚠️ Search error: {e}")
            import traceback
            traceback.print_exc()
            return None

    def execute(self, query: str, category: str = "auto", max_results: int = 5) -> str:
        """
        Universal search with AI-powered extraction agents.
        
        params:
        - query (str): What to search for
        - category (str): Category hint or 'auto' for auto-detection
        - max_results (int): Number of results to return
        """
        if not query or len(query.strip()) < 2:
            return "❌ Error: Search query is too short or empty."
        
        # Auto-detect category
        if category == "auto" or not category:
            category = self._detect_category(query)
        
        print(f"🔍 Category detected: {category}")
        
        # Perform search
        results = self._search_logic(query, category, max_results)
        
        if not results:
            return f"🤷‍♂️ No results found for '{query}'. Try rephrasing or checking your internet connection."
        
        # Build response header
        response_parts = [
            f"🔍 **SEARCH RESULTS** [{category.upper()}]",
            f"Query: \"{query}\"",
            f"Found: {len(results)} quality results (ads filtered)",
            "━" * 70,
            ""
        ]
        
        # Deep scrape best result with agent
        best_result = results[0]
        best_url = best_result.get('href') or best_result.get('link')
        
        response_parts.append(f"📌 **TOP RESULT:**")
        response_parts.append(f"Title: {best_result.get('title', 'N/A')}")
        response_parts.append(f"URL: {best_url}")
        response_parts.append("")
        
        # Attempt agent-powered deep scrape
        deep_content = None
        if best_url:
            try:
                print(f"🌐 Deep scraping with agent: {best_url}")
                deep_content = asyncio.run(self._deep_scrape(best_url, category))
            except Exception as e:
                print(f"⚠️ Deep scrape failed: {e}")
        
        if deep_content:
            response_parts.append(deep_content)
            response_parts.append("")
        else:
            response_parts.append("📝 **SNIPPET:**")
            response_parts.append(best_result.get('body', 'No description available'))
            response_parts.append("")
        
        # Add additional results
        if len(results) > 1:
            response_parts.append("🔗 **MORE QUALITY SOURCES:**")
            for i, result in enumerate(results[1:4], 2):
                title = result.get('title', 'N/A')[:100]
                url = result.get('href') or result.get('link', 'N/A')
                response_parts.append(f"{i}. {title}")
                response_parts.append(f"   {url}")
                response_parts.append("")
        
        return "\n".join(response_parts)


def register():
    return WebSearchTool()