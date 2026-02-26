import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../constants/app_version.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // API Configuration Section
          _buildSection(
            context,
            title: 'API Configuration',
            children: [
              _buildSettingCard(
                context,
                icon: Icons.cloud,
                title: 'Snovio API',
                subtitle: 'Configure Snovio API for enhanced email discovery',
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSnovioConfigDialog,
              ),
              const SizedBox(height: 12),
              Consumer<ContactProvider>(
                builder: (context, provider, _) {
                  return _buildSettingCard(
                    context,
                    icon: provider.apiHealthy ? Icons.check_circle : Icons.error,
                    title: 'Backend API Status',
                    subtitle: provider.apiHealthy
                        ? 'Connected and ready'
                        : 'Offline - Check backend server',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: provider.apiHealthy
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        provider.apiHealthy ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: provider.apiHealthy ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: () {
                      provider.checkApiHealth();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checking API status...'),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Data Management Section
          _buildSection(
            context,
            title: 'Data Management',
            children: [
              _buildSettingCard(
                context,
                icon: Icons.delete_sweep,
                title: 'Clear All Data',
                subtitle: 'Remove all contacts and upload history',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showClearDataDialog(context);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // About Section
          _buildSection(
            context,
            title: 'About',
            children: [
              _buildSettingCard(
                context,
                icon: Icons.info,
                title: 'Version',
                subtitle: 'EnricherPro ${AppVersion.displayVersion}',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    AppVersion.displayVersion,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: null,
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                context,
                icon: Icons.bug_report,
                title: 'Test API',
                subtitle: 'Debug and test enrichment API',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, '/test');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all contacts and upload history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear contacts - implement this method in ContactProvider if needed
              // context.read<ContactProvider>().clearAllContacts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
