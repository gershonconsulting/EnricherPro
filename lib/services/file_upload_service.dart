import 'package:hive/hive.dart';
import '../models/file_upload.dart';

class FileUploadService {
  static const String boxName = 'file_uploads';
  
  // Initialize Hive box
  static Future<void> init() async {
    await Hive.openBox<FileUpload>(boxName);
  }

  // Get the Hive box
  static Box<FileUpload> _getBox() {
    return Hive.box<FileUpload>(boxName);
  }

  // Save a new file upload
  static Future<void> saveFileUpload(FileUpload fileUpload) async {
    final box = _getBox();
    await box.put(fileUpload.id, fileUpload);
  }

  // Get the most recent file upload
  static FileUpload? getLatestFileUpload() {
    final box = _getBox();
    if (box.isEmpty) return null;
    
    final uploads = box.values.toList();
    uploads.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    return uploads.first;
  }

  // Get all file uploads (sorted by date, newest first)
  static List<FileUpload> getAllFileUploads() {
    final box = _getBox();
    final uploads = box.values.toList();
    uploads.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    return uploads;
  }

  // Update file upload status
  static Future<void> updateFileUpload(String id, {
    String? status,
    int? enrichedCount,
    List<int>? enrichedFileBytes,
    DateTime? completionDate,
    double? successRate,
    double? avgConfidence,
    int? processingDuration,
  }) async {
    final box = _getBox();
    final fileUpload = box.get(id);
    
    if (fileUpload != null) {
      final updated = fileUpload.copyWith(
        status: status,
        enrichedCount: enrichedCount,
        enrichedFileBytes: enrichedFileBytes,
        completionDate: completionDate,
        successRate: successRate,
        avgConfidence: avgConfidence,
        processingDuration: processingDuration,
      );
      await box.put(id, updated);
    }
  }

  // Delete a file upload
  static Future<void> deleteFileUpload(String id) async {
    final box = _getBox();
    await box.delete(id);
  }

  // Clear all file uploads
  static Future<void> clearAll() async {
    final box = _getBox();
    await box.clear();
  }

  // Get file upload by ID
  static FileUpload? getFileUploadById(String id) {
    final box = _getBox();
    return box.get(id);
  }

  // Check if any uploads exist
  static bool hasUploads() {
    final box = _getBox();
    return box.isNotEmpty;
  }
}
