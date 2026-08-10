import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/file_upload.dart';
import '../providers/contact_provider.dart';
import '../services/file_upload_service.dart';
import '../widgets/csv_field_analysis_dialog.dart';
import 'main_layout.dart';

const _ink = Color(0xFF102A43);
const _muted = Color(0xFF60758A);
const _blue = Color(0xFF2563EB);
const _mint = Color(0xFF20B486);
const _amber = Color(0xFFF59E0B);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Key _uploadsKey = UniqueKey();

  Future<void> _pickCsvFile() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (selection == null || selection.files.single.bytes == null || !mounted) {
        return;
      }

      final file = selection.files.single;
      final analysis = await context
          .read<ContactProvider>()
          .analyzeCsvFields(file.bytes!, file.name);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CsvFieldAnalysisDialog(
          analysis: analysis,
          onConfirm: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      );
      if (confirmed != true || !mounted) return;

      await context
          .read<ContactProvider>()
          .loadContactsFromCsv(file.bytes!, file.name);
      if (!mounted) return;
      setState(() => _uploadsKey = UniqueKey());
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 1)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import that CSV: $error')),
      );
    }
  }

  Future<void> _export() async {
    final provider = context.read<ContactProvider>();
    if (provider.enrichedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enrich at least one contact before exporting.')),
      );
      return;
    }
    await provider.exportToCsv();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactProvider>(
      builder: (context, provider, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 18 : 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeHeader(onImport: _pickCsvFile),
                    const SizedBox(height: 26),
                    _Metrics(provider: provider),
                    const SizedBox(height: 26),
                    if (compact) ...[
                      _ImportPanel(onImport: _pickCsvFile),
                      const SizedBox(height: 20),
                      _PipelinePanel(provider: provider, onExport: _export),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _ImportPanel(onImport: _pickCsvFile)),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: _PipelinePanel(provider: provider, onExport: _export),
                          ),
                        ],
                      ),
                    const SizedBox(height: 26),
                    _RecentUploads(key: _uploadsKey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 20,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const SizedBox(
            width: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good data starts here.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Import a list, review the field mapping, and enrich contacts with evidence behind every result.',
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New enrichment'),
          ),
        ],
      );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.provider});
  final ContactProvider provider;

  @override
  Widget build(BuildContext context) {
    final pending = provider.totalCount - provider.enrichedCount;
    final rate = provider.totalCount == 0
        ? '—'
        : '${(provider.enrichedCount / provider.totalCount * 100).round()}%';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 700
            ? constraints.maxWidth
            : (constraints.maxWidth - 48) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _Metric('Contacts', '${provider.totalCount}', Icons.people_outline, _blue, width),
            _Metric('Enriched', '${provider.enrichedCount}', Icons.verified_outlined, _mint, width),
            _Metric('Pending', '$pending', Icons.schedule_outlined, _amber, width),
            _Metric('Completion', rate, Icons.insights_outlined, const Color(0xFF7C3AED), width),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color, this.width);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE6EF)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w800)),
                Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
              ],
            ),
          ],
        ),
      );
}

class _ImportPanel extends StatelessWidget {
  const _ImportPanel({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1F33),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.upload_file_outlined, color: Color(0xFF65D6B5)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bring in your next contact list',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'CSV files are analyzed before import. You can confirm name, company, title, email, and LinkedIn mappings before anything runs.',
              style: TextStyle(color: Color(0xFFB8C8D8), height: 1.55),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _ink,
              ),
              onPressed: onImport,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Choose CSV file'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recommended: First name, last name, company, and title',
              style: TextStyle(color: Color(0xFF8FA5B8), fontSize: 12),
            ),
          ],
        ),
      );
}

class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel({required this.provider, required this.onExport});
  final ContactProvider provider;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final progress = provider.totalCount == 0
        ? 0.0
        : provider.enrichedCount / provider.totalCount;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current pipeline', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            provider.totalCount == 0
                ? 'No list loaded yet'
                : '${provider.enrichedCount} of ${provider.totalCount} contacts enriched',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE8EEF5),
              color: _mint,
            ),
          ),
          const SizedBox(height: 24),
          _Signal(
            icon: provider.apiHealthy ? Icons.check_circle_outline : Icons.error_outline,
            label: 'Validation API',
            value: provider.apiHealthy ? 'Connected' : 'Unavailable',
            color: provider.apiHealthy ? _mint : _amber,
          ),
          const SizedBox(height: 12),
          const _Signal(
            icon: Icons.shield_outlined,
            label: 'Result policy',
            value: 'Conservative',
            color: _blue,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: provider.enrichedCount > 0 ? onExport : null,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export enriched CSV'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: _muted))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      );
}

class _RecentUploads extends StatelessWidget {
  const _RecentUploads({super.key});

  @override
  Widget build(BuildContext context) {
    final uploads = FileUploadService.getAllFileUploads().take(5).toList();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent files', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          if (uploads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, color: Color(0xFF9AAEC0), size: 36),
                    SizedBox(height: 10),
                    Text('Your imported files will appear here.', style: TextStyle(color: _muted)),
                  ],
                ),
              ),
            )
          else
            ...uploads.map(_UploadRow.new),
        ],
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow(this.upload);
  final FileUpload upload;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE7EDF3))),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: _blue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(upload.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                  Text('${upload.recordCount} contacts', style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
            _StatusBadge(upload.status),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final complete = status.toLowerCase() == 'completed';
    final color = complete ? _mint : _amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
