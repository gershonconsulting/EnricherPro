"""
Comprehensive Email Validation System
Implements: MX Records, SMTP Handshake, Catch-all Detection, Bounce Probability
"""

import dns.resolver
import smtplib
import socket
import re
import uuid
import random
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass


@dataclass
class EmailValidationResult:
    """Result of email validation with all checks"""
    email: str
    is_valid: bool
    confidence_score: float  # 0.0 to 1.0
    mx_valid: bool
    smtp_valid: Optional[bool]  # None if indeterminate
    is_catchall: bool
    bounce_probability: float
    validation_method: str
    details: str


class EmailValidator:
    """Comprehensive email validation with multiple methods"""
    
    def __init__(self, timeout: int = 10):
        self.timeout = timeout
        self.dns_resolver = dns.resolver.Resolver()
        self.dns_resolver.timeout = timeout
        self.dns_resolver.lifetime = timeout
        
    def validate_email_format(self, email: str) -> bool:
        """Basic email format validation"""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return re.match(pattern, email) is not None
    
    def get_mx_records(self, domain: str) -> List[str]:
        """Get MX records for domain"""
        try:
            mx_records = self.dns_resolver.resolve(domain, 'MX')
            return [str(record.exchange).rstrip('.') for record in mx_records]
        except (dns.resolver.NXDOMAIN, dns.resolver.NoAnswer, dns.resolver.NoNameservers):
            return []
        except Exception as e:
            if kDebugMode:
                print(f"MX lookup error for {domain}: {e}")
            return []
    
    def check_mx_records(self, domain: str) -> bool:
        """Check if domain has valid MX records"""
        mx_records = self.get_mx_records(domain)
        return len(mx_records) > 0
    
    def verify_smtp(self, email: str, mx_record: str) -> Optional[bool]:
        """
        SMTP RCPT TO verification without sending email
        Returns: True if valid, False if invalid, None if indeterminate
        """
        try:
            # Connect to mail server
            server = smtplib.SMTP(timeout=self.timeout)
            server.set_debuglevel(0)
            
            # Try to connect to MX server
            server.connect(mx_record)
            server.helo(server.local_hostname)
            server.mail('verify@validator.com')
            
            # Check if recipient exists
            code, message = server.rcpt(email)
            server.quit()
            
            # 250 = OK, 251 = User not local (but will forward)
            if code in [250, 251]:
                return True
            elif code >= 500:
                return False
            else:
                return None  # Indeterminate
                
        except smtplib.SMTPServerDisconnected:
            return None  # Server disconnected, can't verify
        except smtplib.SMTPConnectError:
            return None  # Can't connect
        except socket.timeout:
            return None  # Timeout
        except Exception as e:
            if kDebugMode:
                print(f"SMTP verification error: {e}")
            return None
    
    def is_catchall_domain(self, domain: str, mx_records: List[str]) -> bool:
        """
        Test if domain accepts all emails (catch-all)
        Tests with random non-existent addresses
        """
        if not mx_records:
            return False
        
        # Generate random test emails
        test_emails = [
            f"random{uuid.uuid4().hex[:8]}@{domain}",
            f"test{random.randint(100000, 999999)}@{domain}",
            f"nonexistent{uuid.uuid4().hex[:6]}@{domain}"
        ]
        
        accepted = 0
        for test_email in test_emails:
            result = self.verify_smtp(test_email, mx_records[0])
            if result is True:
                accepted += 1
        
        # If 2 or more random emails are accepted, it's likely catch-all
        return accepted >= 2
    
    def calculate_bounce_probability(
        self, 
        email: str,
        mx_valid: bool,
        smtp_valid: Optional[bool],
        is_catchall: bool,
        has_common_pattern: bool
    ) -> float:
        """
        Calculate probability of email bouncing (0.0 = won't bounce, 1.0 = will bounce)
        """
        # Start with neutral probability
        probability = 0.5
        
        # MX records exist - reduces bounce probability
        if mx_valid:
            probability -= 0.25
        else:
            probability += 0.35  # No MX records = very likely to bounce
        
        # SMTP verification results
        if smtp_valid is True:
            probability -= 0.30  # Verified via SMTP
        elif smtp_valid is False:
            probability += 0.40  # Rejected by SMTP
        # smtp_valid is None = no change (indeterminate)
        
        # Catch-all domains are uncertain
        if is_catchall:
            probability += 0.20
        
        # Common email patterns are more reliable
        if has_common_pattern:
            probability -= 0.10
        
        # Clamp between 0 and 1
        return max(0.0, min(1.0, probability))
    
    def check_common_pattern(self, email: str) -> bool:
        """Check if email follows common corporate patterns"""
        local_part = email.split('@')[0].lower()
        
        common_patterns = [
            r'^[a-z]+\.[a-z]+$',  # firstname.lastname
            r'^[a-z]\.[a-z]+$',   # f.lastname
            r'^[a-z]+[a-z]$',     # firstnamelastname
            r'^[a-z]+$',          # firstname
            r'^[a-z]+\.[a-z]+\d*$' # firstname.lastname123
        ]
        
        for pattern in common_patterns:
            if re.match(pattern, local_part):
                return True
        return False
    
    def validate_email_comprehensive(self, email: str) -> EmailValidationResult:
        """
        Comprehensive email validation using all methods
        Returns detailed validation result with confidence score
        """
        # Format validation
        if not self.validate_email_format(email):
            return EmailValidationResult(
                email=email,
                is_valid=False,
                confidence_score=0.0,
                mx_valid=False,
                smtp_valid=False,
                is_catchall=False,
                bounce_probability=1.0,
                validation_method="format_check",
                details="Invalid email format"
            )
        
        domain = email.split('@')[1]
        
        # Step 1: MX Record Check
        mx_valid = self.check_mx_records(domain)
        if not mx_valid:
            return EmailValidationResult(
                email=email,
                is_valid=False,
                confidence_score=0.1,
                mx_valid=False,
                smtp_valid=None,
                is_catchall=False,
                bounce_probability=0.95,
                validation_method="mx_check",
                details="No MX records found for domain"
            )
        
        mx_records = self.get_mx_records(domain)
        
        # Step 2: Catch-all Detection
        is_catchall = self.is_catchall_domain(domain, mx_records)
        
        # Step 3: SMTP Verification
        smtp_valid = None
        if mx_records and not is_catchall:
            smtp_valid = self.verify_smtp(email, mx_records[0])
        
        # Step 4: Pattern Analysis
        has_common_pattern = self.check_common_pattern(email)
        
        # Step 5: Calculate Bounce Probability
        bounce_prob = self.calculate_bounce_probability(
            email, mx_valid, smtp_valid, is_catchall, has_common_pattern
        )
        
        # Calculate confidence score (inverse of bounce probability)
        confidence = 1.0 - bounce_prob
        
        # Determine overall validity
        is_valid = confidence >= 0.5
        
        # Build details message
        details_parts = []
        if mx_valid:
            details_parts.append("MX records valid")
        if smtp_valid is True:
            details_parts.append("SMTP verified")
        elif smtp_valid is False:
            details_parts.append("SMTP rejected")
        else:
            details_parts.append("SMTP indeterminate")
        
        if is_catchall:
            details_parts.append("Catch-all domain")
        if has_common_pattern:
            details_parts.append("Common pattern")
        
        details = ", ".join(details_parts)
        
        return EmailValidationResult(
            email=email,
            is_valid=is_valid,
            confidence_score=confidence,
            mx_valid=mx_valid,
            smtp_valid=smtp_valid,
            is_catchall=is_catchall,
            bounce_probability=bounce_prob,
            validation_method="comprehensive",
            details=details
        )


# For debugging
kDebugMode = False


def validate_email(email: str) -> Dict:
    """Wrapper function for easy API use"""
    validator = EmailValidator(timeout=10)
    result = validator.validate_email_comprehensive(email)
    
    return {
        'email': result.email,
        'is_valid': result.is_valid,
        'confidence_score': round(result.confidence_score, 2),
        'mx_valid': result.mx_valid,
        'smtp_valid': result.smtp_valid,
        'is_catchall': result.is_catchall,
        'bounce_probability': round(result.bounce_probability, 2),
        'validation_method': result.validation_method,
        'details': result.details
    }


# Test function
if __name__ == "__main__":
    kDebugMode = True
    
    test_emails = [
        "john.doe@gmail.com",
        "invalid@nonexistentdomain12345.com",
        "test@example.com"
    ]
    
    validator = EmailValidator()
    
    for email in test_emails:
        print(f"\n{'='*60}")
        print(f"Testing: {email}")
        print('='*60)
        result = validator.validate_email_comprehensive(email)
        print(f"Valid: {result.is_valid}")
        print(f"Confidence: {result.confidence_score:.2%}")
        print(f"MX Valid: {result.mx_valid}")
        print(f"SMTP Valid: {result.smtp_valid}")
        print(f"Catch-all: {result.is_catchall}")
        print(f"Bounce Probability: {result.bounce_probability:.2%}")
        print(f"Details: {result.details}")
