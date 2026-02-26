"""
FAST Contact Enrichment - Pattern-based only (NO SMTP validation)
This version prioritizes SPEED over accuracy for large batches
"""

import re
from typing import List, Dict
from urllib.parse import quote


class FastContactEnricher:
    """Fast email generation and LinkedIn discovery - NO external API calls"""
    
    def clean_name(self, name: str) -> str:
        """Clean and normalize names"""
        cleaned = re.sub(r'[^a-zA-Z\s-]', '', name)
        cleaned = cleaned.lower().strip()
        cleaned = re.sub(r'[\s-]+', ' ', cleaned)
        return cleaned
    
    def clean_company_name(self, company: str) -> str:
        """Clean company name for domain extraction"""
        suffixes = ['inc', 'llc', 'ltd', 'corp', 'corporation', 'company', 'co']
        cleaned = company.lower().strip()
        
        for suffix in suffixes:
            cleaned = re.sub(rf'\b{suffix}\.?\b', '', cleaned)
        
        cleaned = re.sub(r'[^a-z0-9\s]', '', cleaned)
        cleaned = cleaned.strip()
        
        return cleaned
    
    def extract_company_domain(self, company: str) -> str:
        """Extract likely domain from company name"""
        cleaned = self.clean_company_name(company)
        words = cleaned.split()
        if words:
            primary_word = words[0]
            return f"{primary_word}.com"
        return "example.com"
    
    def generate_email_patterns(self, firstname: str, lastname: str, company: str) -> List[str]:
        """Generate common email patterns"""
        first = self.clean_name(firstname)
        last = self.clean_name(lastname)
        domain = self.extract_company_domain(company)
        
        first_parts = first.split()
        last_parts = last.split()
        
        first_main = first_parts[0] if first_parts else ''
        last_main = last_parts[-1] if last_parts else ''
        
        if not first_main or not last_main:
            return []
        
        first_initial = first_main[0] if first_main else ''
        
        patterns = [
            f"{first_main}.{last_main}@{domain}",
            f"{first_main}{last_main}@{domain}",
            f"{first_initial}{last_main}@{domain}",
            f"{first_main}@{domain}",
            f"{first_initial}.{last_main}@{domain}",
        ]
        
        return list(dict.fromkeys(patterns))  # Remove duplicates
    
    def estimate_confidence(self, company: str) -> float:
        """Estimate confidence based on company reputation"""
        # Well-known companies get higher confidence
        company_lower = company.lower()
        
        high_confidence_companies = [
            'google', 'microsoft', 'amazon', 'apple', 'facebook', 'meta',
            'ibm', 'oracle', 'salesforce', 'adobe', 'netflix', 'tesla',
            'deloitte', 'pwc', 'kpmg', 'ey', 'accenture', 'mckinsey',
            'boeing', 'ge', 'ford', 'gm', 'toyota', 'honda'
        ]
        
        for known_company in high_confidence_companies:
            if known_company in company_lower:
                return 0.75  # 75% confidence for known companies
        
        return 0.50  # 50% confidence for unknown companies
    
    def generate_linkedin_urls(self, firstname: str, lastname: str, company: str) -> List[str]:
        """Generate probable LinkedIn profile URLs"""
        first = self.clean_name(firstname)
        last = self.clean_name(lastname)
        company_clean = self.clean_company_name(company)
        
        first_parts = first.split()
        last_parts = last.split()
        
        first_main = first_parts[0] if first_parts else ''
        last_main = last_parts[-1] if last_parts else ''
        
        if not first_main or not last_main:
            return []
        
        base_url = "https://www.linkedin.com/in/"
        
        patterns = [
            f"{first_main}-{last_main}",
            f"{first_main}{last_main}",
            f"{first_main}-{last_main}-{company_clean}",
        ]
        
        urls = []
        for pattern in patterns:
            slug = re.sub(r'\s+', '-', pattern)
            slug = re.sub(r'-+', '-', slug)
            if slug:
                urls.append(f"{base_url}{slug}")
        
        return urls
    
    def generate_linkedin_search_url(self, firstname: str, lastname: str, company: str) -> str:
        """Generate LinkedIn search URL"""
        query = f"{firstname} {lastname} {company}"
        encoded_query = quote(query)
        return f"https://www.linkedin.com/search/results/people/?keywords={encoded_query}"
    
    def enrich_contact(self, firstname: str, lastname: str, title: str, company: str) -> Dict:
        """Fast enrichment - pattern generation only"""
        # Generate email patterns
        patterns = self.generate_email_patterns(firstname, lastname, company)
        best_email = patterns[0] if patterns else ''
        
        # Estimate confidence
        confidence = self.estimate_confidence(company)
        
        # Generate LinkedIn URLs
        linkedin_urls = self.generate_linkedin_urls(firstname, lastname, company)
        linkedin_primary = linkedin_urls[0] if linkedin_urls else ''
        linkedin_search = self.generate_linkedin_search_url(firstname, lastname, company)
        
        return {
            'firstname': firstname,
            'lastname': lastname,
            'title': title,
            'company': company,
            'email': best_email,
            'email_confidence': confidence,
            'email_all_patterns': patterns,
            'linkedin_url': linkedin_primary,
            'linkedin_alternatives': linkedin_urls[1:],
            'linkedin_search': linkedin_search,
            'enrichment_status': 'completed'
        }


# Test
if __name__ == "__main__":
    enricher = FastContactEnricher()
    
    test_contacts = [
        ("Denise", "Bartuss", "Owner", "OEM Solutions"),
        ("Test", "User", "Engineer", "Google"),
        ("Jane", "Doe", "Manager", "Microsoft"),
    ]
    
    print("\n=== FAST ENRICHMENT TEST ===\n")
    
    for firstname, lastname, title, company in test_contacts:
        result = enricher.enrich_contact(firstname, lastname, title, company)
        print(f"{firstname} {lastname} @ {company}")
        print(f"  Email: {result['email']} ({result['email_confidence']:.0%})")
        print(f"  LinkedIn: {result['linkedin_url']}")
        print()
