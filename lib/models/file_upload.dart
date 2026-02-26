import 'package:hive/hive.dart';

part 'file_upload.g.dart';

@HiveType(typeId: 1)
class FileUpload extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fileName;

  @HiveField(2)
  final int recordCount;

  @HiveField(3)
  final DateTime uploadDate;

  @HiveField(4)
  final String status; // 'pending', 'processing', 'completed', 'failed'

  @HiveField(5)
  final int enrichedCount;

  @HiveField(6)
  final String? filePath;

  // NEW: Store original CSV file bytes
  @HiveField(7)
  final List<int>? originalFileBytes;

  // NEW: Store enriched CSV file bytes
  @HiveField(8)
  final List<int>? enrichedFileBytes;

  // NEW: Enrichment completion date
  @HiveField(9)
  final DateTime? completionDate;

  // NEW: Success rate (percentage of successfully enriched contacts)
  @HiveField(10)
  final double? successRate;

  // NEW: Average confidence score
  @HiveField(11)
  final double? avgConfidence;

  // NEW: Processing duration in seconds
  @HiveField(12)
  final int? processingDuration;

  FileUpload({
    required this.id,
    required this.fileName,
    required this.recordCount,
    required this.uploadDate,
    this.status = 'pending',
    this.enrichedCount = 0,
    this.filePath,
    this.originalFileBytes,
    this.enrichedFileBytes,
    this.completionDate,
    this.successRate,
    this.avgConfidence,
    this.processingDuration,
  });

  // Create from CSV import
  factory FileUpload.fromImport({
    required String fileName,
    required int recordCount,
    String? filePath,
    List<int>? originalFileBytes,
  }) {
    return FileUpload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      recordCount: recordCount,
      uploadDate: DateTime.now(),
      status: 'pending',
      enrichedCount: 0,
      filePath: filePath,
      originalFileBytes: originalFileBytes,
    );
  }

  // Copy with updated values
  FileUpload copyWith({
    String? status,
    int? enrichedCount,
    List<int>? enrichedFileBytes,
    DateTime? completionDate,
    double? successRate,
    double? avgConfidence,
    int? processingDuration,
  }) {
    return FileUpload(
      id: id,
      fileName: fileName,
      recordCount: recordCount,
      uploadDate: uploadDate,
      status: status ?? this.status,
      enrichedCount: enrichedCount ?? this.enrichedCount,
      filePath: filePath,
      originalFileBytes: originalFileBytes,
      enrichedFileBytes: enrichedFileBytes ?? this.enrichedFileBytes,
      completionDate: completionDate ?? this.completionDate,
      successRate: successRate ?? this.successRate,
      avgConfidence: avgConfidence ?? this.avgConfidence,
      processingDuration: processingDuration ?? this.processingDuration,
    );
  }

  // Format upload date for display
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(uploadDate);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${uploadDate.day}/${uploadDate.month}/${uploadDate.year}';
    }
  }

  // Get progress percentage
  double get progressPercent {
    if (recordCount == 0) return 0.0;
    return (enrichedCount / recordCount * 100).clamp(0.0, 100.0);
  }

  // Status emoji
  String get statusEmoji {
    switch (status) {
      case 'completed':
        return '✅';
      case 'processing':
        return '⏳';
      case 'failed':
        return '❌';
      default:
        return '📄';
    }
  }

  // Format success rate for display
  String get formattedSuccessRate {
    if (successRate == null) return 'N/A';
    return '${successRate!.toStringAsFixed(1)}%';
  }

  // Format average confidence for display
  String get formattedAvgConfidence {
    if (avgConfidence == null) return 'N/A';
    return '${(avgConfidence! * 100).toStringAsFixed(0)}%';
  }

  // Format processing duration for display
  String get formattedDuration {
    if (processingDuration == null) return 'N/A';
    final duration = Duration(seconds: processingDuration!);
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }

  // Check if original file is available for download
  bool get hasOriginalFile => originalFileBytes != null && originalFileBytes!.isNotEmpty;

  // Check if enriched file is available for download
  bool get hasEnrichedFile => enrichedFileBytes != null && enrichedFileBytes!.isNotEmpty;

  // Format completion date for display
  String get formattedCompletionDate {
    if (completionDate == null) return 'N/A';
    return '${completionDate!.day}/${completionDate!.month}/${completionDate!.year} ${completionDate!.hour}:${completionDate!.minute.toString().padLeft(2, '0')}';
  }
}
