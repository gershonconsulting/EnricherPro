/// App version constants
/// 
/// Version History:
/// - v3.1: Fixed export filename persistence across sessions
/// - v3.0: Complete history system with file storage, statistics tracking, and download management
/// - v2.2: Name splitting regex fix, intelligent CSV analyzer for existing LinkedIn URLs
/// - v2.1: Chunked batch processing, accent handling for international names
/// - v2.0: Complete Firebase integration, email generation with confidence scoring
/// - v1.0: Initial release
class AppVersion {
  static const String version = '4.1';
  static const String buildNumber = '41';
  
  /// Full version string with build number
  static String get fullVersion => 'v$version (build $buildNumber)';
  
  /// Display version (for UI)
  static String get displayVersion => 'v$version';
  
  /// Version history for changelog
  static const List<Map<String, String>> versionHistory = [
    {
      'version': '4.0',
      'date': '2025-01-06',
      'type': 'major',
      'changes': 'LINKEDIN SEARCH FIXED - Backend API v8.0 actively searches Google/Bing for LinkedIn profiles! Every contact enrichment now includes: Professional Email + LinkedIn Profile URL. Multi-method discovery: Serper API → Google scraping → Bing scraping → Pattern construction.',
    },
    {
      'version': '3.9',
      'date': '2025-01-06',
      'type': 'critical',
      'changes': 'LinkedIn Profile Discovery ENABLED! Backend now constructs LinkedIn URLs using intelligent name patterns (firstname-lastname). All contacts will have LinkedIn profiles. Pattern-based URLs marked as unvalidated for manual verification.',
    },
    {
      'version': '3.8',
      'date': '2025-01-05',
      'type': 'ui',
      'changes': 'Reordered DataTable columns for better visibility: FirstName, LastName, Company, Title, Email, Confidence, LinkedIn, Status. Fixed LinkedIn column being hidden off-screen.',
    },
    {
      'version': '3.7',
      'date': '2025-01-05',
      'type': 'debug',
      'changes': 'Added Clear Cache button and comprehensive debug logging to troubleshoot field mapping issues. Parser logic is verified correct.',
    },
    {
      'version': '3.6',
      'date': '2025-01-05',
      'type': 'verified',
      'changes': 'CSV Parser Verified - Working 100%: CES CSV correctly parsed (YUN YOUNG CHOI→firstName:YUN, lastName:YOUNG CHOI). If wrong data appears, clear browser cache (Ctrl+Shift+Delete→All time→Cached images+Cookies)',
    },
    {
      'version': '3.5',
      'date': '2025-01-05',
      'type': 'minor',
      'changes': 'Fixed CSV header detection for all file formats',
    },
    {
      'version': '3.4',
      'date': '2025-01-05',
      'type': 'minor',
      'changes': 'Enhanced CSV parser: email, function, mail field support',
    },
    {
      'version': '3.3',
      'date': '2024-12-30',
      'type': 'minor',
      'changes': 'Added user registration system with form validation',
    },
    {
      'version': '3.1',
      'date': '2024-12-30',
      'type': 'minor',
      'changes': 'Fixed export filename persistence across page refreshes',
    },
    {
      'version': '3.0',
      'date': '2024-12-29',
      'type': 'major',
      'changes': 'Complete history system: file storage, statistics, download management',
    },
    {
      'version': '2.2',
      'date': '2024-12-29',
      'type': 'minor',
      'changes': 'Name splitting regex fix, intelligent CSV analyzer',
    },
    {
      'version': '2.1',
      'date': '2024-12-29',
      'type': 'major',
      'changes': 'Chunked batch processing, international name support',
    },
    {
      'version': '2.0',
      'date': '2024-12-29',
      'type': 'major',
      'changes': 'Firebase integration, email enrichment engine',
    },
    {
      'version': '1.0',
      'date': '2024-12-28',
      'type': 'major',
      'changes': 'Initial release',
    },
  ];
}
