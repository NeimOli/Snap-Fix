import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';

class UserJobsScreen extends StatefulWidget {
  const UserJobsScreen({super.key});

  @override
  State<UserJobsScreen> createState() => _UserJobsScreenState();
}

class _UserJobsScreenState extends State<UserJobsScreen> {
  int? currentRating;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _isRatingDialogShown = false;
  String? _error;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
      _isRatingDialogShown = false; // Reset flag when refreshing
      _error = null;
    }

    try {
      final response = await ApiClient.instance.get(
        '/api/jobs/user',
        authenticated: true,
      );
      final list = (response['jobs'] as List<dynamic>? ?? <dynamic>[]).map<Map<String, dynamic>>((e) => e as Map<String, dynamic>).toList();
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _isRefreshing = false;
        _showRatingDialogIfNeeded();
        _jobs = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _isActiveStatus(String? status) {
    final s = status?.toLowerCase();
    return s == 'accepted' || s == 'in_progress';
  }

  Future<void> _callPhone(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available.')),
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

  void _showRatingDialogIfNeeded() {
    if (_isRatingDialogShown || !mounted) return;
    
    // Find the first completed job without a rating
    try {
      final unratedJob = _jobs.firstWhere(
        (job) {
          final status = job['status']?.toString().toLowerCase();
          final hasRating = (job['rating'] is num) && (job['rating'] ?? 0) > 0;
          return status == 'completed' && !hasRating;
        },
        orElse: () => <String, dynamic>{},
      );

      // Skip if no unrated jobs found
      if (unratedJob.isEmpty) return;

      if (unratedJob.isNotEmpty) {
        _isRatingDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            barrierDismissible: false, // User must rate to dismiss
            builder: (context) => _buildRatingDialog(
              jobId: unratedJob['_id'].toString(),
              providerName: unratedJob['provider']?['name']?.toString() ?? 'the provider',
            ),
          );
        });
      }
    } catch (e) {
      // No unrated jobs found or other error
      debugPrint('No unrated jobs or error: $e');
    }
  }

  Widget _buildRatingDialog({
    required String jobId,
    required String providerName,
  }) {
    return AlertDialog(
      title: const Text('Rate your experience'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How would you rate your service with $providerName?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  Icons.star,
                  size: 36,
                  color: (index < (currentRating ?? 0)) ? Colors.amber : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    currentRating = index + 1;
                  });
                },
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: currentRating == null
              ? null
              : () async {
                  try {
                    await ApiClient.instance.post(
                      '/api/jobs/$jobId/rate',
                      body: {'rating': currentRating},
                      authenticated: true,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thanks for your rating!')),
                      );
                      Navigator.pop(context);
                      _loadJobs(); // Refresh the list
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to submit rating. Please try again.')),
                      );
                    }
                  }
                },
          child: const Text('Submit'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jobs'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  )
                : _jobs.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No jobs yet.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final job = _jobs[index];
                          final rawStatus = job['status']?.toString() ?? '';
                          final status = rawStatus;
                          final isActive = _isActiveStatus(status);
                          final description = job['description']?.toString() ?? '';
                          final service = job['service'] as Map<String, dynamic>?;
                          final provider = job['provider'] as Map<String, dynamic>?;
                          final serviceName = service != null
                              ? (service['name']?.toString() ?? 'Service')
                              : 'Service';
                          final providerName = provider != null
                              ? (provider['fullName']?.toString() ?? provider['name']?.toString() ?? 'Provider')
                              : 'Provider';
                          final providerPhone = provider != null ? provider['phone']?.toString() : null;
                          final jobId = job['_id']?.toString();
                          final hasRating = (job['rating'] is num) && (job['rating'] ?? 0) > 0;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    theme.brightness == Brightness.light ? 0.05 : 0.4,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            serviceName,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            providerName,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _isActiveStatus(status)
                                            ? Colors.orange.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        rawStatus.toLowerCase() == 'requested'
                                            ? 'Waiting for provider to accept'
                                            : status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _isActiveStatus(status) ? Colors.orange : Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                if (isActive) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _callPhone(context, providerPhone),
                                          icon: const Icon(Icons.call),
                                          label: const Text('Call'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            final jobId = job['_id']?.toString();
                                            if (jobId == null) return;
                                            context.push(
                                              '/job-chat',
                                              extra: <String, dynamic>{
                                                'jobId': jobId,
                                                'providerName': providerName,
                                                'providerPhone': providerPhone,
                                              },
                                            );
                                          },
                                          icon: const Icon(Icons.chat_bubble_outline),
                                          label: const Text('Chat'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (status.toLowerCase() == 'completed' && jobId != null && !hasRating) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final rating = await showDialog<int>(
                                          context: context,
                                          builder: (dialogContext) {
                                            int selected = 5;
                                            return StatefulBuilder(
                                              builder: (context, setState) {
                                                return AlertDialog(
                                                  title: const Text('Rate your provider'),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: List.generate(5, (index) {
                                                          final starIndex = index + 1;
                                                          final isFilled = starIndex <= selected;
                                                          return IconButton(
                                                            icon: Icon(
                                                              isFilled ? Icons.star : Icons.star_border,
                                                              color: Colors.amber,
                                                            ),
                                                            onPressed: () {
                                                              setState(() {
                                                                selected = starIndex;
                                                              });
                                                            },
                                                          );
                                                        }),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(dialogContext).pop(),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.of(dialogContext).pop(selected),
                                                      child: const Text('Submit'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        );

                                        if (rating == null) return;

                                        try {
                                          await ApiClient.instance.post(
                                            '/api/jobs/$jobId/rate',
                                            body: {'rating': rating},
                                            authenticated: true,
                                          );

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Thanks for rating your provider!')),
                                          );
                                          await _loadJobs();
                                        } catch (error) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to submit rating: $error')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.star_rate),
                                      label: const Text('Rate provider'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
