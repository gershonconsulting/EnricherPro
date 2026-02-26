import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_upload_service.dart';
import '../models/file_upload.dart';
import '../providers/contact_provider.dart';
import '../utils/file_downloader.dart';
import 'main_layout.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search uploads...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'processing', child: Text('Processing')),
                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterStatus = value!;
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Upload History List
          Expanded(
            child: FutureBuilder<List<FileUpload>>(
              future: Future.value(FileUploadService.getAllFileUploads()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                var uploads = snapshot.data!;

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  uploads = uploads
                      .where((upload) =>
                          upload.fileName.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                // Apply status filter
                if (_filterStatus != 'all') {
                  uploads = uploads
                      .where((upload) =>
                          upload.status.toLowerCase() == _filterStatus)
                      .toList();
                }

                if (uploads.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: uploads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildUploadCard(context, uploads[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/enricherpro_logo_large.png',
              width: 400,
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Upload History',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your uploaded files will appear here',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to contacts screen
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Your First CSV'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context, FileUpload upload) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          _showUploadDetails(context, upload);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.file_present,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          upload.fileName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(upload.uploadDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      upload.status,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: _getStatusColor(upload.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.contacts,
                    '${upload.recordCount} contacts',
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.check_circle,
                    '${upload.enrichedCount} enriched',
                    Colors.green,
                  ),
                  if (upload.successRate != null)
                    _buildInfoChip(
                      Icons.percent,
                      upload.formattedSuccessRate,
                      Colors.orange,
                    ),
                  if (upload.hasOriginalFile)
                    _buildInfoChip(
                      Icons.file_present,
                      'Original',
                      Colors.blue[700]!,
                    ),
                  if (upload.hasEnrichedFile)
                    _buildInfoChip(
                      Icons.file_download_done,
                      'Enriched',
                      Colors.green[700]!,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.withValues(alpha: 0.2);
      case 'processing':
        return Colors.blue.withValues(alpha: 0.2);
      case 'failed':
        return Colors.red.withValues(alpha: 0.2);
      default:
        return Colors.grey.withValues(alpha: 0.2);
    }
  }

  void _showUploadDetails(BuildContext context, FileUpload upload) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.file_present, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                upload.fileName,
                style: const TextStyle(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info
                _buildDetailRow('Status', '${upload.statusEmoji} ${upload.status}'),
                _buildDetailRow('Total Contacts', upload.recordCount.toString()),
                _buildDetailRow('Enriched', upload.enrichedCount.toString()),
                _buildDetailRow('Uploaded', _formatDate(upload.uploadDate)),
                
                // Statistics (if completed)
                if (upload.status == 'completed') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '📊 Enrichment Statistics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Success Rate', upload.formattedSuccessRate),
                  _buildDetailRow('Avg. Confidence', upload.formattedAvgConfidence),
                  _buildDetailRow('Processing Time', upload.formattedDuration),
                  if (upload.completionDate != null)
                    _buildDetailRow('Completed', upload.formattedCompletionDate),
                ],
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Download Files Section
                const Text(
                  '📥 Download Files',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Original File Download
                if (upload.hasOriginalFile)
                  ListTile(
                    leading: const Icon(Icons.file_download, color: Colors.blue),
                    title: const Text('Original CSV'),
                    subtitle: Text('Uploaded: ${upload.formattedDate}'),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        _downloadOriginalFile(context, upload);
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                
                // Enriched File Download
                if (upload.hasEnrichedFile)
                  ListTile(
                    leading: const Icon(Icons.file_download_done, color: Colors.green),
                    title: const Text('Enriched CSV'),
                    subtitle: Text('${upload.enrichedCount} enriched contacts'),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        _downloadEnrichedFile(context, upload);
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                
                if (!upload.hasOriginalFile && !upload.hasEnrichedFile)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No files available for download',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _loadUploadContacts(BuildContext context, FileUpload upload) {
    // Check if this is the current upload
    final provider = context.read<ContactProvider>();
    final currentUpload = provider.currentFileUpload;
    
    if (currentUpload != null && currentUpload.id == upload.id) {
      // Already loaded, just navigate
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainLayout(initialIndex: 1),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viewing ${provider.totalCount} contacts from "${upload.fileName}"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Different upload - need to reload
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Cannot load previous uploads yet. Please re-upload "${upload.fileName}" to view its contacts.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Upload',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const MainLayout(initialIndex: 1),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _exportUploadContacts(BuildContext context, FileUpload upload) {
    final provider = context.read<ContactProvider>();
    final currentUpload = provider.currentFileUpload;
    
    // Check if this is the current loaded upload
    if (currentUpload != null && currentUpload.id == upload.id && provider.hasContacts) {
      // Export current contacts
      try {
        final csvBytes = provider.exportToCsvBytes();
        FileDownloader.instance.downloadFile(
          csvBytes,
          'enriched_${upload.fileName}',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported ${provider.enrichedCount} enriched contacts!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Not currently loaded
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Cannot export previous uploads yet. Please re-upload "${upload.fileName}" and enrich it again.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Upload',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).pushNamed('/contacts');
            },
          ),
        ),
      );
    }
  }

  void _downloadOriginalFile(BuildContext context, FileUpload upload) {
    if (!upload.hasOriginalFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Original file not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final bytes = Uint8List.fromList(upload.originalFileBytes!);
      FileDownloader.instance.downloadFile(bytes, upload.fileName);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Downloaded original file: ${upload.fileName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _downloadEnrichedFile(BuildContext context, FileUpload upload) {
    if (!upload.hasEnrichedFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Enriched file not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final bytes = Uint8List.fromList(upload.enrichedFileBytes!);
      
      // Generate enriched filename with date
      final completionDate = upload.completionDate ?? upload.uploadDate;
      final dateStr = '${completionDate.year}${completionDate.month.toString().padLeft(2, '0')}${completionDate.day.toString().padLeft(2, '0')}';
      final nameWithoutExt = upload.fileName.endsWith('.csv') 
          ? upload.fileName.substring(0, upload.fileName.length - 4)
          : upload.fileName;
      final enrichedFileName = '${nameWithoutExt}_enriched_$dateStr.csv';
      
      FileDownloader.instance.downloadFile(bytes, enrichedFileName);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Downloaded enriched file: $enrichedFileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, FileUpload upload) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Re-enrich'),
              onTap: () {
                Navigator.pop(context);
                // Implement re-enrich functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                await FileUploadService.deleteFileUpload(upload.id);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
