# EnricherPro - Professional B2B Contact Enrichment Platform

**Version:** v4.2  
**Build:** 42  
**Platform:** Flutter Web + Python Backend

---

## 🎯 Overview

EnricherPro is a professional B2B contact enrichment platform that helps you:
- ✅ Upload and parse CSV contact lists
- ✅ Auto-detect column mappings
- ✅ Generate professional email addresses
- ✅ Discover LinkedIn profiles
- ✅ Validate email deliverability
- ✅ Export enriched data

---

## 🚀 Features

### 📊 CSV Management
- Smart column auto-detection
- Support for multiple CSV formats
- Handles international names and special characters
- Preserves original data structure

### ✉️ Email Enrichment (v2.0)
- Multiple email pattern generation
- DNS/MX record verification
- Domain validation
- Confidence scoring (0-100%)
- 8+ email pattern testing per contact

### 🔗 LinkedIn Discovery
- Auto-generates LinkedIn profile URLs
- Multiple URL pattern attempts
- Profile format validation

### 📈 Batch Processing
- Process up to 50 contacts per batch
- Real-time progress tracking
- Error handling and retry logic

### 💾 Data Export
- Smart filename generation (original_enriched_YYYYMMDD.csv)
- Includes all enriched data
- Google Sheets compatible format

---

## 🛠️ Technology Stack

### Frontend
- **Framework:** Flutter 3.35.4
- **Language:** Dart 3.9.2
- **UI:** Material Design 3
- **State Management:** Provider
- **Storage:** Hive (local browser storage)

### Backend
- **Framework:** Flask (Python)
- **Email Validation:** dnspython
- **CORS:** flask-cors

### Key Dependencies
```yaml
dependencies:
  flutter: 3.35.4
  provider: 6.1.5+1
  http: 1.5.0
  hive: 2.2.3
  hive_flutter: 1.1.0
  shared_preferences: 2.5.3
  csv: 6.0.0
```

---

## 📁 Project Structure

```
enricherpro/
├── lib/
│   ├── constants/
│   │   └── app_version.dart          # Version management
│   ├── models/
│   │   ├── contact.dart               # Contact data model
│   │   ├── file_upload.dart           # File upload model
│   │   └── csv_field_analysis.dart    # CSV analysis model
│   ├── providers/
│   │   └── contact_provider.dart      # State management
│   ├── screens/
│   │   ├── landing_screen.dart        # Landing page
│   │   ├── registration_screen.dart   # User registration
│   │   ├── main_layout.dart           # App layout
│   │   ├── contacts_screen.dart       # Contact list UI
│   │   ├── history_screen.dart        # Upload history
│   │   └── dashboard_screen.dart      # Dashboard
│   ├── services/
│   │   ├── api_service.dart           # Backend API client
│   │   ├── csv_service.dart           # CSV parsing
│   │   └── file_upload_service.dart   # File management
│   └── main.dart                      # App entry point
├── android/                            # Android platform files
├── web/                                # Web platform files
├── assets/                             # Images and assets
├── fullstack_server_v2.py             # Backend API server
└── pubspec.yaml                        # Dependencies

```

---

## 🚦 Getting Started

### Prerequisites
- Flutter SDK 3.35.4
- Dart SDK 3.9.2
- Python 3.8+
- pip (Python package manager)

### Installation

**1. Clone the repository:**
```bash
git clone https://github.com/gershonconsulting/enricherpro.git
cd enricherpro
```

**2. Install Flutter dependencies:**
```bash
flutter pub get
```

**3. Install Python dependencies:**
```bash
pip install flask flask-cors dnspython
```

**4. Run the backend API:**
```bash
python3 fullstack_server_v2.py
```

**5. Build Flutter web:**
```bash
flutter build web --release
```

**6. Access the app:**
```
http://localhost:5060
```

---

## 🎮 Usage Guide

### 1. Upload CSV File
1. Click "Load New CSV" button
2. Select your CSV file
3. System auto-detects columns

### 2. Enrich Contacts
1. Click the floating "Enrich Contacts" button
2. Wait for batch processing to complete
3. View generated emails and LinkedIn URLs

### 3. Review Results
- ✅ Green "completed" status
- 📊 Confidence scores (30-85%)
- ✉️ Generated emails
- 🔗 LinkedIn profile URLs

### 4. Export Data
1. Click "Export CSV"
2. Download enriched file
3. Filename: `original_enriched_20250105.csv`

---

## 📊 CSV Format Support

### Supported Column Names

**First Name:**
- `First Name`, `FirstName`, `first`, `firstName`

**Last Name:**
- `Last Name`, `LastName`, `last`, `lastName`

**Full Name:**
- `Name`, `Full Name`, `fullName`, `CEO Name`, `Contact Name`

**Company:**
- `Company`, `Company Name`, `Organization`, `Employer`

**Title:**
- `Title`, `Job Title`, `Function`, `Role`, `Position`

**Email:**
- `Email`, `email`, `E-mail`, `mail`, `Email Address`

**LinkedIn:**
- `LinkedIn`, `LinkedIn URL`, `linkedin`, `Linkedin`

### Example CSV Format

```csv
First Name,Last Name,Company,Title,Email,LinkedIn
John,Doe,Acme Inc,CEO,,
Jane,Smith,TechCorp,CTO,,
```

---

## 🔧 Configuration

### Email Validation Settings

Edit `fullstack_server_v2.py`:

```python
# Email pattern generation
def generate_email_patterns(first_name, last_name, domain):
    patterns = [
        f"{first}.{last}@{domain}",      # john.doe@company.com
        f"{first}{last}@{domain}",       # johndoe@company.com
        f"{first[0]}{last}@{domain}",    # jdoe@company.com
        # Add more patterns...
    ]
```

### Custom Domain Mapping

Add known company domains:

```python
company_domains = {
    "Hyundai Motor France": "hyundai.fr",
    "Acme Corporation": "acme.com",
    # Add more mappings...
}
```

---

## 📈 Version History

### v4.2 (Current)
- Better error messages with diagnostic tooltips
- Enhanced column layout for better visibility
- Fixed LinkedIn column display issues

### v4.1
- Added error banner for enrichment failures
- Improved status chip display
- Better error categorization

### v3.8
- Reordered DataTable columns
- Fixed LinkedIn column visibility

### v2.0 (Backend)
- Advanced email validation with MX records
- LinkedIn profile discovery
- Multiple email pattern testing

### v1.0
- Initial release
- Basic CSV upload and parsing
- Simple email generation

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

## 📄 License

Copyright © 2024-2025 Gershon Consulting  
All rights reserved.

---

## 🆘 Support

For support, contact:
- **Email:** olivier@gershonconsulting.com
- **GitHub Issues:** https://github.com/gershonconsulting/enricherpro/issues

---

## 🙏 Acknowledgments

Built with:
- Flutter framework
- Flask web framework
- dnspython library
- Material Design components

---

**EnricherPro** - Professional B2B Contact Enrichment Made Simple
