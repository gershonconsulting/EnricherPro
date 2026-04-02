import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_version.dart';
import 'dashboard_screen.dart';
import 'contacts_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'user_files_screen.dart';

class MainLayout extends StatefulWidget {
  final int? initialIndex;
  
  const MainLayout({super.key, this.initialIndex});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isDrawerExpanded = true;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/dashboard',
    ),
    NavigationItem(
      icon: Icons.contacts,
      label: 'Contacts',
      route: '/contacts',
    ),
    NavigationItem(
      icon: Icons.history,
      label: 'History',
      route: '/history',
    ),
    NavigationItem(
      icon: Icons.folder_open,
      label: 'My Files',
      route: '/my-files',
    ),
    NavigationItem(
      icon: Icons.settings,
      label: 'Settings',
      route: '/settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Set initial index if provided
    if (widget.initialIndex != null) {
      _selectedIndex = widget.initialIndex!;
    }
    // Check API health on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().checkApiHealth();
    });
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ContactsScreen();
      case 2:
        return const HistoryScreen();
      case 3:
        return const UserFilesScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar Navigation
          _buildSidebar(),
          
          // Main Content Area
          Expanded(
            child: Stack(
              children: [
                // Main content
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: _getScreen(_selectedIndex),
                    ),
                  ],
                ),
                
                // Version number (bottom-right)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'v${AppVersion.version}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final theme = Theme.of(context);
    final width = _isDrawerExpanded ? 240.0 : 72.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // App Logo/Title
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (_isDrawerExpanded)
                  Expanded(
                    child: Image.asset(
                      'assets/images/enricherpro_logo_large.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/enricherpro_logo_large.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                return _buildNavigationItem(
                  _navigationItems[index],
                  index,
                );
              },
            ),
          ),
          
          // API Status Indicator
          Consumer<ContactProvider>(
            builder: (context, provider, _) {
              return Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: provider.apiHealthy
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: provider.apiHealthy
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.apiHealthy
                          ? Icons.check_circle
                          : Icons.error,
                      color: Colors.white,
                      size: 16,
                    ),
                    if (_isDrawerExpanded) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.apiHealthy ? 'API Ready' : 'API Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          
          // Collapse/Expand Button
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          InkWell(
            onTap: () {
              setState(() {
                _isDrawerExpanded = !_isDrawerExpanded;
              });
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDrawerExpanded
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: Colors.white,
                  ),
                  if (_isDrawerExpanded) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Collapse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(NavigationItem item, int index) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: Colors.white,
                  size: 24,
                ),
                if (_isDrawerExpanded) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _navigationItems[_selectedIndex].label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          
          // Test API Button
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Test API',
            onPressed: () {
              Navigator.pushNamed(context, '/test');
            },
          ),
          
          // Notifications
          IconButton(
            icon: Badge(
              label: const Text('3'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              // Show notifications
            },
          ),
          
          const SizedBox(width: 8),
          
          // User Profile + logout
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.user;
              return PopupMenuButton(
                tooltip: 'Account',
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    user != null
                        ? user.firstName.isNotEmpty
                            ? user.firstName[0].toUpperCase()
                            : 'U'
                        : 'U',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                itemBuilder: (_) => [
                  if (user != null)
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(user.email,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          Text('Plan: ${user.plan}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'logout',
                      child: Row(children: [
                        Icon(Icons.logout, size: 18),
                        SizedBox(width: 8),
                        Text('Sign out'),
                      ])),
                ],
                onSelected: (value) async {
                  if (value == 'logout') {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context)
                          .pushReplacementNamed('/');
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
