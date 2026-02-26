"""
Flask API Server for Contact Enrichment
Exposes email validation and LinkedIn discovery via REST API
With Snovio API integration support
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os
from pathlib import Path
from fast_contact_enricher import FastContactEnricher
from email_validator import EmailValidator

# Use FAST enricher for production (no SMTP validation)
enricher = FastContactEnricher()

# Load environment variables from .env file securely
def load_env_file():
    """Load .env file if it exists (secure credential storage)"""
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()

# Load credentials from .env file
load_env_file()

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web app

# Get Snovio credentials from environment (secure)
SNOVIO_API_KEY = os.environ.get('SNOVIO_API_KEY', None)
SNOVIO_USER_ID = os.environ.get('SNOVIO_USER_ID', None)
SNOVIO_API_SECRET = os.environ.get('SNOVIO_API_SECRET', None)

email_validator = EmailValidator()

print("⚡ Using FAST enricher mode (pattern-based, no SMTP validation)")

# Allow runtime Snovio key update
def update_snovio_key(api_key: str):
    """Update Snovio API key at runtime"""
    global enricher, SNOVIO_API_KEY
    SNOVIO_API_KEY = api_key
    enricher = ContactEnricher(snovio_api_key=api_key)
    print(f"✅ Snovio API key updated")


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'Contact Enrichment API',
        'version': '1.0.0',
        'snovio_enabled': enricher.snovio is not None
    })


@app.route('/api/config/snovio', methods=['POST'])
def configure_snovio():
    """
    Configure Snovio API credentials at runtime
    
    Supports two authentication methods:
    
    Method 1 - API Key:
    {
        "api_key": "your_snovio_api_key"
    }
    
    Method 2 - OAuth (User ID + Secret):
    {
        "api_key": "oauth:user_id:api_secret"
    }
    """
    try:
        data = request.get_json()
        
        if 'api_key' not in data or not data['api_key']:
            return jsonify({
                'error': 'Missing api_key field'
            }), 400
        
        credentials = data['api_key']
        
        # Check if OAuth credentials (format: oauth:user_id:secret)
        if credentials.startswith('oauth:'):
            parts = credentials.split(':')
            if len(parts) != 3:
                return jsonify({
                    'error': 'Invalid OAuth format. Expected: oauth:user_id:secret'
                }), 400
            
            _, user_id, api_secret = parts
            
            # Update with OAuth credentials
            global enricher, SNOVIO_API_KEY
            from snovio_integration import SnovioAPI
            SNOVIO_API_KEY = None
            enricher = ContactEnricher(snovio_api_key=None)
            enricher.snovio = SnovioAPI(client_id=user_id, client_secret=api_secret)
            
            print(f"✅ Snovio OAuth configured (User ID: {user_id[:8]}...)")
            
            return jsonify({
                'status': 'success',
                'message': 'Snovio OAuth credentials configured',
                'snovio_enabled': True,
                'auth_method': 'oauth'
            }), 200
        else:
            # Regular API key
            update_snovio_key(credentials)
            
            return jsonify({
                'status': 'success',
                'message': 'Snovio API key configured',
                'snovio_enabled': True,
                'auth_method': 'api_key'
            }), 200
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'failed'
        }), 500


@app.route('/api/enrich', methods=['POST'])
def enrich_contact():
    """
    Enrich a single contact
    Expected JSON: {
        "firstname": "John",
        "lastname": "Doe", 
        "title": "Software Engineer",
        "company": "Google"
    }
    """
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['firstname', 'lastname', 'title', 'company']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({
                    'error': f'Missing required field: {field}'
                }), 400
        
        # Enrich contact using fast method
        result = enricher.enrich_contact(
            firstname=data['firstname'],
            lastname=data['lastname'],
            title=data['title'],
            company=data['company']
        )
        
        return jsonify(result), 200
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'failed'
        }), 500


@app.route('/api/enrich/batch', methods=['POST'])
def enrich_contacts_batch():
    """
    Enrich multiple contacts at once
    Expected JSON: {
        "contacts": [
            {"firstname": "John", "lastname": "Doe", "title": "Engineer", "company": "Google"},
            {"firstname": "Jane", "lastname": "Smith", "title": "Manager", "company": "Microsoft"}
        ]
    }
    """
    try:
        data = request.get_json()
        
        if 'contacts' not in data or not isinstance(data['contacts'], list):
            return jsonify({
                'error': 'Invalid request format. Expected {"contacts": [...]}'
            }), 400
        
        results = []
        for contact in data['contacts']:
            try:
                # Validate required fields
                if all(k in contact for k in ['firstname', 'lastname', 'title', 'company']):
                    enriched = enricher.enrich_contact(
                        firstname=contact['firstname'],
                        lastname=contact['lastname'],
                        title=contact['title'],
                        company=contact['company']
                    )
                    results.append(enriched)
                else:
                    results.append({
                        **contact,
                        'email': '',
                        'email_confidence': 0.0,
                        'linkedin_url': '',
                        'enrichment_status': 'missing_fields'
                    })
            except Exception as e:
                results.append({
                    **contact,
                    'email': '',
                    'email_confidence': 0.0,
                    'linkedin_url': '',
                    'enrichment_status': f'error: {str(e)}'
                })
        
        return jsonify({
            'results': results,
            'total': len(results),
            'status': 'completed'
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'failed'
        }), 500


@app.route('/api/validate/email', methods=['POST'])
def validate_email():
    """
    Validate a single email address
    Expected JSON: {"email": "john.doe@example.com"}
    """
    try:
        data = request.get_json()
        
        if 'email' not in data:
            return jsonify({'error': 'Missing email field'}), 400
        
        result = email_validator.validate_email_comprehensive(data['email'])
        
        return jsonify({
            'email': result.email,
            'is_valid': result.is_valid,
            'confidence_score': round(result.confidence_score, 2),
            'mx_valid': result.mx_valid,
            'smtp_valid': result.smtp_valid,
            'is_catchall': result.is_catchall,
            'bounce_probability': round(result.bounce_probability, 2),
            'details': result.details
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'failed'
        }), 500


@app.route('/api/patterns/email', methods=['POST'])
def generate_email_patterns():
    """
    Generate email patterns without validation
    Expected JSON: {
        "firstname": "John",
        "lastname": "Doe",
        "company": "Google"
    }
    """
    try:
        data = request.get_json()
        
        required = ['firstname', 'lastname', 'company']
        if not all(k in data for k in required):
            return jsonify({'error': 'Missing required fields'}), 400
        
        patterns = enricher.generate_email_patterns(
            data['firstname'],
            data['lastname'],
            data['company']
        )
        
        return jsonify({
            'patterns': patterns,
            'count': len(patterns)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/patterns/linkedin', methods=['POST'])
def generate_linkedin_patterns():
    """
    Generate LinkedIn URL patterns
    Expected JSON: {
        "firstname": "John",
        "lastname": "Doe",
        "company": "Google"
    }
    """
    try:
        data = request.get_json()
        
        required = ['firstname', 'lastname', 'company']
        if not all(k in data for k in required):
            return jsonify({'error': 'Missing required fields'}), 400
        
        urls = enricher.generate_linkedin_urls(
            data['firstname'],
            data['lastname'],
            data['company']
        )
        
        search_url = enricher.generate_linkedin_search_url(
            data['firstname'],
            data['lastname'],
            data['company']
        )
        
        return jsonify({
            'linkedin_urls': urls,
            'linkedin_search': search_url,
            'count': len(urls)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print("\n" + "="*60)
    print("🚀 Contact Enrichment API Server")
    print("="*60)
    print("\nAvailable Endpoints:")
    print("  GET  /health                    - Health check")
    print("  POST /api/config/snovio         - Configure Snovio API key")
    print("  POST /api/enrich                - Enrich single contact")
    print("  POST /api/enrich/batch          - Enrich multiple contacts")
    print("  POST /api/validate/email        - Validate email address")
    print("  POST /api/patterns/email        - Generate email patterns")
    print("  POST /api/patterns/linkedin     - Generate LinkedIn URLs")
    print("\n" + "="*60)
    print("Starting server on http://0.0.0.0:5000")
    print("="*60 + "\n")
    
    app.run(host='0.0.0.0', port=5000, debug=False)
