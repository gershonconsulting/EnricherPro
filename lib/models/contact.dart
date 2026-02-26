class Contact {
  final String firstName;
  final String lastName;
  final String title;
  final String company;
  String email;
  double emailConfidence;
  String linkedInUrl;
  bool linkedInValidated;
  String enrichmentStatus;

  Contact({
    required this.firstName,
    required this.lastName,
    required this.title,
    required this.company,
    this.email = '',
    this.emailConfidence = 0.0,
    this.linkedInUrl = '',
    this.linkedInValidated = false,
    this.enrichmentStatus = 'pending',
  });

  // Create from CSV row (position-based)
  factory Contact.fromCsvRow(List<dynamic> row) {
    return Contact(
      firstName: row.isNotEmpty ? row[0].toString().trim() : '',
      lastName: row.length > 1 ? row[1].toString().trim() : '',
      title: row.length > 2 ? row[2].toString().trim() : '',
      company: row.length > 3 ? row[3].toString().trim() : '',
    );
  }

  // Create from CSV row with smart column mapping
  factory Contact.fromCsvRowWithMapping(
    List<dynamic> row, 
    Map<String, int> mapping,
  ) {
    String getField(String fieldName, String defaultValue) {
      final index = mapping[fieldName];
      if (index != null && index < row.length) {
        return row[index].toString().trim();
      }
      return defaultValue;
    }

    String firstName = getField('firstName', '');
    String lastName = getField('lastName', '');
    
    // If no firstName/lastName but we have fullName, split it
    if (firstName.isEmpty && lastName.isEmpty) {
      final fullName = getField('fullName', '');
      if (fullName.isNotEmpty) {
        final parts = _splitFullName(fullName);
        firstName = parts['firstName'] ?? '';
        lastName = parts['lastName'] ?? '';
      }
    }

    return Contact(
      firstName: firstName,
      lastName: lastName,
      title: getField('title', ''),
      company: getField('company', ''),
      email: getField('email', ''), // Get email from CSV if exists
      linkedInUrl: getField('linkedIn', ''), // Get LinkedIn URL from CSV if exists
    );
  }
  
  // Helper method to split full name into first and last name
  static Map<String, String> _splitFullName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      return {'firstName': '', 'lastName': ''};
    }
    
    // Split by whitespace
    final parts = trimmed.split(RegExp(r'\s+'));
    
    if (parts.length == 1) {
      // Only one name - treat as firstName
      return {'firstName': parts[0], 'lastName': ''};
    } else if (parts.length == 2) {
      // Two parts - firstName and lastName
      return {'firstName': parts[0], 'lastName': parts[1]};
    } else {
      // More than 2 parts - first part is firstName, rest is lastName
      return {
        'firstName': parts[0],
        'lastName': parts.sublist(1).join(' ')
      };
    }
  }

  // Create from API response
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      firstName: json['firstname'] ?? '',
      lastName: json['lastname'] ?? '',
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      email: json['email'] ?? '',
      emailConfidence: (json['email_confidence'] ?? 0.0).toDouble(),
      linkedInUrl: json['linkedin_url'] ?? '',
      linkedInValidated: json['linkedin_validated'] ?? false,
      enrichmentStatus: json['enrichment_status'] ?? 'pending',
    );
  }

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'firstname': firstName,
      'lastname': lastName,
      'title': title,
      'company': company,
      'email': email,
      'email_confidence': emailConfidence,
      'linkedin_url': linkedInUrl,
      'enrichment_status': enrichmentStatus,
    };
  }

  // Convert to CSV row for export (Google Sheets compatible)
  List<String> toCsvRow() {
    return [
      firstName,
      lastName,
      title,
      company,
      email,
      '${(emailConfidence * 100).toStringAsFixed(0)}%',  // Show as percentage
      linkedInUrl,
    ];
  }

  String get fullName => '$firstName $lastName';
  
  bool get isEnriched => enrichmentStatus == 'completed';
  
  String get confidencePercent => '${(emailConfidence * 100).toStringAsFixed(0)}%';
}
