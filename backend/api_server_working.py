"""
WORKING Flask API Server - FAST pattern-based enrichment only
NO SMTP, NO MX lookups, NO Snovio - Just pattern generation
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import re
from urllib.parse import quote

app = Flask(__name__)
CORS(app)


def clean_name(name: str) -> str:
    cleaned = re.sub(r'[^a-zA-Z\s-]', '', name)
    return cleaned.lower().strip()


def extract_domain(company: str) -> str:
    """Extract domain from company name"""
    # Remove common suffixes
    company = re.sub(r'\b(inc|llc|ltd|corp|corporation|company|co)\b', '', company.lower())
    # Keep only alphanumeric
    company = re.sub(r'[^a-z0-9\s]', '', company).strip()
    # Take first word
    words = company.split()
    return f"{words[0]}.com" if words else "company.com"


def generate_email(firstname: str, lastname: str, company: str) -> tuple:
    """Generate email pattern instantly"""
    first = clean_name(firstname).split()[0] if firstname else ''
    last = clean_name(lastname).split()[-1] if lastname else ''
    domain = extract_domain(company)
    
    if not first or not last:
        return '', 0.0
    
    email = f"{first}.{last}@{domain}"
    
    # Higher confidence for known companies
    known_companies = ['google', 'microsoft', 'amazon', 'apple', 'facebook', 'meta', 'ibm', 'oracle']
    confidence = 0.75 if any(c in company.lower() for c in known_companies) else 0.50
    
    return email, confidence


def generate_linkedin(firstname: str, lastname: str) -> str:
    """Generate LinkedIn URL instantly"""
    first = clean_name(firstname).split()[0] if firstname else ''
    last = clean_name(lastname).split()[-1] if lastname else ''
    
    if not first or not last:
        return ''
    
    return f"https://www.linkedin.com/in/{first}-{last}"


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'Contact Enrichment API',
        'version': '2.0.0',
        'mode': 'fast',
        'snovio_enabled': False
    })


@app.route('/api/enrich', methods=['POST'])
def enrich_single():
    """Enrich single contact - INSTANT"""
    try:
        data = request.get_json()
        
        firstname = data.get('firstname', '')
        lastname = data.get('lastname', '')
        title = data.get('title', '')
        company = data.get('company', '')
        
        email, confidence = generate_email(firstname, lastname, company)
        linkedin = generate_linkedin(firstname, lastname)
        
        return jsonify({
            'firstname': firstname,
            'lastname': lastname,
            'title': title,
            'company': company,
            'email': email,
            'email_confidence': confidence,
            'linkedin_url': linkedin,
            'enrichment_status': 'completed'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/enrich/batch', methods=['POST'])
def enrich_batch():
    """Enrich multiple contacts - INSTANT"""
    try:
        data = request.get_json()
        contacts = data.get('contacts', [])
        
        results = []
        for contact in contacts:
            firstname = contact.get('firstname', '')
            lastname = contact.get('lastname', '')
            title = contact.get('title', '')
            company = contact.get('company', '')
            
            email, confidence = generate_email(firstname, lastname, company)
            linkedin = generate_linkedin(firstname, lastname)
            
            results.append({
                'firstname': firstname,
                'lastname': lastname,
                'title': title,
                'company': company,
                'email': email,
                'email_confidence': confidence,
                'linkedin_url': linkedin,
                'enrichment_status': 'completed'
            })
        
        return jsonify({
            'results': results,
            'total': len(results),
            'status': 'completed'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print("\n" + "="*60)
    print("⚡ FAST Contact Enrichment API")
    print("="*60)
    print("\nMode: Pattern-based (NO SMTP validation)")
    print("Speed: INSTANT results")
    print("\nEndpoints:")
    print("  GET  /health")
    print("  POST /api/enrich")
    print("  POST /api/enrich/batch")
    print("\n" + "="*60)
    print("Starting on http://0.0.0.0:5000\n")
    
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
