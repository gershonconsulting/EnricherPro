"""
Snovio API Integration for Email Finder
Used as a fallback when confidence is below 50%
"""

import requests
import json
from typing import Dict, Optional


class SnovioAPI:
    """Snovio Email Finder API Integration"""
    
    def __init__(self, api_key: str = None, client_id: str = None, client_secret: str = None):
        """
        Initialize Snovio API client
        
        You can use either:
        - API Key (simpler)
        - Client ID + Client Secret (OAuth)
        """
        self.api_key = api_key
        self.client_id = client_id
        self.client_secret = client_secret
        self.base_url = "https://api.snov.io/v1"
        self.access_token = None
        
        # If using OAuth, get access token
        if client_id and client_secret and not api_key:
            self.access_token = self._get_access_token()
    
    def _get_access_token(self) -> Optional[str]:
        """Get OAuth access token using client credentials"""
        try:
            url = f"{self.base_url}/oauth/access_token"
            data = {
                'grant_type': 'client_credentials',
                'client_id': self.client_id,
                'client_secret': self.client_secret
            }
            
            response = requests.post(url, data=data, timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                return result.get('access_token')
            else:
                print(f"Failed to get Snovio access token: {response.status_code}")
                return None
        except Exception as e:
            print(f"Error getting Snovio access token: {e}")
            return None
    
    def _get_headers(self) -> Dict[str, str]:
        """Get request headers with authentication"""
        if self.api_key:
            return {'Authorization': f'Bearer {self.api_key}'}
        elif self.access_token:
            return {'Authorization': f'Bearer {self.access_token}'}
        else:
            return {}
    
    def find_email(
        self, 
        first_name: str, 
        last_name: str, 
        domain: str
    ) -> Optional[Dict]:
        """
        Find email using Snovio Email Finder API
        
        Args:
            first_name: Person's first name
            last_name: Person's last name
            domain: Company domain (e.g., 'google.com')
        
        Returns:
            {
                'email': 'found@email.com',
                'status': 'valid/invalid/catch-all',
                'confidence': 0.95
            }
        """
        try:
            url = f"{self.base_url}/get-emails-from-names"
            
            params = {
                'firstName': first_name,
                'lastName': last_name,
                'domain': domain
            }
            
            headers = self._get_headers()
            
            response = requests.post(
                url, 
                json=params,
                headers=headers,
                timeout=10  # Reduced from 15 to 10 seconds
            )
            
            if response.status_code == 200:
                data = response.json()
                
                # Parse Snovio response
                if data.get('success') and data.get('data'):
                    emails = data['data'].get('emails', [])
                    
                    if emails:
                        # Get the first/best email
                        best_email = emails[0]
                        
                        return {
                            'email': best_email.get('email'),
                            'status': best_email.get('status', 'unknown'),
                            'confidence': self._map_snovio_confidence(best_email),
                            'source': 'snovio',
                            'found': True
                        }
                
                return {
                    'email': None,
                    'found': False,
                    'source': 'snovio',
                    'confidence': 0.0
                }
            
            else:
                print(f"Snovio API error: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"Error calling Snovio API: {e}")
            return None
    
    def _map_snovio_confidence(self, email_data: Dict) -> float:
        """
        Map Snovio email status to confidence score
        
        Snovio statuses:
        - valid: Email exists and is deliverable
        - invalid: Email does not exist
        - catch-all: Domain accepts all emails
        - unknown: Cannot determine
        """
        status = email_data.get('status', 'unknown').lower()
        
        # Map status to confidence
        confidence_map = {
            'valid': 0.95,      # Very high confidence
            'catch-all': 0.60,  # Medium confidence
            'unknown': 0.50,    # Neutral
            'invalid': 0.10     # Very low confidence
        }
        
        return confidence_map.get(status, 0.50)
    
    def verify_email(self, email: str) -> Optional[Dict]:
        """
        Verify a single email using Snovio
        
        Args:
            email: Email address to verify
        
        Returns:
            {
                'email': 'email@example.com',
                'status': 'valid/invalid',
                'confidence': 0.90
            }
        """
        try:
            url = f"{self.base_url}/verify-emails"
            
            params = {
                'emails': [email]
            }
            
            headers = self._get_headers()
            
            response = requests.post(
                url,
                json=params,
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get('success') and data.get('data'):
                    results = data['data']
                    if results:
                        result = results[0]
                        return {
                            'email': result.get('email'),
                            'status': result.get('status'),
                            'confidence': self._map_snovio_confidence(result),
                            'source': 'snovio_verify'
                        }
            
            return None
            
        except Exception as e:
            print(f"Error verifying email with Snovio: {e}")
            return None


def test_snovio_api():
    """Test function for Snovio API"""
    
    # TODO: Add your Snovio credentials here
    API_KEY = "YOUR_SNOVIO_API_KEY"  # or use client_id/client_secret
    
    snovio = SnovioAPI(api_key=API_KEY)
    
    # Test email finder
    print("\n" + "="*60)
    print("Testing Snovio Email Finder")
    print("="*60)
    
    test_cases = [
        ("John", "Doe", "google.com"),
        ("Jane", "Smith", "microsoft.com"),
    ]
    
    for first, last, domain in test_cases:
        print(f"\nFinding email for: {first} {last} @ {domain}")
        result = snovio.find_email(first, last, domain)
        if result:
            print(f"  Result: {result}")
        else:
            print("  No result found")


if __name__ == "__main__":
    test_snovio_api()
