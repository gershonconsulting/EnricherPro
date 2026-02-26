import 'package:hive/hive.dart';

part 'csv_field_analysis.g.dart';

/// Represents analysis of a single CSV field/column
@HiveType(typeId: 2)
class CsvFieldInfo extends HiveObject {
  @HiveField(0)
  final String columnName;

  @HiveField(1)
  final String detectedType; // 'text', 'email', 'url', 'number', 'date'

  @HiveField(2)
  final String mappedTo; // 'firstName', 'lastName', 'title', 'company', 'email', 'linkedIn', 'unknown'

  @HiveField(3)
  final List<String> sampleValues;

  @HiveField(4)
  final int columnIndex;

  @HiveField(5)
  final double confidence; // 0.0 - 1.0

  CsvFieldInfo({
    required this.columnName,
    required this.detectedType,
    required this.mappedTo,
    required this.sampleValues,
    required this.columnIndex,
    required this.confidence,
  });

  /// Get icon for detected type
  String get typeIcon {
    switch (detectedType) {
      case 'email':
        return '📧';
      case 'url':
        return '🔗';
      case 'number':
        return '🔢';
      case 'date':
        return '📅';
      default:
        return '📝';
    }
  }

  /// Get color for mapping status
  String get mappingStatus {
    if (mappedTo == 'unknown') return 'warning';
    if (confidence >= 0.8) return 'success';
    if (confidence >= 0.5) return 'info';
    return 'warning';
  }

  /// Copy with different mapping
  CsvFieldInfo copyWith({
    String? mappedTo,
    double? confidence,
  }) {
    return CsvFieldInfo(
      columnName: columnName,
      detectedType: detectedType,
      mappedTo: mappedTo ?? this.mappedTo,
      sampleValues: sampleValues,
      columnIndex: columnIndex,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Complete analysis of CSV file
@HiveType(typeId: 3)
class CsvFieldAnalysis extends HiveObject {
  @HiveField(0)
  final String fileUploadId;

  @HiveField(1)
  final List<CsvFieldInfo> fields;

  @HiveField(2)
  final DateTime analyzedAt;

  @HiveField(3)
  final int totalRows;

  @HiveField(4)
  final int totalColumns;

  @HiveField(5)
  final bool hasHeader;

  CsvFieldAnalysis({
    required this.fileUploadId,
    required this.fields,
    required this.analyzedAt,
    required this.totalRows,
    required this.totalColumns,
    required this.hasHeader,
  });

  /// Check if all required fields are mapped
  bool get hasRequiredFields {
    final mappings = fields.map((f) => f.mappedTo).toSet();
    // Either we have firstName+lastName OR we have fullName (which will be split)
    final hasNames = (mappings.contains('firstName') && mappings.contains('lastName')) ||
                     mappings.contains('fullName');
    return hasNames && mappings.contains('company');
  }

  /// Get fields by mapping type
  List<CsvFieldInfo> getFieldsByMapping(String mapping) {
    return fields.where((f) => f.mappedTo == mapping).toList();
  }

  /// Get unmapped fields
  List<CsvFieldInfo> get unmappedFields {
    return fields.where((f) => f.mappedTo == 'unknown').toList();
  }

  /// Get mapping summary
  Map<String, int> get mappingSummary {
    final summary = <String, int>{};
    for (final field in fields) {
      summary[field.mappedTo] = (summary[field.mappedTo] ?? 0) + 1;
    }
    return summary;
  }

  /// Analysis quality score (0.0 - 1.0)
  double get qualityScore {
    if (fields.isEmpty) return 0.0;
    final avgConfidence = fields.map((f) => f.confidence).reduce((a, b) => a + b) / fields.length;
    final mappedRatio = fields.where((f) => f.mappedTo != 'unknown').length / fields.length;
    return (avgConfidence + mappedRatio) / 2;
  }

  /// Get analysis status message
  String get statusMessage {
    if (hasRequiredFields) {
      return '✅ All required fields detected';
    } else {
      final missing = <String>[];
      final mappings = fields.map((f) => f.mappedTo).toSet();
      // Check if we have names in any form
      if (!mappings.contains('firstName') && !mappings.contains('fullName')) {
        missing.add('First Name');
      }
      if (!mappings.contains('lastName') && !mappings.contains('fullName')) {
        missing.add('Last Name');
      }
      if (!mappings.contains('company')) missing.add('Company');
      return '⚠️ Missing fields: ${missing.join(', ')}';
    }
  }
}
