import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/file_api_service.dart';

class UserFilesScreen extends StatefulWidget {
  const UserFilesScreen({super.key});

  @override
  State<UserFilesScreen> createState() => _UserFilesScreenState();
}

class _UserFilesScreenState extends State<UserFilesScreen> {
  final FileApiService _api = FileApiService();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await _api.getFiles();
    if (mounted) setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _delete(int fileId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await _api.deleteFile(fileId);
    if (!mounted) return;
    if (ok) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete failed'), backgroundColor: Colors.red));
    }
  }

  Future<void> _download(String url) async {
    final uri = Uri.base.resolve(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Files'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _files.length,
                    itemBuilder: (_, i) => _fileCard(_files[i]),
                  ),
                ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No files yet',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Upload a CSV from the Contacts tab to get started',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );

  Widget _fileCard(Map<String, dynamic> f) {
    final fileId = f['id'] as int;
    final name = f['file_name'] as String? ?? 'Untitled';
    final status = f['status'] as String? ?? 'unknown';
    final records = f['record_count'] as int? ?? 0;
    final enriched = f['enriched_count'] as int? ?? 0;
    final successRate = ((f['success_rate'] as num?)?.toDouble() ?? 0.0) * 100;
    final avgConf = ((f['avg_confidence'] as num?)?.toDouble() ?? 0.0) * 100;
    final uploadDate = f['upload_date'] as String? ?? '';
    final completed = status == 'completed';
    final failed = status == 'failed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed
                      ? Icons.check_circle
                      : failed
                          ? Icons.error
                          : Icons.hourglass_empty,
                  color: completed
                      ? Colors.green
                      : failed
                          ? Colors.red
                          : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _stat('Records', '$records'),
                if (completed) _stat('Enriched', '$enriched'),
                if (completed) _stat('Success', '${successRate.toStringAsFixed(0)}%'),
                if (completed) _stat('Avg Confidence', '${avgConf.toStringAsFixed(0)}%'),
                _stat('Uploaded', _formatDate(uploadDate)),
              ],
            ),
            if (completed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Original'),
                    onPressed: () =>
                        _download(_api.originalDownloadUrl(fileId)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Enriched'),
                    onPressed: () =>
                        _download(_api.enrichedDownloadUrl(fileId)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _delete(fileId, name),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _delete(fileId, name),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final colors = {
      'completed': Colors.green,
      'processing': Colors.blue,
      'pending': Colors.orange,
      'failed': Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (colors[status] ?? Colors.grey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (colors[status] ?? Colors.grey).withOpacity(0.4)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            color: colors[status] ?? Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      );

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
