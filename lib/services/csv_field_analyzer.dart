import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import '../models/csv_field_analysis.dart';

class CsvFieldAnalyzer {
  /// Analyze CSV file and detect field types and mappings
  static Future<CsvFieldAnalysis> analyzeFile({
    required Uint8List bytes,
    required String fileUploadId,
  }) async {
    // Decode bytes to string
    final csvString = utf8.decode(bytes);
    
    // Parse CSV
    final List<List<dynamic>> rows = const CsvToListConverter().convert(
      csvString,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // Check if first row is header
    final hasHeader = _isHeaderRow(rows[0]);
    final headerRow = hasHeader ? rows[0] : _generateGenericHeaders(rows[0].length);
    final dataStartRow = hasHeader ? 1 : 0;

    // Analyze each column
    final fields = <CsvFieldInfo>[];
    
    for (int colIndex = 0; colIndex < headerRow.length; colIndex++) {
      final columnName = headerRow[colIndex].toString().trim();
      
      // Collect sample values from this column (max 5 samples)
      final sampleValues = <String>[];
      for (int rowIndex = dataStartRow; 
           rowIndex < rows.length && sampleValues.length < 5; 
           rowIndex++) {
        if (colIndex < rows[rowIndex].length) {
          final value = rows[rowIndex][colIndex].toString().trim();
          if (value.isNotEmpty) {
            sampleValues.add(value);
          }
        }
      }

      // Detect field type and mapping
      final detectedType = _detectFieldType(sampleValues);
      final mapping = _detectFieldMapping(columnName, sampleValues, detectedType);
      
      fields.add(CsvFieldInfo(
        columnName: columnName,
        detectedType: detectedType,
        mappedTo: mapping.mappedTo,
        sampleValues: sampleValues,
        columnIndex: colIndex,
        confidence: mapping.confidence,
      ));
    }

    return CsvFieldAnalysis(
      fileUploadId: fileUploadId,
      fields: fields,
      analyzedAt: DateTime.now(),
      totalRows: rows.length - (hasHeader ? 1 : 0),
      totalColumns: headerRow.length,
      hasHeader: hasHeader,
    );
  }

  /// Check if row looks like a header
  static bool _isHeaderRow(List<dynamic> row) {
    if (row.isEmpty) return false;
    
    // Check if contains common header keywords
    final headerKeywords = [
      'name', 'first', 'last', 'email', 'company', 'title', 
      'linkedin', 'phone', 'address', 'city', 'country'
    ];
    
    final rowText = row.join(' ').toLowerCase();
    return headerKeywords.any((keyword) => rowText.contains(keyword));
  }

  /// Generate generic column headers (Column1, Column2, etc.)
  static List<String> _generateGenericHeaders(int count) {
    return List.generate(count, (index) => 'Column${index + 1}');
  }

  /// Detect field type based on sample values
  static String _detectFieldType(List<String> samples) {
    if (samples.isEmpty) return 'text';

    // Check for email pattern
    final emailPattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (samples.any((s) => emailPattern.hasMatch(s))) {
      return 'email';
    }

    // Check for URL pattern
    final urlPattern = RegExp(r'^https?://|www\.');
    if (samples.any((s) => urlPattern.hasMatch(s))) {
      return 'url';
    }

    // Check for LinkedIn URL
    if (samples.any((s) => s.contains('linkedin.com'))) {
      return 'url';
    }

    // Check for number
    if (samples.every((s) => double.tryParse(s) != null)) {
      return 'number';
    }

    // Check for date
    final datePattern = RegExp(r'\d{1,4}[-/]\d{1,2}[-/]\d{1,4}');
    if (samples.any((s) => datePattern.hasMatch(s))) {
      return 'date';
    }

    return 'text';
  }

  /// Detect field mapping based on column name and sample values
  static ({String mappedTo, double confidence}) _detectFieldMapping(
    String columnName,
    List<String> samples,
    String detectedType,
  ) {
    final lowerName = columnName.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

    // ===== PRIORITY 0: EXPLICIT COLUMN NAMES (Highest Priority) =====
    // Check column names FIRST to avoid content misclassification
    
    // Company detection (MUST come before content analysis!)
    if (_matchesPattern(lowerName, ['company', 'organization', 'employer', 'firm', 'business', 'companyname', 'orgname'])) {
      return (mappedTo: 'company', confidence: 0.95);
    }
    
    // First Name detection
    if (_matchesPattern(lowerName, ['firstname', 'fname', 'first', 'givenname', 'forename'])) {
      return (mappedTo: 'firstName', confidence: 0.95);
    }

    // Last Name detection
    if (_matchesPattern(lowerName, ['lastname', 'lname', 'last', 'surname', 'familyname'])) {
      return (mappedTo: 'lastName', confidence: 0.95);
    }

    // ===== PRIORITY 1: CONTENT-BASED DETECTION =====
    // Only use content analysis if column name is ambiguous
    
    // Check for URLs FIRST (highest priority for content)
    if (detectedType == 'url' || (samples.isNotEmpty && samples.any((s) => s.contains('http://') || s.contains('https://')))) {
      // Check if it's LinkedIn URL
      if (samples.any((s) => s.contains('linkedin.com'))) {
        return (mappedTo: 'linkedIn', confidence: 0.95);
      }
      // Other URLs
      return (mappedTo: 'website', confidence: 0.85);
    }
    
    // Check for email addresses
    if (detectedType == 'email' || (samples.isNotEmpty && samples.any((s) => s.contains('@') && s.contains('.')))) {
      return (mappedTo: 'email', confidence: 0.95);
    }
    
    // Check if samples contain full names (First Last format)
    if (samples.isNotEmpty && _looksLikeFullNames(samples)) {
      // Samples contain full names like "Mark Vassella", "Greg Walker"
      return (mappedTo: 'fullName', confidence: 0.90);
    }
    
    // Check if samples contain job titles/positions
    if (samples.isNotEmpty && _looksLikeJobTitles(samples)) {
      // Samples contain titles like "CEO", "Manager", "Director"
      return (mappedTo: 'title', confidence: 0.88);
    }

    // ===== PRIORITY 2: OTHER COLUMN NAME PATTERNS =====

    // CEO Name / Executive Name detection (contains both first and last name)
    if (_matchesPattern(lowerName, ['ceoname', 'ceo', 'executivename', 'contactperson'])) {
      return (mappedTo: 'fullName', confidence: 0.85); // Will be split into firstName + lastName
    }

    // Full Name detection (split into first/last later)
    // Only match if it's exactly "name" or has specific patterns, not if it ends with "name"
    if (lowerName == 'name' || lowerName == 'fullname' || lowerName == 'contactname' || lowerName == 'personname') {
      return (mappedTo: 'fullName', confidence: 0.80); // Will be split into firstName + lastName
    }

    // Title detection
    if (_matchesPattern(lowerName, ['title', 'jobtitle', 'position', 'role', 'designation'])) {
      return (mappedTo: 'title', confidence: 0.9);
    }

    // Email detection
    if (_matchesPattern(lowerName, ['email', 'emailaddress', 'mail', 'e-mail']) || detectedType == 'email') {
      return (mappedTo: 'email', confidence: 0.95);
    }

    // LinkedIn detection
    if (_matchesPattern(lowerName, ['linkedin', 'linkedinurl', 'linkedinprofile', 'profile']) || 
        (detectedType == 'url' && samples.any((s) => s.contains('linkedin.com')))) {
      return (mappedTo: 'linkedIn', confidence: 0.9);
    }

    // Phone detection
    if (_matchesPattern(lowerName, ['phone', 'telephone', 'mobile', 'cell', 'contact'])) {
      return (mappedTo: 'phone', confidence: 0.85);
    }

    // Address detection
    if (_matchesPattern(lowerName, ['address', 'street', 'location', 'addr'])) {
      return (mappedTo: 'address', confidence: 0.8);
    }

    // City detection
    if (_matchesPattern(lowerName, ['city', 'town', 'municipality'])) {
      return (mappedTo: 'city', confidence: 0.85);
    }

    // Country detection
    if (_matchesPattern(lowerName, ['country', 'nation', 'nationality'])) {
      return (mappedTo: 'country', confidence: 0.85);
    }

    // Website detection
    if (_matchesPattern(lowerName, ['website', 'url', 'web', 'homepage']) || detectedType == 'url') {
      return (mappedTo: 'website', confidence: 0.8);
    }

    // Unknown field
    return (mappedTo: 'unknown', confidence: 0.0);
  }

  /// Check if column name matches any of the patterns
  static bool _matchesPattern(String columnName, List<String> patterns) {
    return patterns.any((pattern) => columnName.contains(pattern));
  }
  
  /// Check if samples look like full names (First Last format)
  static bool _looksLikeFullNames(List<String> samples) {
    if (samples.isEmpty) return false;
    
    int fullNameCount = 0;
    for (final sample in samples.take(5)) {
      final trimmed = sample.trim();
      if (trimmed.isEmpty) continue;
      
      // Check if it contains spaces (indicating multiple name parts)
      final parts = trimmed.split(RegExp(r'\s+'));
      
      // Full name criteria:
      // 1. Has 2+ parts (First Last or First Middle Last)
      // 2. Each part starts with capital letter
      // 3. No special characters like "&", numbers, or common title words
      if (parts.length >= 2) {
        final hasProperCapitalization = parts.every((part) => 
          part.isNotEmpty && part[0] == part[0].toUpperCase()
        );
        
        final lowerSample = trimmed.toLowerCase();
        final hasNoTitleWords = !lowerSample.contains('ceo') && 
                                !lowerSample.contains('manager') &&
                                !lowerSample.contains('director') &&
                                !lowerSample.contains('founder') &&
                                !lowerSample.contains('&') &&
                                !RegExp(r'\d').hasMatch(trimmed);
        
        if (hasProperCapitalization && hasNoTitleWords) {
          fullNameCount++;
        }
      }
    }
    
    // If majority of samples look like full names
    return fullNameCount >= (samples.length * 0.6).ceil();
  }
  
  /// Check if samples look like job titles
  static bool _looksLikeJobTitles(List<String> samples) {
    if (samples.isEmpty) return false;
    
    final titleKeywords = [
      'ceo', 'cto', 'cfo', 'coo', 'cmo',
      'manager', 'director', 'executive', 'officer',
      'founder', 'owner', 'president', 'vp', 'vice president',
      'head', 'lead', 'chief', 'senior', 'junior',
      'engineer', 'developer', 'designer', 'analyst',
      'coordinator', 'specialist', 'consultant', 'advisor',
      'md', 'partner', 'associate', 'assistant'
    ];
    
    int titleCount = 0;
    for (final sample in samples.take(5)) {
      final lowerSample = sample.toLowerCase().trim();
      if (lowerSample.isEmpty) continue;
      
      // Check if sample contains any title keywords
      if (titleKeywords.any((keyword) => lowerSample.contains(keyword))) {
        titleCount++;
      }
    }
    
    // If majority of samples contain title keywords
    return titleCount >= (samples.length * 0.6).ceil();
  }

  /// Get field mapping suggestions for a column
  static List<String> getSuggestedMappings(String columnName, List<String> samples) {
    final suggestions = <String>[];
    final detectedType = _detectFieldType(samples);
    final currentMapping = _detectFieldMapping(columnName, samples, detectedType);

    // Add current mapping if confident
    if (currentMapping.confidence >= 0.5) {
      suggestions.add(currentMapping.mappedTo);
    }

    // Add common alternatives
    final commonMappings = [
      'firstName', 'lastName', 'title', 'company', 
      'email', 'linkedIn', 'phone', 'address', 'city', 'country'
    ];

    for (final mapping in commonMappings) {
      if (!suggestions.contains(mapping)) {
        suggestions.add(mapping);
      }
    }

    return suggestions;
  }

  /// Format field type for display
  static String formatFieldType(String type) {
    switch (type) {
      case 'email':
        return 'Email Address';
      case 'url':
        return 'URL/Link';
      case 'number':
        return 'Number';
      case 'date':
        return 'Date';
      default:
        return 'Text';
    }
  }

  /// Format mapping for display
  static String formatMapping(String mapping) {
    switch (mapping) {
      case 'firstName':
        return 'First Name';
      case 'lastName':
        return 'Last Name';
      case 'fullName':
        return 'Full Name (→ Split)';
      case 'title':
        return 'Job Title';
      case 'company':
        return 'Company';
      case 'email':
        return 'Email';
      case 'linkedIn':
        return 'LinkedIn URL';
      case 'phone':
        return 'Phone';
      case 'address':
        return 'Address';
      case 'city':
        return 'City';
      case 'country':
        return 'Country';
      case 'website':
        return 'Website';
      case 'unknown':
        return 'Not Mapped';
      default:
        return mapping;
    }
  }
}
