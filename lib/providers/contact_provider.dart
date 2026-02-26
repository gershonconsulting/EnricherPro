import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../models/file_upload.dart';
import '../models/csv_field_analysis.dart';
import '../services/api_service.dart';
import '../services/csv_service.dart';
import '../services/file_upload_service.dart';
import '../services/csv_field_analyzer.dart';

class ContactProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final CsvService _csvService = CsvService();

  List<Contact> _contacts = [];
  bool _isLoading = false;
  bool _isEnriching = false;
  String? _error;
  bool _apiHealthy = false;
  int _enrichmentProgress = 0;
  int _enrichmentTotal = 0;
  FileUpload? _currentFileUpload;
  CsvFieldAnalysis? _currentFieldAnalysis;
  String? _originalFileName;

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  bool get isEnriching => _isEnriching;
  String? get error => _error;
  bool get apiHealthy => _apiHealthy;
  bool get hasContacts => _contacts.isNotEmpty;
  int get enrichedCount => _contacts.where((c) => c.isEnriched).length;
  int get totalCount => _contacts.length;
  int get enrichmentProgress => _enrichmentProgress;
  int get enrichmentTotal => _enrichmentTotal;
  String get progressText => _enrichmentTotal > 0 
      ? '$_enrichmentProgress / $_enrichmentTotal contacts'
      : '';
  FileUpload? get currentFileUpload => _currentFileUpload;
  CsvFieldAnalysis? get currentFieldAnalysis => _currentFieldAnalysis;
  
  /// Load the latest file upload from database
  void loadLatestFileUpload() {
    _currentFileUpload = FileUploadService.getLatestFileUpload();
    // Restore original filename for export
    if (_currentFileUpload != null) {
      _originalFileName = _currentFileUpload!.fileName;
      if (kDebugMode) debugPrint('📝 Restored original filename: $_originalFileName');
    }
    notifyListeners();
  }
  
  /// Analyze CSV fields before loading
  Future<CsvFieldAnalysis> analyzeCsvFields(Uint8List bytes, String fileName) async {
    // Create temporary file upload ID
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Analyze the CSV file
    _currentFieldAnalysis = await CsvFieldAnalyzer.analyzeFile(
      bytes: bytes,
      fileUploadId: tempId,
    );
    
    return _currentFieldAnalysis!;
  }

  /// Check backend API health
  Future<void> checkApiHealth() async {
    _apiHealthy = await _apiService.checkHealth();
    notifyListeners();
  }

  /// Load contacts from CSV file
  Future<void> loadContactsFromCsv(Uint8List bytes, String fileName) async {
    if (kDebugMode) {
      debugPrint('🔍 [ContactProvider] loadContactsFromCsv STARTED');
      debugPrint('   📄 fileName: $fileName');
      debugPrint('   📊 bytes length: ${bytes.length}');
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate CSV format
      if (kDebugMode) debugPrint('   ✅ Step 1: Validating CSV format...');
      final validation = await _csvService.validateCsvFormat(bytes);
      
      if (!validation['valid']) {
        _error = validation['error'];
        _isLoading = false;
        if (kDebugMode) debugPrint('   ❌ CSV validation FAILED: ${_error}');
        notifyListeners();
        return;
      }
      if (kDebugMode) debugPrint('   ✅ CSV format validation PASSED');

      // Parse CSV
      if (kDebugMode) debugPrint('   ✅ Step 2: Parsing CSV...');
      _contacts = await _csvService.parseCsv(bytes);
      if (kDebugMode) {
        debugPrint('   ✅ CSV parsed: ${_contacts.length} contacts loaded');
        debugPrint('   📋 _contacts.isEmpty = ${_contacts.isEmpty}');
        debugPrint('   📋 hasContacts = $hasContacts');
        if (_contacts.isNotEmpty) {
          debugPrint('\n🔍 FIRST 3 CONTACTS DETAILED INSPECTION:');
          for (int i = 0; i < 3 && i < _contacts.length; i++) {
            final c = _contacts[i];
            debugPrint('Contact ${i + 1}:');
            debugPrint('  firstName: "${c.firstName}"');
            debugPrint('  lastName: "${c.lastName}"');
            debugPrint('  company: "${c.company}"');
            debugPrint('  title: "${c.title}"');
            debugPrint('  email: "${c.email}"');
            debugPrint('  linkedInUrl: "${c.linkedInUrl}"');
          }
          debugPrint('');
        }
      }
      
      if (_contacts.isEmpty) {
        _error = 'No valid contacts found in CSV';
        if (kDebugMode) debugPrint('   ❌ No valid contacts found');
      } else {
        // Store original filename for export
        _originalFileName = fileName;
        if (kDebugMode) debugPrint('   📝 Original filename stored: $_originalFileName');
        
        // Create file upload record in database with original file bytes
        if (kDebugMode) debugPrint('   ✅ Step 3: Saving file upload record...');
        _currentFileUpload = FileUpload.fromImport(
          fileName: fileName,
          recordCount: _contacts.length,
          originalFileBytes: bytes.toList(), // Store original CSV file
        );
        
        // Save to database
        await FileUploadService.saveFileUpload(_currentFileUpload!);
        if (kDebugMode) debugPrint('   ✅ File upload record saved with original file (${bytes.length} bytes)');
      }
    } catch (e, stackTrace) {
      _error = 'Failed to load CSV: $e';
      _contacts = [];
      if (kDebugMode) {
        debugPrint('   ❌ EXCEPTION in loadContactsFromCsv: $e');
        debugPrint('   📚 Stack trace: $stackTrace');
      }
    }

    _isLoading = false;
    notifyListeners();
    
    if (kDebugMode) {
      debugPrint('🏁 [ContactProvider] loadContactsFromCsv COMPLETED');
      debugPrint('   📊 Final state: ${_contacts.length} contacts, hasContacts=$hasContacts, error=$_error');
    }
  }

  /// Enrich all contacts
  Future<void> enrichAllContacts() async {
    if (_contacts.isEmpty) return;

    _isEnriching = true;
    _error = null;
    _enrichmentProgress = 0;
    _enrichmentTotal = _contacts.length;
    
    // Record start time for duration calculation
    final startTime = DateTime.now();
    
    // Update file upload status to processing
    if (_currentFileUpload != null) {
      await FileUploadService.updateFileUpload(
        _currentFileUpload!.id,
        status: 'processing',
      );
      _currentFileUpload = FileUploadService.getFileUploadById(_currentFileUpload!.id);
    }
    
    notifyListeners();

    try {
      // Enrich in batches of 50 contacts to avoid timeouts and memory issues
      const int batchSize = 50;
      final List<Contact> enrichedContacts = [];
      
      for (int i = 0; i < _contacts.length; i += batchSize) {
        // Get batch
        final end = (i + batchSize < _contacts.length) ? i + batchSize : _contacts.length;
        final batch = _contacts.sublist(i, end);
        
        // Enrich batch
        if (kDebugMode) {
          debugPrint('🔄 Enriching batch ${i ~/ batchSize + 1} (${batch.length} contacts)');
        }
        
        final enrichedBatch = await _apiService.enrichContactsBatch(batch);
        enrichedContacts.addAll(enrichedBatch);
        
        // Update progress
        _enrichmentProgress = enrichedContacts.length;
        notifyListeners();
        
        // Small delay between batches to avoid overwhelming the API
        if (end < _contacts.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      _contacts = enrichedContacts;
      _enrichmentProgress = _enrichmentTotal;
      
      // Calculate statistics
      final endTime = DateTime.now();
      final processingDuration = endTime.difference(startTime).inSeconds;
      
      final successCount = _contacts.where((c) => c.isEnriched).length;
      final successRate = (successCount / _contacts.length) * 100;
      
      final contactsWithConfidence = _contacts.where((c) => c.emailConfidence > 0).toList();
      final avgConfidence = contactsWithConfidence.isNotEmpty
          ? contactsWithConfidence.map((c) => c.emailConfidence).reduce((a, b) => a + b) / contactsWithConfidence.length
          : 0.0;
      
      // Generate enriched CSV bytes
      final enrichedCsvBytes = exportToCsvBytes();
      
      if (kDebugMode) {
        debugPrint('📊 Enrichment Statistics:');
        debugPrint('   ✅ Success count: $successCount / ${_contacts.length}');
        debugPrint('   📈 Success rate: ${successRate.toStringAsFixed(1)}%');
        debugPrint('   🎯 Average confidence: ${(avgConfidence * 100).toStringAsFixed(0)}%');
        debugPrint('   ⏱️ Processing duration: ${processingDuration}s');
        debugPrint('   📦 Enriched CSV size: ${enrichedCsvBytes.length} bytes');
      }
      
      // Update file upload status to completed with statistics
      if (_currentFileUpload != null) {
        await FileUploadService.updateFileUpload(
          _currentFileUpload!.id,
          status: 'completed',
          enrichedCount: successCount,
          enrichedFileBytes: enrichedCsvBytes.toList(),
          completionDate: endTime,
          successRate: successRate,
          avgConfidence: avgConfidence,
          processingDuration: processingDuration,
        );
        _currentFileUpload = FileUploadService.getFileUploadById(_currentFileUpload!.id);
        if (kDebugMode) debugPrint('   ✅ File upload record updated with statistics');
      }
    } catch (e) {
      _error = 'Failed to enrich contacts: $e';
      
      // Update file upload status to failed
      if (_currentFileUpload != null) {
        await FileUploadService.updateFileUpload(
          _currentFileUpload!.id,
          status: 'failed',
        );
        _currentFileUpload = FileUploadService.getFileUploadById(_currentFileUpload!.id);
      }
    }

    _isEnriching = false;
    _enrichmentProgress = 0;
    _enrichmentTotal = 0;
    notifyListeners();
  }

  /// Enrich a single contact
  Future<void> enrichSingleContact(int index) async {
    if (index < 0 || index >= _contacts.length) return;

    final contact = _contacts[index];
    
    try {
      final enriched = await _apiService.enrichContact(contact);
      _contacts[index] = enriched;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to enrich contact: $e');
      }
    }
  }

  /// Get enriched filename with date suffix
  String get enrichedFileName {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    
    if (_originalFileName != null && _originalFileName!.isNotEmpty) {
      // Remove .csv extension if present
      final nameWithoutExt = _originalFileName!.endsWith('.csv') 
          ? _originalFileName!.substring(0, _originalFileName!.length - 4)
          : _originalFileName;
      return '${nameWithoutExt}_enriched_$dateStr.csv';
    }
    
    // Fallback to generic name
    return 'enriched_contacts_$dateStr.csv';
  }

  /// Export enriched contacts to CSV
  String exportToCsv() {
    return _csvService.generateCsv(_contacts);
  }

  /// Export enriched contacts as bytes
  Uint8List exportToCsvBytes() {
    return _csvService.generateCsvBytes(_contacts);
  }

  /// Clear all contacts
  void clearContacts() {
    _contacts = [];
    _error = null;
    notifyListeners();
  }

  /// Add sample contacts for testing
  void addSampleContacts() {
    _contacts = [
      Contact(
        firstName: 'John',
        lastName: 'Doe',
        title: 'Software Engineer',
        company: 'Google',
      ),
      Contact(
        firstName: 'Jane',
        lastName: 'Smith',
        title: 'Product Manager',
        company: 'Microsoft',
      ),
      Contact(
        firstName: 'Robert',
        lastName: 'Johnson',
        title: 'CEO',
        company: 'Amazon',
      ),
    ];
    notifyListeners();
  }

  /// Configure Snovio API key
  Future<bool> configureSnovioApiKey(String apiKey) async {
    try {
      final result = await _apiService.configureSnovio(apiKey);
      if (result['status'] == 'success') {
        return true;
      }
      _error = result['message'];
      return false;
    } catch (e) {
      _error = 'Failed to configure Snovio: $e';
      return false;
    }
  }
}
