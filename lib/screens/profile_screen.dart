import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  AppUser? _currentUser;
  bool _isLoading = true;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserData();
    }
  }

  Future<void> _changeAvatar() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      final response = await ApiClient.instance.put(
        '/api/users/avatar',
        body: {
          'avatarBase64': dataUrl,
        },
        authenticated: true,
      );

      if (response['success'] == true) {
        await _loadUserData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to update avatar');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating photo: $error')),
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.instance.fetchCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _currentUser!.fullName);
    final phoneController = TextEditingController(text: _currentUser!.phone);
    final formKey = GlobalKey<FormState>();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                if (!formKey.currentState!.validate()) return;

                setState(() {
                  isUpdating = true;
                });

                try {
                  final response = await ApiClient.instance.put(
                    '/api/users/profile',
                    body: {
                      'fullName': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                    },
                    authenticated: true,
                  );

                  if (response['success'] == true) {
                    // Update local user data
                    await _loadUserData();
                    
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    throw Exception(response['message'] ?? 'Failed to update profile');
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating profile: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      isUpdating = false;
                    });
                  }
                }
              },
              child: isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage() {
    final avatarUrl = _currentUser?.avatarUrl ?? '';
    if (avatarUrl.isEmpty) {
      return const Icon(
        Icons.person,
        size: 48,
        color: Colors.white,
      );
    }

    try {
      final base64Part = avatarUrl.contains('base64,')
          ? avatarUrl.split('base64,').last
          : avatarUrl;
      final bytes = base64Decode(base64Part);
      return ClipOval(
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return const Icon(
        Icons.person,
        size: 48,
        color: Colors.white,
      );
    }
  }

  void _showMyFixesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Fixes'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your repair history will appear here'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildFixItem('Kitchen Sink Repair', 'Completed', 'Rs.2,500', '2024-01-15'),
                    _buildFixItem('AC Maintenance', 'Completed', 'Rs.1,800', '2024-01-10'),
                    _buildFixItem('Electrical Wiring', 'In Progress', 'Rs.3,200', '2024-01-20'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSavedSolutionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Solutions'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your bookmarked DIY solutions'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildSolutionItem('Fix Leaky Faucet', 'Plumbing', '5 min read'),
                    _buildSolutionItem('Clean AC Filters', 'HVAC', '3 min read'),
                    _buildSolutionItem('Replace Light Switch', 'Electrical', '8 min read'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFavoritesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorite Services'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your liked repair services'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildFavoriteServiceItem('Quick Plumbing', '4.8★', 'Rs.500/hr'),
                    _buildFavoriteServiceItem('Expert Electricians', '4.9★', 'Rs.600/hr'),
                    _buildFavoriteServiceItem('Pro AC Service', '4.7★', 'Rs.700/hr'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReviewsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Reviews'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your service reviews'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildReviewItem('Quick Plumbing', 'Great service!', 5, '2024-01-15'),
                    _buildReviewItem('Expert Electricians', 'Very professional', 4, '2024-01-10'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFixItem(String title, String status, String cost, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text('$date • $status'),
        trailing: Text(
          cost,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  Widget _buildSolutionItem(String title, String category, String readTime) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.bookmark, color: Color(0xFF6366F1)),
        title: Text(title),
        subtitle: Text('$category • $readTime'),
      ),
    );
  }

  Widget _buildFavoriteServiceItem(String name, String rating, String price) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.favorite, color: Colors.red),
        title: Text(name),
        subtitle: Text(rating),
        trailing: Text(
          price,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(String serviceName, String review, int rating, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(serviceName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(5, (index) => Icon(
                index < rating ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.amber,
              )),
            ),
            const SizedBox(height: 4),
            Text(review),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool pushEnabled = true;
        bool emailEnabled = true;
        bool serviceUpdatesEnabled = true;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _loadPrefsOnce() async {
              try {
                final prefs = await SharedPreferences.getInstance();
                setState(() {
                  pushEnabled = prefs.getBool('notif_push') ?? true;
                  emailEnabled = prefs.getBool('notif_email') ?? true;
                  serviceUpdatesEnabled = prefs.getBool('notif_service_updates') ?? true;
                });
              } catch (_) {}
            }

            // Trigger load on first build
            if (pushEnabled == true && emailEnabled == true && serviceUpdatesEnabled == true) {
              _loadPrefsOnce();
            }

            Future<void> _savePrefs() async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_push', pushEnabled);
                await prefs.setBool('notif_email', emailEnabled);
                await prefs.setBool('notif_service_updates', serviceUpdatesEnabled);
              } catch (_) {}
            }

            return AlertDialog(
              title: const Text('Notification Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Receive app alerts and reminders'),
                    value: pushEnabled,
                    onChanged: (value) {
                      setState(() {
                        pushEnabled = value;
                      });
                      _savePrefs();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Receive important updates by email'),
                    value: emailEnabled,
                    onChanged: (value) {
                      setState(() {
                        emailEnabled = value;
                      });
                      _savePrefs();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Service Updates'),
                    subtitle: const Text('Tips and updates about your repair services'),
                    value: serviceUpdatesEnabled,
                    onChanged: (value) {
                      setState(() {
                        serviceUpdatesEnabled = value;
                      });
                      _savePrefs();
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'SnapFix',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.build,
        size: 48,
        color: Color(0xFF6366F1),
      ),
      children: [
        const Text('SnapFix is your trusted companion for all home repair and maintenance needs. Connect with skilled technicians, get instant AI-powered diagnostics, and keep your home in perfect condition.'),
        const SizedBox(height: 16),
        const Text('Features:'),
        const Text('• AI-powered problem detection'),
        const Text('• Verified repair professionals'),
        const Text('• Real-time service tracking'),
        const Text('• Secure payment processing'),
        const SizedBox(height: 16),
        const Text('Powered by SnapFix'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load profile',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildStats(context),
              const SizedBox(height: 24),
              _buildMenuItems(context),
              const SizedBox(height: 24),
              _buildSettings(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final gradient = LinearGradient(
      colors: [
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primary.withOpacity(0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit, color: Colors.white70),
            ),
          ),
          GestureDetector(
            onTap: _changeAvatar,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
              ),
              child: _buildAvatarImage(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser!.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentUser!.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          if (_currentUser!.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _currentUser!.phone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentUser!.isProMember ? 'Pro Member' : 'Basic Member',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
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
            'Your Activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Problems Fixed',
                  '${_currentUser!.problemsFixed}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Money Saved',
                  'Rs.${_currentUser!.moneySaved}',
                  Icons.savings,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Services Used',
                  '${_currentUser!.servicesUsed}',
                  Icons.build,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.05 : 0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            'My Fixes',
            'View your repair history',
            Icons.history,
            () {
              context.go('/history');
            },
          ),
          _buildMenuItem(
            'Saved Solutions',
            'Your bookmarked fixes',
            Icons.bookmark,
            _showSavedSolutionsDialog,
          ),
          _buildMenuItem(
            'Favorites',
            'Liked repair services',
            Icons.favorite,
            _showFavoritesDialog,
          ),
          _buildMenuItem(
            'Location Settings',
            'Manage location permissions',
            Icons.location_on,
            _navigateToLocationPermission,
          ),
          _buildMenuItem(
            'Reviews',
            'Your service reviews',
            Icons.rate_review,
            _showReviewsDialog,
          ),
        ],
      ),
    );
  }

  void _navigateToLocationPermission() {
    context.go('/location-permission');
  }


  Widget _buildMenuItem(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.grey[700],
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? Colors.red
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: isDestructive
              ? Colors.red.withOpacity(0.7)
              : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: isDestructive
            ? Colors.red
            : Theme.of(context).iconTheme.color?.withOpacity(0.7),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear any stored user data if needed
              // Navigate to login page
              context.go('/login');
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.05 : 0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            'Notifications',
            'Manage your notifications',
            Icons.notifications,
            _showNotificationsDialog,
          ),
          _buildMenuItem(
            'Privacy',
            'Control your privacy settings',
            Icons.privacy_tip,
            () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Privacy'),
                  content: const Text(
                    'SnapFix stores only the data needed to provide repair suggestions and connect you with providers. '
                    'Your photos and analysis history are kept secure and are not shared with providers without your action.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildMenuItem(
            'Help & Support',
            'Get help and contact support',
            Icons.help,
            () async {
              const email = 'support@snapfix.app';
              const subject = 'SnapFix Support Request';
              final uri = Uri(
                scheme: 'mailto',
                path: email,
                query: 'subject=${Uri.encodeComponent(subject)}',
              );

              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open email app. Please contact support@snapfix.app'),
                    ),
                  );
                }
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open email app. Please contact support@snapfix.app'),
                  ),
                );
              }
            },
          ),
          _buildMenuItem(
            'About',
            'App version and info',
            Icons.info,
            _showAboutDialog,
          ),
          const Divider(),
          _buildMenuItem(
            'Logout',
            'Sign out of your account',
            Icons.logout,
            _handleLogout,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}
