"""
Contact Enrichment System
Email pattern generation and LinkedIn profile discovery
With Snovio API integration as fallback for low-confidence results
"""

import re
import os
from typing import List, Dict, Tuple, Optional
from urllib.parse import quote
from email_validator import EmailValidator, EmailValidationResult
from snovio_integration import SnovioAPI


class ContactEnricher:
    """Generate and validate professional emails, discover LinkedIn profiles"""
    
    def __init__(self, snovio_api_key: Optional[str] = None):
        self.email_validator = EmailValidator(timeout=3)  # Reduced from 8 to 3 seconds for faster processing
        
        # Initialize Snovio API if credentials provided
        api_key = snovio_api_key or os.environ.get('SNOVIO_API_KEY')
        self.snovio = SnovioAPI(api_key=api_key) if api_key else None
        
        if self.snovio:
            print("✅ Snovio API integration enabled")
        else:
            print("⚠️  Snovio API not configured (will use pattern validation only)")
        
    def clean_name(self, name: str) -> str:
        """Clean and normalize names"""
        # Remove special characters, convert to lowercase
        cleaned = re.sub(r'[^a-zA-Z\s-]', '', name)
        cleaned = cleaned.lower().strip()
        # Replace spaces and hyphens with single space
        cleaned = re.sub(r'[\s-]+', ' ', cleaned)
        return cleaned
    
    def clean_company_name(self, company: str) -> str:
        """Clean company name for domain extraction"""
        # Remove common suffixes
        suffixes = ['inc', 'llc', 'ltd', 'corp', 'corporation', 'company', 'co']
        cleaned = company.lower().strip()
        
        for suffix in suffixes:
            cleaned = re.sub(rf'\b{suffix}\.?\b', '', cleaned)
        
        # Remove special characters except spaces
        cleaned = re.sub(r'[^a-z0-9\s]', '', cleaned)
        cleaned = cleaned.strip()
        
        return cleaned
    
    def extract_company_domain(self, company: str) -> str:
        """
        Extract likely domain from company name
        Examples: "Google Inc" -> "google.com", "Microsoft Corporation" -> "microsoft.com"
        """
        cleaned = self.clean_company_name(company)
        
        # Handle multi-word companies - use first significant word
        words = cleaned.split()
        if words:
            primary_word = words[0]
            return f"{primary_word}.com"
        
        return "example.com"
    
    def generate_email_patterns(
        self, 
        firstname: str, 
        lastname: str, 
        company: str
    ) -> List[str]:
        """
        Generate common email patterns based on name and company
        Returns list of probable email addresses in order of likelihood
        """
        first = self.clean_name(firstname)
        last = self.clean_name(lastname)
        domain = self.extract_company_domain(company)
        
        # Handle names with spaces (middle names, etc.)
        first_parts = first.split()
        last_parts = last.split()
        
        first_main = first_parts[0] if first_parts else ''
        last_main = last_parts[-1] if last_parts else ''  # Use last part of lastname
        
        if not first_main or not last_main:
            return []
        
        first_initial = first_main[0] if first_main else ''
        last_initial = last_main[0] if last_main else ''
        
        # Common email patterns (ordered by prevalence)
        patterns = [
            f"{first_main}.{last_main}@{domain}",           # john.doe@company.com (most common)
            f"{first_main}{last_main}@{domain}",            # johndoe@company.com
            f"{first_initial}{last_main}@{domain}",         # jdoe@company.com
            f"{first_main}@{domain}",                       # john@company.com
            f"{first_initial}.{last_main}@{domain}",        # j.doe@company.com
            f"{last_main}.{first_main}@{domain}",           # doe.john@company.com
            f"{first_main}_{last_main}@{domain}",           # john_doe@company.com
            f"{first_main}-{last_main}@{domain}",           # john-doe@company.com
            f"{last_main}@{domain}",                        # doe@company.com
            f"{first_initial}{last_initial}@{domain}",      # jd@company.com
        ]
        
        # Remove duplicates while preserving order
        seen = set()
        unique_patterns = []
        for pattern in patterns:
            if pattern not in seen:
                seen.add(pattern)
                unique_patterns.append(pattern)
        
        return unique_patterns
    
    def find_best_email(
        self, 
        firstname: str, 
        lastname: str, 
        company: str
    ) -> Dict:
        """
        Generate email patterns and validate to find the best match
        Uses Snovio API as fallback if confidence is below 50%
        Returns the most likely valid email with confidence score
        """
        patterns = self.generate_email_patterns(firstname, lastname, company)
        
        if not patterns:
            return {
                'email': '',
                'confidence': 0.0,
                'all_patterns': [],
                'validation_details': 'Could not generate email patterns',
                'source': 'pattern_generation_failed'
            }
        
        best_email = None
        best_score = 0.0
        all_results = []
        validation_source = 'pattern_validation'
        
        # Validate each pattern
        for pattern in patterns[:5]:  # Check top 5 patterns to save time
            result = self.email_validator.validate_email_comprehensive(pattern)
            
            all_results.append({
                'email': pattern,
                'confidence': result.confidence_score,
                'valid': result.is_valid,
                'details': result.details
            })
            
            # Track best result
            if result.confidence_score > best_score:
                best_score = result.confidence_score
                best_email = pattern
        
        # If no valid email found, return first pattern with low confidence
        if not best_email:
            best_email = patterns[0]
            best_score = 0.3
        
        # 🔥 SNOVIO FALLBACK: If confidence is below 50%, try Snovio API
        if best_score < 0.50 and self.snovio:
            print(f"⚠️  Low confidence ({best_score:.0%}), trying Snovio API...")
            
            try:
                domain = self.extract_company_domain(company)
                snovio_result = self.snovio.find_email(firstname, lastname, domain)
                
                if snovio_result and snovio_result.get('found') and snovio_result.get('email'):
                    snovio_email = snovio_result['email']
                    snovio_confidence = snovio_result.get('confidence', 0.0)
                    
                    # Use Snovio result if it has higher confidence
                    if snovio_confidence > best_score:
                        print(f"✅ Snovio found better result: {snovio_email} ({snovio_confidence:.0%})")
                        best_email = snovio_email
                        best_score = snovio_confidence
                        validation_source = 'snovio_api'
                    else:
                        print(f"ℹ️  Snovio result not better than pattern validation")
                else:
                    print(f"ℹ️  Snovio did not find email")
            except Exception as e:
                print(f"⚠️  Snovio API error (skipping): {str(e)[:100]}")
                # Continue with pattern validation result
        
        return {
            'email': best_email,
            'confidence': round(best_score, 2),
            'all_patterns': [p['email'] for p in all_results],
            'validation_details': all_results[0]['details'] if all_results else '',
            'source': validation_source
        }
    
    def generate_linkedin_urls(
        self, 
        firstname: str, 
        lastname: str, 
        company: str
    ) -> List[str]:
        """
        Generate probable LinkedIn profile URLs
        Returns list of likely LinkedIn URLs
        """
        first = self.clean_name(firstname)
        last = self.clean_name(lastname)
        company_clean = self.clean_company_name(company)
        
        # Handle multi-part names
        first_parts = first.split()
        last_parts = last.split()
        
        first_main = first_parts[0] if first_parts else ''
        last_main = last_parts[-1] if last_parts else ''
        
        if not first_main or not last_main:
            return []
        
        # LinkedIn URL slug patterns
        base_url = "https://www.linkedin.com/in/"
        
        # Generate probable LinkedIn vanity URLs
        patterns = [
            f"{first_main}-{last_main}",                    # john-doe
            f"{first_main}{last_main}",                     # johndoe
            f"{first_main}-{last_main}-{company_clean}",    # john-doe-google
            f"{first_main}{last_main}{company_clean}",      # johndoegoogle
            f"{last_main}{first_main}",                     # doejohn
        ]
        
        # Remove duplicates and build full URLs
        urls = []
        seen = set()
        for pattern in patterns:
            # Remove extra spaces and clean
            slug = re.sub(r'\s+', '-', pattern)
            slug = re.sub(r'-+', '-', slug)  # Multiple dashes to single
            
            if slug and slug not in seen:
                seen.add(slug)
                urls.append(f"{base_url}{slug}")
        
        return urls
    
    def generate_linkedin_search_url(
        self, 
        firstname: str, 
        lastname: str, 
        company: str
    ) -> str:
        """
        Generate LinkedIn search URL to find the person
        """
        query = f"{firstname} {lastname} {company}"
        encoded_query = quote(query)
        return f"https://www.linkedin.com/search/results/people/?keywords={encoded_query}"
    
    def enrich_contact(
        self, 
        firstname: str, 
        lastname: str, 
        title: str, 
        company: str
    ) -> Dict:
        """
        Main enrichment function - adds email and LinkedIn profile
        Returns enriched contact data
        """
        # Find best email
        email_result = self.find_best_email(firstname, lastname, company)
        
        # Generate LinkedIn URLs
        linkedin_urls = self.generate_linkedin_urls(firstname, lastname, company)
        linkedin_primary = linkedin_urls[0] if linkedin_urls else ''
        linkedin_search = self.generate_linkedin_search_url(firstname, lastname, company)
        
        return {
            'firstname': firstname,
            'lastname': lastname,
            'title': title,
            'company': company,
            'email': email_result['email'],
            'email_confidence': email_result['confidence'],
            'email_all_patterns': email_result['all_patterns'],
            'linkedin_url': linkedin_primary,
            'linkedin_alternatives': linkedin_urls[1:],
            'linkedin_search': linkedin_search,
            'enrichment_status': 'completed'
        }


# Test function
if __name__ == "__main__":
    enricher = ContactEnricher()
    
    # Test cases
    test_contacts = [
        ("John", "Doe", "Software Engineer", "Google Inc"),
        ("Jane", "Smith", "Product Manager", "Microsoft Corporation"),
        ("Robert", "Johnson", "CEO", "Amazon"),
    ]
    
    print("\n" + "="*80)
    print("CONTACT ENRICHMENT TEST")
    print("="*80)
    
    for firstname, lastname, title, company in test_contacts:
        print(f"\n{'='*80}")
        print(f"Contact: {firstname} {lastname}")
        print(f"Title: {title}")
        print(f"Company: {company}")
        print("-"*80)
        
        result = enricher.enrich_contact(firstname, lastname, title, company)
        
        print(f"Email: {result['email']}")
        print(f"Confidence: {result['email_confidence']:.0%}")
        print(f"LinkedIn: {result['linkedin_url']}")
        print(f"LinkedIn Search: {result['linkedin_search']}")
        print(f"Status: {result['enrichment_status']}")
