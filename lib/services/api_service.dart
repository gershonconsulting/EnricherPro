import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';

class ApiService {
  // Backend API URL - uses same-origin proxy to avoid CORS issues
  static const String baseUrl = '/api';
  
  // Timeout duration (longer for email validation which includes MX/SMTP checks)
  // Increased to 10 minutes for large batches with Snovio API integration
  static const Duration timeout = Duration(seconds: 600);

  /// Enrich a single contact
  Future<Contact> enrichContact(Contact contact) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/enrich'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(contact.toJson()),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Contact.fromJson(data);
      } else {
        throw Exception('Failed to enrich contact: ${response.statusCode}');
      }
    } catch (e) {
      // Return contact with error status
      return Contact(
        firstName: contact.firstName,
        lastName: contact.lastName,
        title: contact.title,
        company: contact.company,
        enrichmentStatus: 'error: $e',
      );
    }
  }

  /// Enrich multiple contacts in batch
  Future<List<Contact>> enrichContactsBatch(List<Contact> contacts) async {
    try {
      final contactsJson = contacts.map((c) => c.toJson()).toList();
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/enrich/batch'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'contacts': contactsJson}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        // DEBUG: Print response (works in release mode too!)
        print('✅ API Response: ${response.body.length} bytes');
        
        final data = jsonDecode(response.body);
        print('📊 Results count: ${(data['results'] as List?)?.length ?? 0}');
        
        // DEBUG: Print response structure
        if (kDebugMode) {
          print('   Response keys: ${data.keys.toList()}');
          print('   Status: ${data['status']}');
          print('   Total: ${data['total']}');
          print('   Results count: ${(data['results'] as List?)?.length ?? 0}');
          
          if (data['results'] != null && (data['results'] as List).isNotEmpty) {
            print('\n🔍 DEBUG: First enrichment result from backend:');
            final firstResult = (data['results'] as List).first;
            print('   Keys: ${firstResult.keys.toList()}');
            print('   Email: "${firstResult['email']}" (has email: ${firstResult.containsKey('email')})');
            print('   Confidence: ${firstResult['email_confidence']} (has confidence: ${firstResult.containsKey('email_confidence')})');
            print('\n   Full JSON:');
            print('   ${jsonEncode(firstResult)}');
          }
        }
        
        final results = (data['results'] as List)
            .map((json) {
              // DEBUG: Print each contact as it's parsed
              if ((data['results'] as List).indexOf(json) == 0) {
                print('🔍 First result JSON: ${jsonEncode(json)}');
              }
              return Contact.fromJson(json);
            })
            .toList();
        
        // DEBUG: Print first Contact object (works in release mode!)
        if (results.isNotEmpty) {
          final contact = results.first;
          print('👤 First Contact: ${contact.firstName} ${contact.lastName}');
          print('📧 Email: "${contact.email}" | Confidence: ${contact.emailConfidence}');
          print('🔗 LinkedIn: ${contact.linkedInUrl}');
        }
        
        return results;
      } else {
        throw Exception('Failed to enrich contacts: ${response.statusCode}');
      }
    } catch (e) {
      // DEBUG: Print error (works in release mode!)
      print('❌ ERROR in enrichContactsBatch: $e');
      print('Error type: ${e.runtimeType}');
      
      // Return contacts with error status
      return contacts.map((c) {
        c.enrichmentStatus = 'error: $e';
        return c;
      }).toList();
    }
  }

  /// Validate a single email
  Future<Map<String, dynamic>> validateEmail(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/validate/email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to validate email');
      }
    } catch (e) {
      return {
        'email': email,
        'is_valid': false,
        'confidence_score': 0.0,
        'details': 'Validation error: $e'
      };
    }
  }

  /// Generate email patterns
  Future<List<String>> generateEmailPatterns({
    required String firstName,
    required String lastName,
    required String company,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/patterns/email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstname': firstName,
              'lastname': lastName,
              'company': company,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['patterns']);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Generate LinkedIn URLs
  Future<Map<String, dynamic>> generateLinkedInUrls({
    required String firstName,
    required String lastName,
    required String company,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/patterns/linkedin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstname': firstName,
              'lastname': lastName,
              'company': company,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'linkedin_urls': [], 'linkedin_search': ''};
      }
    } catch (e) {
      return {'linkedin_urls': [], 'linkedin_search': ''};
    }
  }

  /// Check API health
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('/health'))
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Health check error: $e');
      }
      return false;
    }
  }

  /// Configure Snovio API key
  Future<Map<String, dynamic>> configureSnovio(String apiKey) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/config/snovio'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'api_key': apiKey}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to configure Snovio: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Configuration failed: $e'
      };
    }
  }
}
