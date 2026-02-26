import 'package:flutter/material.dart';
import '../models/csv_field_analysis.dart';
import '../services/csv_field_analyzer.dart';

class CsvFieldAnalysisDialog extends StatelessWidget {
  final CsvFieldAnalysis analysis;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const CsvFieldAnalysisDialog({
    super.key,
    required this.analysis,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Summary
            _buildSummary(),
            
            // Fields List
            Expanded(
              child: _buildFieldsList(),
            ),
            
            // Actions
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CSV Field Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review detected fields before processing',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final qualityPercent = (analysis.qualityScore * 100).toStringAsFixed(0);
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Status Message
          Row(
            children: [
              Icon(
                analysis.hasRequiredFields ? Icons.check_circle : Icons.warning,
                color: analysis.hasRequiredFields ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  analysis.statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: analysis.hasRequiredFields ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.table_chart,
                  label: 'Total Rows',
                  value: '${analysis.totalRows}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.view_column,
                  label: 'Columns',
                  value: '${analysis.totalColumns}',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Mapped Fields',
                  value: '${analysis.fields.where((f) => f.mappedTo != 'unknown').length}/${analysis.totalColumns}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.score,
                  label: 'Quality',
                  value: '$qualityPercent%',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: analysis.fields.length,
      itemBuilder: (context, index) {
        final field = analysis.fields[index];
        return _FieldCard(field: field);
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: analysis.hasRequiredFields ? onConfirm : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue.shade600,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: Text(
                analysis.hasRequiredFields ? 'Continue with These Fields' : 'Missing Required Fields',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final CsvFieldInfo field;

  const _FieldCard({required this.field});

  @override
  Widget build(BuildContext context) {
    final isUnmapped = field.mappedTo == 'unknown';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnmapped ? Colors.orange.shade200 : Colors.grey.shade200,
          width: isUnmapped ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Column Name
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          field.typeIcon,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.columnName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CsvFieldAnalyzer.formatFieldType(field.detectedType),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Mapping Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getMappingColor(field.mappedTo),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMappingIcon(field.mappedTo),
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        CsvFieldAnalyzer.formatMapping(field.mappedTo),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Sample Values
            if (field.sampleValues.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Values:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...field.sampleValues.take(3).map((value) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $value',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                ),
              ),
            ],
            
            // Confidence Indicator
            if (!isUnmapped) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Confidence: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: field.confidence,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getConfidenceColor(field.confidence),
                      ),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(field.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getMappingColor(String mapping) {
    switch (mapping) {
      case 'firstName':
      case 'lastName':
      case 'company':
        return Colors.green.shade600;
      case 'title':
      case 'email':
      case 'linkedIn':
        return Colors.blue.shade600;
      case 'phone':
      case 'address':
      case 'city':
      case 'country':
        return Colors.purple.shade600;
      case 'unknown':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getMappingIcon(String mapping) {
    switch (mapping) {
      case 'firstName':
      case 'lastName':
        return Icons.person;
      case 'fullName':
        return Icons.person_outline; // Different icon for full names that will be split
      case 'company':
        return Icons.business;
      case 'title':
        return Icons.work;
      case 'email':
        return Icons.email;
      case 'linkedIn':
        return Icons.link;
      case 'phone':
        return Icons.phone;
      case 'address':
      case 'city':
      case 'country':
        return Icons.location_on;
      case 'unknown':
        return Icons.help_outline;
      default:
        return Icons.label;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade600;
    if (confidence >= 0.5) return Colors.blue.shade600;
    return Colors.orange.shade600;
  }
}
