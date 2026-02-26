# 🚀 EnricherPro v4.2

**Professional Contact Enrichment Platform** - Transform your CSV contact lists with AI-powered email validation and LinkedIn discovery.

[![Flutter Version](https://img.shields.io/badge/Flutter-3.35.4-02569B?logo=flutter)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.9.2-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)](#platforms)

---

## 📋 Table of Contents

- [Features](#-features)
- [Demo](#-demo)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Usage](#-usage)
- [Architecture](#-architecture)
- [API Documentation](#-api-documentation)
- [Development](#-development)
- [Deployment](#-deployment)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

### 🎯 Core Features

- **📊 Smart CSV Import** - Intelligent column detection and mapping
- **📧 Email Generation** - Multiple email pattern algorithms with confidence scoring (60-95%)
- **🔍 Email Validation** - Format validation, DNS/MX record verification, optional SMTP checks
- **🔗 LinkedIn Discovery** - Profile URL validation and verification
- **⚡ Batch Processing** - Process up to 50 contacts per batch with real-time progress
- **📤 Export Enriched Data** - Download CSV with generated emails and confidence scores
- **📜 History Tracking** - Complete audit trail of all enrichment operations
- **👤 User Management** - Registration, authentication, and profile management

### 🛠️ Technical Features

- **Cross-Platform** - Runs on Android, iOS, and Web
- **Responsive UI** - Material Design 3 with adaptive layouts
- **Offline Support** - Local data persistence with Hive database
- **RESTful API** - Full-featured backend with CORS support
- **Real-time Updates** - Live progress tracking during enrichment
- **Error Recovery** - Robust error handling with retry mechanisms

---

## 🎬 Demo

**Live Demo:** [https://5060-igok3o2cnonx3mhhv0baf-cbeee0f9.sandbox.novita.ai](https://5060-igok3o2cnonx3mhhv0baf-cbeee0f9.sandbox.novita.ai)

### Screenshot Gallery

```
Coming Soon: Add screenshots of your app here
```

---

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK:** 3.35.4
- **Dart:** 3.9.2
- **Python:** 3.8+ (for backend)
- **Git:** Latest version

### 30-Second Setup

```bash
# Clone the repository
git clone https://github.com/gershonconsulting/EnricherPro.git
cd EnricherPro

# Install Flutter dependencies
flutter pub get

# Start the backend server
python3 backend/unified_server.py &

# Run the app
flutter run -d chrome
```

---

## 📦 Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/gershonconsulting/EnricherPro.git
cd EnricherPro
```

### Step 2: Install Flutter Dependencies

```bash
flutter pub get
```

**Key Dependencies:**
```yaml
dependencies:
  flutter: sdk: flutter
  provider: 6.1.5+1          # State management
  http: 1.5.0                # API client
  hive: 2.2.3                # Local database
  hive_flutter: 1.1.0        # Hive Flutter integration
  file_picker: 8.1.6         # File selection
  csv: 6.0.0                 # CSV parsing
  intl: 0.19.0               # Internationalization
```

### Step 3: Install Backend Dependencies

```bash
cd backend
pip install -r requirements.txt
```

**Backend Requirements:**
```txt
fastapi==0.104.1
uvicorn==0.24.0
python-dotenv==1.0.0
dnspython==2.4.2
requests==2.31.0
```

### Step 4: Configure Environment (Optional)

Create `.env` file in `backend/` directory:

```env
# API Configuration
API_HOST=0.0.0.0
API_PORT=5060
DEBUG=true

# Email Validation
ENABLE_SMTP_VALIDATION=false
SMTP_TIMEOUT=10

# LinkedIn Integration
LINKEDIN_API_KEY=your_key_here  # Optional
```

---

## 📖 Usage

### Running the Application

#### Web Platform (Recommended for Testing)

```bash
# Terminal 1: Start backend
cd backend
python3 unified_server.py

# Terminal 2: Run Flutter web
cd ..
flutter run -d chrome
```

#### Android/iOS

```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

#### Production Build

```bash
# Web
flutter build web --release

# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

### Using EnricherPro

#### 1. Upload CSV

- Click **"Load New CSV"** button
- Select your CSV file with contact information
- Supported columns: First Name, Last Name, Company, Title, Email, LinkedIn

#### 2. Review Contacts

- View parsed contacts in the data table
- Verify column mapping is correct
- Check for any parsing errors

#### 3. Enrich Contacts

- Click the **"Enrich Contacts"** floating button
- Watch real-time progress as contacts are processed
- See confidence scores for generated emails

#### 4. Export Results

- Click **"Export CSV"** button
- Download enriched CSV with:
  - Original contact data
  - Generated email addresses
  - Confidence scores (60-95%)
  - LinkedIn validation status

### CSV Format Requirements

**Minimum Required Columns:**
- First Name (or Full Name)
- Last Name
- Company

**Optional Columns:**
- Email
- Title/Function
- LinkedIn URL
- Phone
- Any custom fields

**Example CSV:**

```csv
First Name,Last Name,Company,Title,Email,LinkedIn
John,Doe,Acme Corp,CEO,john.doe@acme.com,https://linkedin.com/in/johndoe
Jane,Smith,Tech Inc,CTO,,https://linkedin.com/in/janesmith
Bob,Johnson,StartupXYZ,Founder,bob@startupxyz.com,
```

---

## 🏗️ Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    EnricherPro v4.2                      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐         ┌──────────────┐              │
│  │   Flutter    │◄───────►│   Backend    │              │
│  │   Frontend   │  HTTP   │   API        │              │
│  │              │  REST   │  (Python)    │              │
│  └──────────────┘         └──────────────┘              │
│         │                        │                       │
│         │                        │                       │
│    ┌────▼────┐            ┌─────▼──────┐               │
│    │  Hive   │            │  Email     │               │
│    │  Local  │            │  Validator │               │
│    │  Storage│            └────────────┘               │
│    └─────────┘                                          │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Frontend Architecture (Flutter)

```
lib/
├── main.dart                    # App entry point
├── constants/
│   └── app_version.dart        # Version management
├── models/
│   ├── contact.dart            # Contact data model
│   ├── file_upload.dart        # File upload model
│   └── csv_field_analysis.dart # CSV analysis model
├── providers/
│   └── contact_provider.dart   # State management
├── screens/
│   ├── landing_screen.dart     # Welcome screen
│   ├── contacts_screen.dart    # Main contacts view
│   ├── history_screen.dart     # Enrichment history
│   └── registration_screen.dart # User registration
├── services/
│   ├── api_service.dart        # Backend API client
│   ├── csv_service.dart        # CSV parsing
│   └── file_upload_service.dart # File management
└── widgets/
    ├── csv_field_analysis_dialog.dart
    └── file_upload_banner.dart
```

### Backend Architecture (Python)

```
backend/
├── unified_server.py           # Main FastAPI server
├── api_server.py               # API endpoints
├── email_validator.py          # Email validation logic
├── contact_enricher.py         # Enrichment algorithms
└── requirements.txt            # Python dependencies
```

---

## 🔌 API Documentation

### Base URL

```
http://localhost:5060/api
```

### Endpoints

#### 1. Health Check

```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "EnricherPro API v2.0",
  "version": "2.0.0",
  "features": [
    "email_validation",
    "linkedin_discovery",
    "batch_processing"
  ]
}
```

#### 2. Enrich Single Contact

```http
POST /api/enrich
Content-Type: application/json
```

**Request Body:**
```json
{
  "firstName": "John",
  "lastName": "Doe",
  "company": "Acme Corp",
  "title": "CEO",
  "email": "",
  "linkedInUrl": ""
}
```

**Response:**
```json
{
  "firstName": "John",
  "lastName": "Doe",
  "company": "Acme Corp",
  "title": "CEO",
  "email": "john.doe@acmecorp.com",
  "emailConfidence": 0.85,
  "linkedInUrl": "https://linkedin.com/in/johndoe",
  "linkedInValidated": true,
  "enrichmentStatus": "completed"
}
```

#### 3. Batch Enrichment

```http
POST /api/enrich/batch
Content-Type: application/json
```

**Request Body:**
```json
{
  "contacts": [
    {
      "firstName": "John",
      "lastName": "Doe",
      "company": "Acme Corp",
      "title": "CEO"
    },
    // ... up to 50 contacts
  ]
}
```

**Response:**
```json
{
  "enrichedContacts": [
    {
      "firstName": "John",
      "lastName": "Doe",
      "email": "john.doe@acmecorp.com",
      "emailConfidence": 0.85,
      "enrichmentStatus": "completed"
    }
  ],
  "summary": {
    "total": 50,
    "enriched": 48,
    "failed": 2
  }
}
```

---

## 🛠️ Development

### Project Structure

```
EnricherPro/
├── .github/
│   └── workflows/
│       └── flutter-ci.yml      # GitHub Actions CI/CD
├── android/                     # Android platform code
├── ios/                        # iOS platform code
├── web/                        # Web platform code
├── lib/                        # Flutter source code
├── backend/                    # Python backend
├── assets/                     # Images, icons, fonts
├── test/                       # Unit tests
├── pubspec.yaml                # Flutter dependencies
└── README.md                   # This file
```

### Running Tests

```bash
# Flutter unit tests
flutter test

# Flutter widget tests
flutter test test/widget_test.dart

# Backend tests
cd backend
pytest
```

### Code Style

**Flutter/Dart:**
```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Fix common issues
dart fix --apply
```

**Python:**
```bash
# Format code
black backend/

# Lint code
flake8 backend/

# Type checking
mypy backend/
```

### Building for Production

#### Web Deployment

```bash
# Build for web
flutter build web --release

# Serve locally
python3 -m http.server 5060 --directory build/web
```

#### Android APK

```bash
# Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### iOS App

```bash
# Build iOS (macOS only)
flutter build ios --release

# Output: build/ios/iphoneos/Runner.app
```

---

## 🚢 Deployment

### Deploying to Web Hosting

**Option 1: Firebase Hosting**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase
firebase init hosting

# Deploy
flutter build web --release
firebase deploy
```

**Option 2: Netlify**

```bash
# Build the app
flutter build web --release

# Drag and drop build/web folder to Netlify
# Or use Netlify CLI:
netlify deploy --prod --dir=build/web
```

**Option 3: GitHub Pages**

```bash
# Build for GitHub Pages
flutter build web --release --base-href "/EnricherPro/"

# Push to gh-pages branch
git subtree push --prefix build/web origin gh-pages
```

### Deploying Backend API

**Option 1: Heroku**

```bash
# Create Procfile
echo "web: python3 backend/unified_server.py" > Procfile

# Deploy
heroku create enricherpro-api
git push heroku main
```

**Option 2: Docker**

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY backend/ /app/backend/
COPY requirements.txt /app/

RUN pip install -r requirements.txt

EXPOSE 5060
CMD ["python3", "backend/unified_server.py"]
```

```bash
# Build and run
docker build -t enricherpro-api .
docker run -p 5060:5060 enricherpro-api
```

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

1. Check existing issues first
2. Create a new issue with:
   - Clear description
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Run tests: `flutter test`
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Development Guidelines

- Follow Flutter/Dart style guide
- Write tests for new features
- Update documentation
- Keep commits atomic and descriptive

---

## 📝 Version History

### v4.2 (Current) - 2025-01-05
- ✅ Advanced email validation with DNS/MX records
- ✅ LinkedIn profile discovery
- ✅ Improved error handling and retry mechanisms
- ✅ Better UI with diagnostic tooltips
- ✅ Full-stack integration with CORS support

### v4.1 - 2025-01-05
- ✅ Enhanced error messages
- ✅ Retry button for failed enrichments
- ✅ Status chip improvements

### v4.0 - 2025-01-05
- ✅ Complete backend API integration
- ✅ Real-time enrichment progress
- ✅ Batch processing support

### v3.8 - 2025-01-05
- ✅ Column layout improvements
- ✅ LinkedIn column now visible

### v3.5 - 2025-01-05
- ✅ Fixed CSV header detection
- ✅ Improved column mapping

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Authors

**Olivier Gershon** - [Gershon Consulting](https://gershonconsulting.com)

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- FastAPI for the elegant Python backend
- Material Design for UI inspiration
- Open source community

---

## 📞 Support

- **Email:** olivier@gershonconsulting.com
- **Issues:** [GitHub Issues](https://github.com/gershonconsulting/EnricherPro/issues)
- **Documentation:** [Wiki](https://github.com/gershonconsulting/EnricherPro/wiki)

---

## 🌟 Star History

If you find this project useful, please consider giving it a ⭐️ on GitHub!

---

**Made with ❤️ by Gershon Consulting**
