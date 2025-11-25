import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _selectedIndex = 0;

  bool _isLoadingJobs = true;
  String? _jobsError;
  List<Map<String, dynamic>> _jobs = [];
  bool _isUpdatingJob = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoadingJobs = true;
      _jobsError = null;
    });

    try {
      final response = await ApiClient.instance.get(
        '/api/jobs/provider',
        authenticated: true,
      );

      if (response['success'] == true && response['jobs'] is List) {
        final list = response['jobs'] as List;
        setState(() {
          _jobs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoadingJobs = false;
        });
      } else {
        setState(() {
          _jobsError = response['message']?.toString() ?? 'Failed to load jobs';
          _isLoadingJobs = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _jobsError = e.message;
        _isLoadingJobs = false;
      });
    } catch (e) {
      setState(() {
        _jobsError = 'Failed to load jobs: $e';
        _isLoadingJobs = false;
      });
    }
  }

  Future<void> _callUser(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User phone number not available.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone.trim());
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a phone call.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a phone call.')),
      );
    }
  }

  Future<void> _updateJobStatus(String jobId, String actionPath) async {
    if (_isUpdatingJob) return;
    setState(() {
      _isUpdatingJob = true;
    });

    try {
      await ApiClient.instance.post(
        '/api/jobs/$jobId/$actionPath',
        authenticated: true,
      );
      await _loadJobs();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update job: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingJob = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    switch (_selectedIndex) {
      case 0:
        body = _buildDashboardTab(context, theme);
        break;
      case 1:
        body = _buildJobRequestsTab(context, theme);
        break;
      case 2:
        body = _buildProfileTab(context, theme);
        break;
      default:
        body = _buildDashboardTab(context, theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Provider Dashboard'
              : _selectedIndex == 1
                  ? 'Job Requests'
                  : 'Provider Profile',
        ),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Job requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildJobRequestsTab(BuildContext context, ThemeData theme) {
    final requestedJobs = _jobs.where((job) {
      final status = job['status']?.toString();
      return status == 'requested';
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadJobs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job requests',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New job requests from users will appear here. You can accept and then start the job.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingJobs)
              const Center(child: CircularProgressIndicator())
            else if (_jobsError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _jobsError!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
                ),
              )
            else if (requestedJobs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'No new job requests right now. When users request your service, you will see them here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requestedJobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final job = requestedJobs[index];
                  return _buildJobCard(context, job);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStatsSection(ThemeData theme) {
    int totalJobs = 0;
    int inProgressJobs = 0;
    int completedJobs = 0;
    num totalEarnings = 0;

    if (_jobs.isNotEmpty) {
      for (final job in _jobs) {
        final status = job['status']?.toString();
        totalJobs++;
        if (status == 'in_progress') {
          inProgressJobs++;
        } else if (status == 'completed') {
          completedJobs++;
          final price = job['totalPrice'];
          if (price is num) {
            totalEarnings += price;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.05 : 0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your job stats',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildProfileStatChip(theme, 'Total jobs', '$totalJobs', Icons.assignment_outlined),
              const SizedBox(width: 8),
              _buildProfileStatChip(theme, 'In progress', '$inProgressJobs', Icons.build_circle_outlined),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildProfileStatChip(theme, 'Completed', '$completedJobs', Icons.check_circle_outline),
              const SizedBox(width: 8),
              _buildProfileStatChip(theme, 'Earnings', 'Rs ${totalEarnings.toStringAsFixed(0)}', Icons.currency_rupee),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatChip(ThemeData theme, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(BuildContext context, ThemeData theme) {
    // Derive job counts from loaded jobs
    int newCount = 0;
    int inProgressCount = 0;
    int completedCount = 0;
    num todayEarnings = 0;

    if (!_isLoadingJobs && _jobs.isNotEmpty) {
      for (final job in _jobs) {
        final status = job['status']?.toString();
        if (status == 'requested') {
          newCount++;
        } else if (status == 'in_progress') {
          inProgressCount++;
        } else if (status == 'completed') {
          completedCount++;
          final price = job['totalPrice'];
          if (price is num) {
            todayEarnings += price;
          }
        }
      }
    }

    final user = AuthService.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card with provider info and quick stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.85),
                  theme.colorScheme.secondary.withOpacity(0.85),
                ],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  child: const Icon(
                    Icons.build_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Provider',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.serviceCategory.isNotEmpty == true
                            ? user!.serviceCategory
                            : 'Service category not set',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        completedCount > 0
                            ? 'You have completed $completedCount jobs today.'
                            : 'You have no completed jobs yet today.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${todayEarnings.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Today's summary",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: _buildStatCard(
                    context,
                    'New',
                    '$newCount',
                    Icons.inbox,
                    Colors.lightBlueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: _buildStatCard(
                    context,
                    'In progress',
                    '$inProgressCount',
                    Icons.build_circle,
                    Colors.deepOrangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: _buildStatCard(
                    context,
                    'Completed',
                    '$completedCount',
                    Icons.check_circle,
                    Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent jobs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingJobs)
            const Center(child: CircularProgressIndicator())
          else if (_jobsError != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _jobsError!,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
              ),
            )
          else if (_jobs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'No jobs yet. When users request your service, they will appear here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final job = _jobs[index];
                return _buildJobCard(context, job);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, ThemeData theme) {
    final user = AuthService.instance.currentUser;

    // Derive a simple availability status from current jobs
    bool hasActiveJob = false;
    if (_jobs.isNotEmpty) {
      for (final job in _jobs) {
        final status = job['status']?.toString();
        if (status == 'accepted' || status == 'in_progress') {
          hasActiveJob = true;
          break;
        }
      }
    }
    final String availabilityLabel = hasActiveJob ? 'Busy with a job' : 'Available now';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.16),
                  theme.colorScheme.primary.withOpacity(0.04),
                ],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child: Icon(
                    Icons.build,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Provider name',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.serviceCategory.isNotEmpty == true
                            ? user!.serviceCategory
                            : 'Service category not set',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade400),
                      const SizedBox(width: 4),
                      Text(
                        availabilityLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.05 : 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildContactRow(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? '-',
                ),
                const SizedBox(height: 8),
                _buildContactRow(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: user?.phone.isNotEmpty == true ? user!.phone : '-',
                ),
                const SizedBox(height: 8),
                _buildContactRow(
                  context,
                  icon: Icons.badge_outlined,
                  label: 'PAN Number',
                  value: user?.panNumber.isNotEmpty == true ? user!.panNumber : '-',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildProfileStatsSection(theme),
          const SizedBox(height: 24),
          Text(
            'How users contact you',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users will see your profile, service category and contact details when they request a job through SnapFix.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout from your provider account?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (shouldLogout != true) return;

                await AuthService.instance.logout();
                if (!context.mounted) return;
                context.go('/login');
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: Text(
                'Logout',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: theme.brightness == Brightness.light ? 1.5 : 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {}, // visual feedback only
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    final theme = Theme.of(context);
    final String description = job['description']?.toString() ?? 'Job request';
    final String rawStatus = job['status']?.toString() ?? '';

    // Map backend status to display label
    String statusLabel;
    switch (rawStatus) {
      case 'requested':
        statusLabel = 'New request';
        break;
      case 'accepted':
        statusLabel = 'Accepted';
        break;
      case 'in_progress':
        statusLabel = 'In progress';
        break;
      case 'completed':
        statusLabel = 'Completed';
        break;
      case 'cancelled':
        statusLabel = 'Cancelled';
        break;
      default:
        statusLabel = rawStatus.isNotEmpty ? rawStatus : 'Unknown';
    }

    // createdAt for time label
    String timeLabel = '';
    final createdAtRaw = job['createdAt'];
    if (createdAtRaw is String) {
      timeLabel = createdAtRaw;
    }

    // totalPrice for price label (or estimate if in progress)
    String priceLabel = '';
    final totalPrice = job['totalPrice'];
    final ratePerHour = job['ratePerHour'];
    if (rawStatus == 'completed' && totalPrice is num) {
      priceLabel = 'Rs ${totalPrice.toStringAsFixed(0)}';
    } else if (ratePerHour is num) {
      priceLabel = 'Rs ${ratePerHour.toStringAsFixed(0)}/hour';
    }
    Color statusColor;
    switch (rawStatus) {
      case 'requested':
        statusColor = Colors.blue;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = theme.colorScheme.primary;
    }

    final String jobId = job['_id']?.toString() ?? '';

    // user info for call/chat
    final user = job['user'] as Map<String, dynamic>?;
    final String userName = user != null
        ? (user['fullName']?.toString() ?? user['name']?.toString() ?? 'User')
        : 'User';
    final String? userPhone = user != null ? user['phone']?.toString() : null;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: theme.brightness == Brightness.light ? 1.5 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {}, // tap feedback only
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  description,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            priceLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (jobId.isNotEmpty && (rawStatus == 'accepted' || rawStatus == 'in_progress')) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callUser(context, userPhone),
                    icon: const Icon(Icons.call),
                    label: const Text('Call user'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push(
                        '/job-chat',
                        extra: <String, dynamic>{
                          'jobId': jobId,
                          'providerName': userName,
                        },
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (jobId.isNotEmpty)
            Row(
              children: [
                if (rawStatus == 'requested')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUpdatingJob
                          ? null
                          : () {
                              _updateJobStatus(jobId, 'accept');
                            },
                      child: const Text('Accept'),
                    ),
                  )
                else if (rawStatus == 'accepted')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdatingJob
                          ? null
                          : () {
                              _updateJobStatus(jobId, 'start');
                            },
                      child: const Text('Start Job'),
                    ),
                  )
                else if (rawStatus == 'in_progress')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdatingJob
                          ? null
                          : () {
                              _updateJobStatus(jobId, 'end');
                            },
                      child: const Text('End Job'),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildContactRow(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
