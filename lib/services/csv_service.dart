import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import '../models/contact.dart';

class CsvService {
  /// Parse CSV data from uploaded file
  Future<List<Contact>> parseCsv(Uint8List bytes) async {
    try {
      // Decode bytes to string
      final csvString = utf8.decode(bytes);
      
      // Parse CSV
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvString,
        eol: '\n',
        shouldParseNumbers: false,
      );

      if (rows.isEmpty) {
        return [];
      }

      // Detect column mapping from header row
      Map<String, int>? columnMapping;
      int startRow = 0;
      
      if (_isHeaderRow(rows[0])) {
        columnMapping = _detectColumnMapping(rows[0]);
        startRow = 1; // Skip header row
        
        // DEBUG: Log detected mapping
        print('📋 COLUMN MAPPING DETECTED:');
        columnMapping.forEach((key, value) {
          print('   $key → column $value (${rows[0][value]})');
        });
      }

      // Convert to Contact objects
      final contacts = <Contact>[];
      int skippedRows = 0;
      
      for (int i = startRow; i < rows.length; i++) {
        final row = rows[i];
        
        // Require at least 3 columns (FirstName, LastName, Company - Title is optional)
        if (row.length < 3) {
          skippedRows++;
          continue; // Skip invalid rows
        }
        
        try {
          final contact = columnMapping != null
              ? Contact.fromCsvRowWithMapping(row, columnMapping)
              : Contact.fromCsvRow(row);
          
          // DEBUG: Log first 3 contacts to see what's being parsed
          if (contacts.length < 3) {
            print('🔍 CONTACT ${contacts.length + 1} PARSED:');
            print('   RAW ROW DATA (first 6 columns):');
            for (int j = 0; j < 6 && j < row.length; j++) {
              final cellData = row[j].toString();
              print('   [$j] "${cellData.length > 80 ? cellData.substring(0, 80) + '...' : cellData}"');
            }
            print('   MAPPED CONTACT OBJECT:');
            print('   firstName: "${contact.firstName}"');
            print('   lastName: "${contact.lastName}"');
            print('   company: "${contact.company}"');
            print('   title: "${contact.title}"');
            print('   linkedInUrl: "${contact.linkedInUrl}"');
            print('   Validation: firstName.isNotEmpty=${contact.firstName.isNotEmpty}, company.isNotEmpty=${contact.company.isNotEmpty}');
            print('');
          }
          
          // Accept contact if it has at least firstName (lastName can be empty for single names)
          if (contact.firstName.isNotEmpty && contact.company.isNotEmpty) {
            contacts.add(contact);
          } else {
            skippedRows++;
            if (skippedRows <= 3) {
              print('❌ SKIPPED ROW $i: firstName="${contact.firstName}", company="${contact.company}"');
            }
          }
        } catch (e) {
          // Skip invalid rows
          skippedRows++;
          if (skippedRows <= 3) {
            print('❌ EXCEPTION ROW $i: $e');
          }
          continue;
        }
      }
      
      print('📊 CSV PARSING COMPLETE: ${contacts.length} valid contacts, $skippedRows skipped rows');

      return contacts;
    } catch (e) {
      throw Exception('Failed to parse CSV: $e');
    }
  }

  /// Detect column mapping from header row
  Map<String, int> _detectColumnMapping(List<dynamic> headerRow) {
    final mapping = <String, int>{};
    
    for (int i = 0; i < headerRow.length; i++) {
      final header = headerRow[i].toString().toLowerCase().trim();
      final normalizedHeader = header.replaceAll(' ', '').replaceAll('_', '');
      
      // PRIORITY 1: Company (must check BEFORE other patterns!)
      // Match: "Company", "CompanyName", "Company Name", "Organization", etc.
      if ((header.contains('company') || normalizedHeader == 'company' || 
           normalizedHeader == 'organization' || normalizedHeader == 'employer' ||
           normalizedHeader == 'firm') && !header.contains('linkedin')) {
        mapping['company'] = i;
        continue; // Skip to next column
      }
      
      // PRIORITY 2: Email Address
      // Match: "email", "e-mail", "mail", "Email Address", etc.
      if (normalizedHeader == 'email' || normalizedHeader == 'mail' || 
          normalizedHeader == 'emailaddress' || header == 'e-mail') {
        mapping['email'] = i;
        continue;
      }
      
      // PRIORITY 3: Title/Function/Role
      // Match: "title", "job title", "function", "role", "position"
      if ((header.contains('title') || normalizedHeader == 'function' || 
           normalizedHeader == 'role' || normalizedHeader == 'position') && 
          !header.contains('linkedin') && !header.contains('url')) {
        mapping['title'] = i;
        continue;
      }
      
      // PRIORITY 4: Full Name (CEO Name, Contact Name, etc.)
      if (normalizedHeader == 'ceoname' || 
          normalizedHeader == 'fullname' ||
          normalizedHeader == 'contactname' ||
          normalizedHeader == 'executivename' ||
          normalizedHeader == 'personname') {
        mapping['fullName'] = i;
        continue;
      }
      
      // PRIORITY 5: FirstName variants
      if ((header.contains('first') && header.contains('name')) ||
          header == 'firstname' || header == 'first') {
        mapping['firstName'] = i;
        continue;
      }
      
      // PRIORITY 6: LastName variants
      if ((header.contains('last') && header.contains('name')) ||
          header == 'lastname' || header == 'last') {
        mapping['lastName'] = i;
        continue;
      }
      
      // PRIORITY 7: LinkedIn URL (LinkedIn, CEO LinkedIn URL, LinkedIn Profile, etc.)
      // Match ANY column containing 'linkedin' (except 'company linkedin')
      if (header.contains('linkedin') && !header.contains('company')) {
        mapping['linkedIn'] = i;
        continue;
      }
      
      // PRIORITY 8: Generic "name" (only if not already mapped)
      // This catches columns like "Name", "Name ", etc.
      if (normalizedHeader == 'name' && !mapping.containsKey('fullName') && !mapping.containsKey('firstName')) {
        mapping['fullName'] = i;
        continue;
      }
    }
    
    return mapping;
  }

  /// Check if row is a header row
  bool _isHeaderRow(List<dynamic> row) {
    if (row.isEmpty) return false;
    
    // Check if ANY cell in the row looks like a header
    for (var cell in row) {
      final cellStr = cell.toString().toLowerCase().trim();
      
      // Common header keywords
      if (cellStr.contains('first') || 
          cellStr.contains('last') ||
          cellStr.contains('name') ||
          cellStr.contains('company') ||
          cellStr.contains('email') ||
          cellStr.contains('mail') ||
          cellStr.contains('linkedin') ||
          cellStr.contains('title') ||
          cellStr.contains('function') ||
          cellStr.contains('role') ||
          cellStr.contains('booth')) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Helper method to split full name into first and last name
  static Map<String, String> splitFullName(String fullName) {
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

  /// Generate CSV string from contacts (Google Sheets compatible)
  String generateCsv(List<Contact> contacts) {
    // Create header row (Google Sheets compatible)
    final List<List<String>> rows = [
      [
        'First Name',
        'Last Name',
        'Title',
        'Company',
        'Email',
        'Confidence',
        'LinkedIn URL'
      ]
    ];

    // Add data rows
    for (final contact in contacts) {
      rows.add(contact.toCsvRow());
    }

    // Convert to CSV string with proper formatting
    // URLs will be clickable in Google Sheets
    return const ListToCsvConverter().convert(rows);
  }

  /// Generate CSV bytes for download
  Uint8List generateCsvBytes(List<Contact> contacts) {
    final csvString = generateCsv(contacts);
    return Uint8List.fromList(utf8.encode(csvString));
  }

  /// Validate CSV format
  Future<Map<String, dynamic>> validateCsvFormat(Uint8List bytes) async {
    try {
      final csvString = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(csvString);

      if (rows.isEmpty) {
        return {
          'valid': false,
          'error': 'CSV file is empty',
          'rowCount': 0,
        };
      }

      // Check if we have at least 3 columns (FirstName, LastName, Company - Title is optional)
      final hasEnoughColumns = rows.every((row) => row.length >= 3);
      if (!hasEnoughColumns) {
        return {
          'valid': false,
          'error': 'CSV must have at least 3 columns (FirstName, LastName, CompanyName). Title is optional.',
          'rowCount': rows.length,
        };
      }

      final dataRows = _isHeaderRow(rows[0]) ? rows.length - 1 : rows.length;

      return {
        'valid': true,
        'rowCount': dataRows,
        'hasHeader': _isHeaderRow(rows[0]),
      };
    } catch (e) {
      return {
        'valid': false,
        'error': 'Failed to parse CSV: $e',
        'rowCount': 0,
      };
    }
  }
}
