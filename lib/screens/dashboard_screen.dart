import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/contact_provider.dart';
import '../services/file_upload_service.dart';
import '../models/file_upload.dart';
import '../widgets/csv_field_analysis_dialog.dart';
import 'main_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Key to force rebuild of recent uploads
  Key _uploadsKey = UniqueKey();
  
  Future<void> _pickCsvFile() async {
    print('🔍 _pickCsvFile called');
    try {
      print('📂 Opening file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      print('📊 File picker result: ${result != null ? "File selected" : "No file selected"}');

      if (result != null && result.files.single.bytes != null) {
        if (!mounted) return;
        
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        print('✅ File loaded: $fileName (${bytes.length} bytes)');
        
        // Analyze CSV fields first
        print('🔍 Analyzing CSV fields...');
        final analysis = await context.read<ContactProvider>().analyzeCsvFields(bytes, fileName);
        print('📋 Analysis complete: ${analysis.fields.length} fields analyzed');
        
        if (!mounted) return;
        
        // Show analysis dialog
        print('💬 Showing analysis dialog...');
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => CsvFieldAnalysisDialog(
            analysis: analysis,
            onConfirm: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
        );
        
        print('✓ Dialog result: ${confirmed == true ? "Confirmed" : "Cancelled"}');
        
        // If user confirmed, proceed with loading
        if (confirmed == true) {
          if (!mounted) return;
          print('📥 Loading contacts from CSV...');
          await context.read<ContactProvider>().loadContactsFromCsv(bytes, fileName);
          print('✅ Contacts loaded successfully');
          
          // Refresh recent uploads list
          setState(() {
            _uploadsKey = UniqueKey();
          });
          
          // Show success message
          if (!mounted) return;
          final contactCount = context.read<ContactProvider>().totalCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $contactCount contacts loaded successfully! Navigating to Contacts...'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Navigate to Contacts screen immediately
          if (!mounted) return;
          // Navigate to MainLayout with Contacts tab (index 1)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainLayout(initialIndex: 1),
            ),
          );
        }
      } else {
        print('⚠️ No file selected or no bytes available');
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in _pickCsvFile: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Consumer<ContactProvider>(
            builder: (context, provider, _) {
              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Total Contacts',
                      value: provider.totalCount.toString(),
                      icon: Icons.contacts,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Enriched',
                      value: provider.enrichedCount.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Pending',
                      value: (provider.totalCount - provider.enrichedCount)
                          .toString(),
                      icon: Icons.pending,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Success Rate',
                      value: provider.totalCount > 0
                          ? '${((provider.enrichedCount / provider.totalCount) * 100).toStringAsFixed(1)}%'
                          : '0%',
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          
          const SizedBox(height: 16),
          
          _buildQuickActions(context),
          
          const SizedBox(height: 32),
          
          // Recent Activity
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: KeyedSubtree(
                    key: _uploadsKey,
                    child: _buildRecentUploads(context),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildQuickTips(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        // PRIMARY ACTION: Upload CSV (Large, Prominent)
        _buildPrimaryUploadCard(context),
        
        const SizedBox(height: 32),
        
        // Secondary Actions (Smaller)
        Row(
          children: [
            Expanded(
              child: _buildSecondaryActionCard(
                context,
                icon: Icons.auto_fix_high,
                label: 'Enrich All',
                color: Colors.green[600]!,
                onTap: () {
                  final provider = context.read<ContactProvider>();
                  if (provider.hasContacts && !provider.isEnriching) {
                    provider.enrichAllContacts();
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSecondaryActionCard(
                context,
                icon: Icons.download,
                label: 'Export CSV',
                color: Colors.orange[600]!,
                onTap: () async {
                  final provider = context.read<ContactProvider>();
                  if (provider.enrichedCount > 0) {
                    await provider.exportToCsv();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('CSV exported successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No enriched contacts to export'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSecondaryActionCard(
                context,
                icon: Icons.settings,
                label: 'Settings',
                color: Colors.purple[600]!,
                onTap: () {
                  // Navigate to Settings tab
                  final mainLayoutState = context.findAncestorStateOfType<State>();
                  // For now, show message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Click "Settings" in the left sidebar'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryUploadCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[600]!,
            Colors.blue[800]!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[200]!.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: _pickCsvFile,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload Your CSV File',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Start enriching your contact list with verified emails',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_upload, color: Colors.blue[600], size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Choose File',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildRecentUploads(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Uploads',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Click \"History\" in the left sidebar to see all uploads'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<FileUpload>>(
                future: Future.value(FileUploadService.getAllFileUploads()),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recent uploads',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final uploads = snapshot.data!.take(5).toList();
                  return ListView.separated(
                    itemCount: uploads.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final upload = uploads[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.file_present,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          upload.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${upload.recordCount} contacts • ${_formatDate(upload.uploadDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Chip(
                          label: Text(
                            upload.status,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: _getStatusColor(upload.status),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTips(BuildContext context) {
    final tips = [
      Tip(
        icon: Icons.lightbulb,
        title: 'LinkedIn URLs',
        description: 'Provide LinkedIn URLs for faster email enrichment',
        color: Colors.amber,
      ),
      Tip(
        icon: Icons.speed,
        title: 'Batch Processing',
        description: 'Process multiple contacts at once for efficiency',
        color: Colors.blue,
      ),
      Tip(
        icon: Icons.verified,
        title: 'MX Validation',
        description: 'All emails are verified using MX record validation',
        color: Colors.green,
      ),
      Tip(
        icon: Icons.save,
        title: 'Export Results',
        description: 'Export enriched data to CSV for easy integration',
        color: Colors.purple,
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Tips',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: tips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final tip = tips[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tip.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          tip.icon,
                          color: tip.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
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
}

class Tip {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  Tip({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
