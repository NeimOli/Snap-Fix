import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/admin_auth_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _adminEmail;
  List<dynamic> _users = [];
  bool _isLoadingUsers = true;
  bool _isPerformingUserAction = false;
  
  // Sample data for dashboard (fallback)
  final List<Map<String, dynamic>> _recentUsers = [
    {'name': 'John Doe', 'email': 'john@example.com', 'date': '2024-01-15', 'status': 'Active'},
    {'name': 'Jane Smith', 'email': 'jane@example.com', 'date': '2024-01-14', 'status': 'Active'},
    {'name': 'Mike Johnson', 'email': 'mike@example.com', 'date': '2024-01-13', 'status': 'Inactive'},
  ];

  final List<Map<String, dynamic>> _recentAnalyses = [
    {'user': 'John Doe', 'type': 'Plumbing', 'date': '2024-01-15', 'status': 'Completed'},
    {'user': 'Jane Smith', 'type': 'Electrical', 'date': '2024-01-14', 'status': 'In Progress'},
    {'user': 'Mike Johnson', 'type': 'Appliance', 'date': '2024-01-13', 'status': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAuthenticationAndLoadData();
  }

  Future<void> _checkAuthenticationAndLoadData() async {
    final isLoggedIn = await AdminAuthService.isLoggedIn();
    
    if (!isLoggedIn) {
      if (mounted) {
        context.go('/profile');
      }
      return;
    }

    // Get admin data
    final adminData = await AdminAuthService.getAdminData();
    if (adminData != null) {
      setState(() {
        _adminEmail = adminData['email'];
      });
    }

    // Load dashboard data
    await _loadDashboardData();
    await _loadUsers();
  }

  Future<void> _loadDashboardData() async {
    try {
      final result = await AdminAuthService.getDashboardData();
      if (result['success']) {
        setState(() {
          _dashboardData = result['data'];
          _isLoading = false;
        });
      } else {
        // Use sample data if API fails
        setState(() {
          _dashboardData = {
            'stats': {
              'totalUsers': 1234,
              'activeAnalyses': 45,
              'revenue': 245000,
              'weeklyActivity': [1, 3, 2, 5, 4, 6, 7]
            },
            'recentUsers': _recentUsers,
            'recentAnalyses': _recentAnalyses,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      // Use sample data on error
      setState(() {
        _dashboardData = {
          'stats': {
            'totalUsers': 1234,
            'activeAnalyses': 45,
            'revenue': 245000,
            'weeklyActivity': [1, 3, 2, 5, 4, 6, 7]
          },
          'recentUsers': _recentUsers,
          'recentAnalyses': _recentAnalyses,
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    final users = await AdminAuthService.fetchUsers();

    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoadingUsers = false;
    });
  }

  Future<void> _logout() async {
    await AdminAuthService.logout();
    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _showApiConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrlController = TextEditingController(text: prefs.getString('admin_api_base_url') ?? '');
    final providerController = TextEditingController(text: prefs.getString('admin_ai_provider') ?? 'default');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('API Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Backend Base URL',
                  hintText: 'https://api.snapfix.yourdomain.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: providerController,
                decoration: const InputDecoration(
                  labelText: 'AI Provider',
                  hintText: 'groq / huggingface / default',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setString('admin_api_base_url', baseUrlController.text.trim());
                await prefs.setString('admin_ai_provider', providerController.text.trim());
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API configuration saved locally')), 
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUserPermissionsDialog() async {
    final totalUsers = _users.length;
    final userRoleCount = _users.where((u) => (u as Map<String, dynamic>)['role'] == 'user').length;
    final providerRoleCount = _users.where((u) => (u as Map<String, dynamic>)['role'] == 'provider').length;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('User Permissions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total accounts: $totalUsers'),
              const SizedBox(height: 8),
              Text('Users: $userRoleCount'),
              Text('Providers: $providerRoleCount'),
              const SizedBox(height: 12),
              const Text(
                'Roles are managed by the backend using the user "role" field. '
                'Use provider onboarding to create new providers.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSystemMaintenanceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isRefreshing = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('System Maintenance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Use these tools to keep the admin dashboard in sync.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () async {
                    if (isRefreshing) return;
                    setState(() {
                      isRefreshing = true;
                    });
                    await _loadDashboardData();
                    await _loadUsers();
                    if (!mounted) return;
                    setState(() {
                      isRefreshing = false;
                    });
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dashboard data refreshed')),
                    );
                  },
                  child: isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Refresh data'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _confirmLogout();
                  },
                  child: const Text('Clear admin session'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDataExportDialog() async {
    final exportPayload = {
      'stats': _dashboardData?['stats'] ?? {},
      'userCount': _users.length,
    };

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Data Export'),
          content: const Text(
            'Copy a JSON summary of key metrics to the clipboard. '
            'You can paste this into a file or spreadsheet tool.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: exportPayload.toString()));
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export data copied to clipboard')),
                );
              },
              child: const Text('Copy JSON'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout from Admin?'),
          content: const Text('You will need to log in again to access the admin dashboard.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _logout();
    }
  }

  List<FlSpot> _getWeeklyActivitySpots() {
    final weeklyActivity = _dashboardData?['stats']?['weeklyActivity'] as List<dynamic>? ?? [1, 3, 2, 5, 4, 6, 7];
    return weeklyActivity.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), (entry.value as num).toDouble());
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Dashboard...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.black87),
            onSelected: (value) {
              if (value == 'logout') {
                _confirmLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(_adminEmail ?? 'Admin'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            margin: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(child: _buildStatCard('Total Users', '${_dashboardData?['stats']?['totalUsers'] ?? 1234}', Colors.blue, Icons.people)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Active Providers', '${_dashboardData?['stats']?['activeProviders'] ?? 0}', Colors.green, Icons.home_repair_service)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Revenue', 'Rs ${(_dashboardData?['stats']?['revenue'] ?? 245000).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', Colors.orange, Icons.currency_rupee)),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Users'),
                Tab(text: 'Providers'),
                Tab(text: 'Settings'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildProvidersTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final recentAnalyses = (_dashboardData?['recentAnalyses'] as List<dynamic>? ?? _recentAnalyses)
        .whereType<Map<String, dynamic>>()
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _getWeeklyActivitySpots(),
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (recentAnalyses.isEmpty)
            const Text(
              'No recent activity yet.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...recentAnalyses.map((analysis) => _buildActivityCard(analysis)).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.analytics,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['user'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${activity['type']} • ${activity['date']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: activity['status'] == 'Completed' 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              activity['status'],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activity['status'] == 'Completed' 
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Users Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingUsers)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: const [
                  Icon(Icons.person_off, color: Colors.grey, size: 40),
                  SizedBox(height: 12),
                  Text('No users found', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            ..._users.map((user) => _buildUserCard(user as Map<String, dynamic>)).toList(),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = (user['id'] ?? user['_id'] ?? '').toString();
    final isPro = user['isProMember'] == true || user['status'] == 'Pro Member';
    final name = user['fullName'] ?? user['name'] ?? 'Unknown';
    final email = user['email'] ?? 'N/A';
    final phone = user['phone'] ?? 'Not provided';
    final joinedDate = user['createdAt']?.toString().split('T').first ?? user['date'] ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Joined $joinedDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPro ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isPro ? 'Pro Member' : 'Basic',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPro ? Colors.green : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditUserDialog(userId, name, email, phone, isPro);
              } else if (value == 'delete') {
                _confirmDeleteUser(userId, name);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit, size: 18),
                  title: Text('Edit'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, size: 18, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(
    String userId,
    String name,
    String email,
    String phone,
    bool isPro,
  ) async {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController(text: phone);
    bool isProMember = isPro;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(email, style: const TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pro Member'),
                value: isProMember,
                onChanged: (value) {
                  isProMember = value;
                  (context as Element).markNeedsBuild();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != true || _isPerformingUserAction) return;

    setState(() => _isPerformingUserAction = true);
    final success = await AdminAuthService.updateUser(userId, {
      'fullName': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'isProMember': isProMember,
    });
    if (!mounted) return;

    setState(() => _isPerformingUserAction = false);

    if (success) {
      await _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update user')),
      );
    }
  }

  Future<void> _confirmDeleteUser(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Delete $name? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true || _isPerformingUserAction) return;

    setState(() => _isPerformingUserAction = true);
    final success = await AdminAuthService.deleteUser(userId);
    if (!mounted) return;
    setState(() => _isPerformingUserAction = false);

    if (success) {
      await _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete user')),
      );
    }
  }

  Widget _buildProvidersTab() {
    final providers = _users.where((user) {
      final map = user as Map<String, dynamic>;
      final role = (map['role'] ?? '').toString().toLowerCase();
      return role == 'provider';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Providers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoadingUsers)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (providers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: const [
                  Icon(Icons.home_repair_service, color: Colors.grey, size: 40),
                  SizedBox(height: 12),
                  Text('No providers found', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            ...providers.map((user) => _buildProviderCard(user as Map<String, dynamic>)).toList(),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> user) {
    final name = user['fullName'] ?? user['name'] ?? 'Unknown Provider';
    final email = user['email'] ?? 'N/A';
    final phone = user['phone'] ?? 'Not provided';
    final category = user['serviceCategory'] ?? 'Category not set';
    final joinedDate = user['createdAt']?.toString().split('T').first ?? user['date'] ?? '—';
    final pan = (user['panNumber'] ?? '').toString().isNotEmpty ? user['panNumber'] : 'Not provided';
    final problemsFixed = user['problemsFixed'] ?? 0;
    final moneySaved = user['moneySaved'] ?? 0;
    final servicesUsed = user['servicesUsed'] ?? 0;
    final isPro = user['isProMember'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Icon(
              Icons.home_repair_service,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Pro',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Category: $category',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Joined $joinedDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PAN: $pan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Problems fixed: $problemsFixed',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Money saved: Rs $moneySaved',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Services used: $servicesUsed',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingItem(
            'API Configuration',
            'Manage OpenAI API settings',
            Icons.key,
            _showApiConfigDialog,
          ),
          _buildSettingItem(
            'User Permissions',
            'Manage user roles and permissions',
            Icons.admin_panel_settings,
            _showUserPermissionsDialog,
          ),
          _buildSettingItem(
            'System Maintenance',
            'System updates and maintenance',
            Icons.settings,
            _showSystemMaintenanceDialog,
          ),
          _buildSettingItem(
            'Data Export',
            'Export user data and analytics',
            Icons.download,
            _showDataExportDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String description, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
