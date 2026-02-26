import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/contact_provider.dart';
import '../utils/file_downloader.dart';
import '../widgets/file_upload_banner.dart';
import '../widgets/csv_field_analysis_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Check API health on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().checkApiHealth();
    });
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        if (!mounted) return;
        
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        
        // Analyze CSV fields first
        final analysis = await context.read<ContactProvider>().analyzeCsvFields(bytes, fileName);
        
        if (!mounted) return;
        
        // Show analysis dialog
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => CsvFieldAnalysisDialog(
            analysis: analysis,
            onConfirm: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
        );
        
        // If user confirmed, proceed with loading
        if (confirmed == true) {
          if (!mounted) return;
          await context.read<ContactProvider>().loadContactsFromCsv(bytes, fileName);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPasteCsvDialog() {
    final TextEditingController csvController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Paste CSV Data'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your CSV data below (FirstName, LastName, Title, CompanyName):',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: csvController,
                  decoration: const InputDecoration(
                    hintText: 'FirstName,LastName,Title,CompanyName\nJohn,Doe,Engineer,Google\nJane,Smith,Manager,Microsoft',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 10,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Format: One contact per line, comma-separated values',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final csvText = csvController.text.trim();
                if (csvText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please paste CSV data'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                
                try {
                  // Convert text to bytes
                  final bytes = Uint8List.fromList(csvText.codeUnits);
                  await context.read<ContactProvider>().loadContactsFromCsv(
                    bytes,
                    'pasted-data.csv', // Default filename for pasted data
                  );
                  
                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CSV data loaded successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to load CSV: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Load CSV'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enrichContacts() async {
    final provider = context.read<ContactProvider>();
    
    if (!provider.apiHealthy) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend API is not available. Please ensure the Python server is running.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    await provider.enrichAllContacts();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enriched ${provider.enrichedCount} contacts successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportCsv() {
    final provider = context.read<ContactProvider>();
    final csvBytes = provider.exportToCsvBytes();
    
    try {
      FileDownloader.instance.downloadFile(csvBytes, 'enriched_contacts.csv');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _addSampleData() {
    context.read<ContactProvider>().addSampleContacts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sample contacts added'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showSnovioConfigDialog() {
    final TextEditingController apiKeyController = TextEditingController();
    final TextEditingController userIdController = TextEditingController();
    final TextEditingController secretController = TextEditingController();
    bool useOAuth = false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Configure Snovio API'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enable fallback email enrichment when confidence is below 50%.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    
                    // Authentication method selector
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('API Key', style: TextStyle(fontSize: 14)),
                            value: false,
                            groupValue: useOAuth,
                            onChanged: (value) {
                              setState(() => useOAuth = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('OAuth', style: TextStyle(fontSize: 14)),
                            value: true,
                            groupValue: useOAuth,
                            onChanged: (value) {
                              setState(() => useOAuth = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // API Key method
                    if (!useOAuth) ...[
                      TextField(
                        controller: apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Enter Snovio API key',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Find at: Settings → API → Generate API Key',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                    
                    // OAuth method
                    if (useOAuth) ...[
                      TextField(
                        controller: userIdController,
                        decoration: const InputDecoration(
                          labelText: 'User ID (Client ID)',
                          hintText: 'Enter User ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: secretController,
                        decoration: const InputDecoration(
                          labelText: 'API Secret (Client Secret)',
                          hintText: 'Enter API Secret',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Find at: Settings → API → OAuth Credentials',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    const Text(
                      'Get credentials from: https://snov.io/api',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String credentials;
                    
                    if (useOAuth) {
                      final userId = userIdController.text.trim();
                      final secret = secretController.text.trim();
                      
                      if (userId.isEmpty || secret.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter both User ID and API Secret'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      
                      credentials = 'oauth:$userId:$secret';
                    } else {
                      final apiKey = apiKeyController.text.trim();
                      
                      if (apiKey.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter an API key'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      
                      credentials = apiKey;
                    }
                    
                    Navigator.of(context).pop();
                    
                    final success = await context.read<ContactProvider>().configureSnovioApiKey(credentials);
                    
                    if (!mounted) return;
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success 
                              ? '✅ Snovio API configured successfully!' 
                              : '❌ Failed to configure Snovio API'
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  },
                  child: const Text('Configure'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact Enricher',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Test API',
            onPressed: () {
              Navigator.pushNamed(context, '/test');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure Snovio API',
            onPressed: _showSnovioConfigDialog,
          ),
          Consumer<ContactProvider>(
            builder: (context, provider, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Icon(
                      provider.apiHealthy 
                          ? Icons.check_circle 
                          : Icons.error,
                      color: provider.apiHealthy 
                          ? Colors.green 
                          : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.apiHealthy ? 'API Ready' : 'API Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.apiHealthy 
                            ? Colors.green 
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<ContactProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading contacts...'),
                  ],
                ),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _pickCsvFile,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            if (!provider.hasContacts) {
              return _buildEmptyState();
            }

            return Column(
              children: [
                // File Upload Banner
                if (provider.currentFileUpload != null)
                  FileUploadBanner(
                    fileUpload: provider.currentFileUpload!,
                    onClose: () {
                      // Optional: dismiss banner (could clear from provider)
                    },
                  ),
                _buildActionBar(provider),
                Expanded(
                  child: _buildContactsTable(provider),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Consumer<ContactProvider>(
        builder: (context, provider, _) {
          if (!provider.hasContacts) return const SizedBox.shrink();
          
          return FloatingActionButton.extended(
            onPressed: provider.isEnriching ? null : _enrichContacts,
            icon: provider.isEnriching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(
              provider.isEnriching ? 'Enriching...' : 'Enrich Contacts',
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_file,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Upload CSV to Get Started',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload a CSV file with FirstName, LastName, Title, and CompanyName columns',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickCsvFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Upload CSV File'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showPasteCsvDialog,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste CSV Data'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _addSampleData,
              icon: const Icon(Icons.science),
              label: const Text('Load Sample Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(ContactProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${provider.totalCount} contacts',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 16),
          if (provider.enrichedCount > 0)
            Chip(
              label: Text('${provider.enrichedCount} enriched'),
              backgroundColor: Colors.green[100],
              labelStyle: TextStyle(color: Colors.green[900]),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: _pickCsvFile,
            icon: const Icon(Icons.refresh),
            label: const Text('Load New CSV'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: provider.enrichedCount > 0 ? _exportCsv : null,
            icon: const Icon(Icons.download),
            label: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsTable(ContactProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('First Name')),
            DataColumn(label: Text('Last Name')),
            DataColumn(label: Text('Title')),
            DataColumn(label: Text('Company')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Confidence')),
            DataColumn(label: Text('LinkedIn')),
            DataColumn(label: Text('Status')),
          ],
          rows: provider.contacts.asMap().entries.map((entry) {
            final contact = entry.value;
            
            return DataRow(
              cells: [
                DataCell(Text(contact.firstName)),
                DataCell(Text(contact.lastName)),
                DataCell(Text(contact.title)),
                DataCell(Text(contact.company)),
                DataCell(
                  contact.email.isNotEmpty
                      ? SelectableText(contact.email)
                      : const Text('-'),
                ),
                DataCell(
                  contact.emailConfidence > 0
                      ? Chip(
                          label: Text(contact.confidencePercent),
                          backgroundColor: _getConfidenceColor(
                            contact.emailConfidence,
                          ),
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        )
                      : const Text('-'),
                ),
                DataCell(
                  contact.linkedInUrl.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _launchUrl(contact.linkedInUrl),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Row(
                              children: [
                                Icon(
                                  contact.linkedInValidated ? Icons.check_circle : Icons.search,
                                  color: contact.linkedInValidated ? Colors.green : Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    contact.linkedInUrl,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Text('-'),
                ),
                DataCell(
                  _buildStatusChip(contact.enrichmentStatus),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    if (status == 'completed') {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (status.startsWith('error')) {
      color = Colors.red;
      icon = Icons.error;
    } else {
      color = Colors.orange;
      icon = Icons.pending;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(status),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
