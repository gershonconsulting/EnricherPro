# EnricherPro Version Management Guide

## Current Version: v2.2

## Version Numbering System

### Major Updates (+1.0)
Increment major version for:
- New core features (e.g., Firebase integration, new enrichment methods)
- Complete system overhauls
- Breaking changes to data structure
- New major UI sections

**Examples:**
- v1.0 → v2.0: Added Firebase integration + Email enrichment
- v2.0 → v3.0: Would be adding LinkedIn scraping + Company intelligence

### Minor Updates (+0.1)
Increment minor version for:
- Bug fixes (e.g., regex fixes, UI corrections)
- Small feature improvements
- Performance optimizations
- UI/UX tweaks

**Examples:**
- v2.1 → v2.2: Fixed name splitting regex bug
- v2.2 → v2.3: Would be adding CSV export improvements

## How to Update Version

### Step 1: Update Constants
Edit `/lib/constants/app_version.dart`:

```dart
class AppVersion {
  static const String version = '2.3';  // Update this
  static const String buildNumber = '23';  // Update this
```

### Step 2: Add to Version History
Add entry to `versionHistory` in same file:

```dart
{
  'version': '2.3',
  'date': '2024-12-30',
  'type': 'minor',  // or 'major'
  'changes': 'Your change description here',
},
```

### Step 3: Rebuild
```bash
cd /home/user/flutter_app
flutter build web --release
```

### Step 4: Restart Server
The version will automatically appear in:
- Landing page (bottom right)
- Settings screen (About section)

## Version History

### v2.2 (2024-12-29) - Minor Update
**Changes:**
- Fixed name splitting regex bug (\\s+ → \s+)
- Intelligent CSV analyzer for existing LinkedIn URLs
- Improved column detection for various CSV formats

### v2.1 (2024-12-29) - Major Update
**Changes:**
- Chunked batch processing (50 contacts per batch)
- International name support (accent handling)
- Optimized for large datasets (2000+ contacts)

### v2.0 (2024-12-29) - Major Update
**Changes:**
- Complete Firebase integration
- Email generation engine with confidence scoring
- MX record validation
- Company domain recognition

### v1.0 (2024-12-28) - Initial Release
**Changes:**
- CSV upload and parsing
- Contact management
- Basic enrichment workflow
- Landing page and UI

## Quick Reference

| Update Type | Version Change | Example |
|-------------|----------------|---------|
| Major Feature | +1.0 | v2.0 → v3.0 |
| Bug Fix | +0.1 | v2.2 → v2.3 |
| UI Tweak | +0.1 | v2.3 → v2.4 |
| New Module | +1.0 | v2.4 → v3.0 |

## Where Version Appears

1. **Landing Page**: Bottom right corner with badge styling
2. **Settings Screen**: About section with blue badge
3. **Build Info**: Available via `AppVersion.fullVersion`

## Testing After Version Update

1. Clear browser cache
2. Navigate to landing page
3. Check bottom right for new version
4. Go to Settings → About
5. Verify version displays correctly
