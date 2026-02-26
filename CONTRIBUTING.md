# Contributing to EnricherPro

First off, thank you for considering contributing to EnricherPro! It's people like you that make EnricherPro such a great tool.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Testing](#testing)

---

## 📜 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

### Our Standards

- ✅ Be respectful and inclusive
- ✅ Welcome newcomers and help them learn
- ✅ Focus on what is best for the community
- ✅ Show empathy towards other community members
- ❌ No harassment, trolling, or derogatory comments
- ❌ No spam or self-promotion

---

## 🤝 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues. When you create a bug report, include as many details as possible:

**Bug Report Template:**

```markdown
**Description**
A clear and concise description of the bug.

**Steps to Reproduce**
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Screenshots**
If applicable, add screenshots.

**Environment**
- OS: [e.g. Windows 10, macOS 13]
- Flutter Version: [e.g. 3.35.4]
- Device: [e.g. iPhone 12, Chrome Browser]
- Version: [e.g. v4.2]

**Additional Context**
Any other context about the problem.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

**Enhancement Template:**

```markdown
**Feature Description**
A clear description of the feature.

**Problem It Solves**
Explain the problem this feature would solve.

**Proposed Solution**
Describe how you envision this feature working.

**Alternatives Considered**
Any alternative solutions you've considered.

**Additional Context**
Mockups, examples, or references.
```

### Your First Code Contribution

Unsure where to begin? Look for issues labeled:

- `good-first-issue` - Simple issues perfect for newcomers
- `help-wanted` - Issues where we need community help
- `documentation` - Improvements to documentation

---

## 🛠️ Development Setup

### Prerequisites

- Flutter SDK 3.35.4
- Dart 3.9.2
- Python 3.8+
- Git
- Code editor (VS Code recommended)

### Setup Steps

1. **Fork the repository**

```bash
# Click "Fork" on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/EnricherPro.git
cd EnricherPro
```

2. **Add upstream remote**

```bash
git remote add upstream https://github.com/gershonconsulting/EnricherPro.git
```

3. **Install Flutter dependencies**

```bash
flutter pub get
```

4. **Install backend dependencies**

```bash
cd backend
pip install -r requirements.txt
cd ..
```

5. **Run the app**

```bash
# Terminal 1: Backend
python3 backend/unified_server.py

# Terminal 2: Flutter
flutter run -d chrome
```

### Development Tools

**Recommended VS Code Extensions:**

- Flutter
- Dart
- Python
- GitLens
- Error Lens
- Prettier

**Recommended Settings (`.vscode/settings.json`):**

```json
{
  "editor.formatOnSave": true,
  "dart.lineLength": 100,
  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "files.exclude": {
    "**/.dart_tool": true,
    "**/.packages": true,
    "**/build": true
  }
}
```

---

## 🔄 Pull Request Process

### Before Submitting

1. ✅ Create a feature branch: `git checkout -b feature/amazing-feature`
2. ✅ Make your changes
3. ✅ Write or update tests
4. ✅ Run tests: `flutter test`
5. ✅ Format code: `dart format .`
6. ✅ Analyze code: `flutter analyze`
7. ✅ Update documentation if needed
8. ✅ Commit with descriptive message

### Submitting

1. **Push to your fork**

```bash
git push origin feature/amazing-feature
```

2. **Create Pull Request**

- Go to your fork on GitHub
- Click "New Pull Request"
- Select your feature branch
- Fill in the PR template

**PR Template:**

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
Describe tests you ran and how to reproduce.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-reviewed my own code
- [ ] Commented code, particularly complex areas
- [ ] Updated documentation
- [ ] No new warnings
- [ ] Added tests proving fix/feature works
- [ ] New/existing tests pass locally
- [ ] Dependent changes merged and published
```

3. **Code Review**

- Wait for review from maintainers
- Address feedback promptly
- Make requested changes
- Re-request review after changes

4. **Merge**

- Once approved, maintainers will merge
- Delete your feature branch after merge

---

## 📝 Coding Standards

### Flutter/Dart

**Style Guide:**

```dart
// ✅ Good: Descriptive names, proper formatting
class ContactEnrichmentService {
  Future<Contact> enrichContact(Contact contact) async {
    if (contact.email.isEmpty) {
      final generatedEmail = await _generateEmail(contact);
      return contact.copyWith(email: generatedEmail);
    }
    return contact;
  }
}

// ❌ Bad: Unclear names, poor formatting
class CES {
  Future<Contact> enrich(Contact c) async {
    if(c.email==''){
      var e=await _gen(c);
      return c.copyWith(email:e);
    }
    return c;
  }
}
```

**Key Principles:**

- Use meaningful variable/function names
- Follow Dart style guide
- Max line length: 100 characters
- Use `const` constructors when possible
- Prefer `final` over `var`
- Use null-safety properly

### Python

**Style Guide:**

```python
# ✅ Good: Clear, documented, type-hinted
def validate_email(email: str) -> tuple[bool, float]:
    """
    Validate email format and return confidence score.
    
    Args:
        email: Email address to validate
        
    Returns:
        Tuple of (is_valid, confidence_score)
    """
    if not email or '@' not in email:
        return False, 0.0
    
    # Validation logic here
    return True, 0.85

# ❌ Bad: Unclear, no documentation
def val(e):
    if not e or '@' not in e:
        return False,0.0
    return True,0.85
```

**Key Principles:**

- Follow PEP 8
- Use type hints
- Write docstrings
- Max line length: 88 characters (Black formatter)
- Use f-strings for formatting

---

## 💬 Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

### Examples

```bash
# ✅ Good commits
feat(enrichment): add LinkedIn profile discovery
fix(csv): handle trailing spaces in headers
docs(readme): update installation instructions
test(contact): add unit tests for Contact model

# ❌ Bad commits
Update stuff
Fixed bug
Changes
WIP
```

### Detailed Example

```
feat(email-validation): add DNS/MX record verification

Implement comprehensive email validation including:
- Format validation with regex
- DNS lookup for domain existence
- MX record verification
- Optional SMTP validation

This improves email generation confidence scores by 15%.

Closes #123
```

---

## 🧪 Testing

### Running Tests

```bash
# All Flutter tests
flutter test

# Specific test file
flutter test test/models/contact_test.dart

# With coverage
flutter test --coverage

# Backend tests
cd backend
pytest
```

### Writing Tests

**Flutter Unit Test Example:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:enricher_pro/models/contact.dart';

void main() {
  group('Contact Model', () {
    test('should create contact from CSV row', () {
      final csvRow = ['John', 'Doe', 'Acme Corp', 'CEO'];
      final contact = Contact.fromCsvRow(csvRow);
      
      expect(contact.firstName, 'John');
      expect(contact.lastName, 'Doe');
      expect(contact.company, 'Acme Corp');
      expect(contact.title, 'CEO');
    });
    
    test('should split full name correctly', () {
      final contact = Contact.fromCsvRowWithMapping(
        ['', '', 'John Doe', 'Acme Corp'],
        {'fullName': 2, 'company': 3}
      );
      
      expect(contact.firstName, 'John');
      expect(contact.lastName, 'Doe');
    });
  });
}
```

**Python Test Example:**

```python
import pytest
from backend.email_validator import EmailValidator

def test_email_validation():
    validator = EmailValidator()
    
    # Test valid email
    is_valid, confidence = validator.validate("john.doe@acme.com")
    assert is_valid is True
    assert confidence > 0.5
    
    # Test invalid email
    is_valid, confidence = validator.validate("invalid-email")
    assert is_valid is False
    assert confidence == 0.0
```

### Test Coverage

- Aim for >80% code coverage
- All new features must include tests
- Bug fixes should include regression tests

---

## 📚 Additional Resources

### Learning Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [Python PEP 8](https://www.python.org/dev/peps/pep-0008/)
- [Git Best Practices](https://git-scm.com/book/en/v2)

### Community

- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: Questions and community chat
- Email: olivier@gershonconsulting.com

---

## ❓ Questions?

Don't hesitate to ask! Open an issue with the `question` label or reach out directly.

---

**Thank you for contributing to EnricherPro! 🎉**
