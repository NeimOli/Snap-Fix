import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';

class ProviderProfileView extends StatefulWidget {
  const ProviderProfileView({super.key});

  @override
  State<ProviderProfileView> createState() => _ProviderProfileViewState();
}

class _ProviderProfileViewState extends State<ProviderProfileView> {
  bool _hasPendingRequestedJob = false;
  bool _isCheckingJobs = false;
  bool _pendingCheckStarted = false;
  String? _pendingJobId;

  Future<void> _callProvider(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available for this provider.')),
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

  Future<void> _showCancelRequestDialog(Map<String, dynamic> provider) async {
    if (_pendingJobId == null) return;

    // First, show a confirmation dialog
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Are you sure you want to cancel this service request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    // Then show the reason input dialog
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reason for Cancellation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Help us improve by sharing why you\'re canceling:'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Reason (optional)',
                      filled: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Back'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setState(() {
                            isSubmitting = true;
                          });
                          try {
                            await ApiClient.instance.post(
                              '/api/jobs/$_pendingJobId/cancel',
                              body: {'reason': reasonController.text.trim()},
                              authenticated: true,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } on ApiException catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(false);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('Failed to cancel request. Please try again.')),
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(false);
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      // Refresh the pending job status
      await _checkPendingJobForProvider(provider);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancelled successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _showRequestJobDialog(BuildContext context, Map<String, dynamic> provider) async {
    final descriptionController = TextEditingController();
    final timeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    TimeOfDay? selectedTime;

    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Request a Job'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Describe your problem',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please describe the problem';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: timeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Preferred time (optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Select time',
                      ),
                      onTap: () async {
                        final now = TimeOfDay.now();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? now,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                            timeController.text = picked.format(context);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isSubmitting = true;
                          });

                          try {
                            final String description = descriptionController.text.trim();
                            final String preferred = timeController.text.trim();
                            final String? providerEmail = provider['email']?.toString();
                            final String? providerName = provider['name']?.toString();
                            final String? serviceId = provider['_id']?.toString();
                            final num? ratePerHour = provider['ratePerHour'] as num?;

                            final body = <String, dynamic>{
                              'providerEmail': providerEmail,
                              'providerName': providerName,
                              'serviceId': serviceId,
                              'description': description,
                              'preferredTime': preferred,
                              if (ratePerHour != null) 'ratePerHour': ratePerHour,
                            };

                            await ApiClient.instance.post(
                              '/api/jobs',
                              body: body,
                              authenticated: true,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Job request sent to ${providerName ?? provider['name'] ?? 'provider'}.',
                                  ),
                                ),
                              );
                            }
                          } on ApiException catch (e) {
                            setState(() {
                              isSubmitting = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              isSubmitting = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to send job request: $e')),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );

    return sent == true;
  }

  Future<void> _checkPendingJobForProvider(Map<String, dynamic> provider) async {
    if (_isCheckingJobs) return;
    setState(() {
      _isCheckingJobs = true;
    });

    try {
      final response = await ApiClient.instance.get(
        '/api/jobs/user',
        authenticated: true,
      );

      final jobs = (response['jobs'] as List<dynamic>? ?? <dynamic>[]);
      final providerEmail = provider['email']?.toString();
      final providerId = provider['_id']?.toString();

      bool hasPending = false;
      String? pendingJobId;
      for (final job in jobs) {
        final map = job as Map<String, dynamic>;
        final status = map['status']?.toString();
        if (status == 'requested') {
          final jobProvider = map['provider'] as Map<String, dynamic>?;
          final jobProviderEmail = jobProvider?['email']?.toString();
          final jobProviderId = jobProvider?['_id']?.toString();

          if ((providerEmail != null && providerEmail.isNotEmpty && jobProviderEmail == providerEmail) ||
              (providerId != null && providerId.isNotEmpty && jobProviderId == providerId)) {
            hasPending = true;
            pendingJobId = map['_id']?.toString();
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasPendingRequestedJob = hasPending;
          _pendingJobId = pendingJobId;
        });
      }
    } catch (_) {
      // ignore errors here, just don't block the UI
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingJobs = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routerState = GoRouterState.of(context);
    final extra = routerState.extra;

    if (extra is! Map<String, dynamic>) {
      return Scaffold(
        appBar: AppBar(title: const Text('Provider Profile')),
        body: const Center(child: Text('Provider information not available.')),
      );
    }

    final provider = extra;
    final String name = provider['name']?.toString() ?? 'Provider';
    final String category = provider['category']?.toString() ?? 'General';
    final String distance = provider['distance']?.toString() ?? '';
    num? ratePerHour = provider['ratePerHour'] as num?;
    String price = provider['price']?.toString() ?? '';
    if (price.trim().isEmpty || price.trim() == 'Rs 0' || price.trim() == 'Rs 0/hour') {
      final num effectiveRate = (ratePerHour ?? 50);
      price = 'Rs ${effectiveRate.toStringAsFixed(0)}/hour';
    }
    final String availability = provider['availability']?.toString() ?? '';
    final double rating = (provider['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviews = (provider['reviews'] as num?)?.toInt() ?? 0;
    final String? phone = provider['phone']?.toString();
    final List<String> services =
        (provider['services'] as List?)?.map((e) => e.toString()).toList() ?? const [];

    if (!_pendingCheckStarted) {
      _pendingCheckStarted = true;
      _checkPendingJobForProvider(provider);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to the Services screen in the user dashboard
            context.go('/repair-services');
          },
        ),
        title: const Text('Provider Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                    backgroundColor: Colors.white.withOpacity(0.18),
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
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
                          ),
                        ),
                        if (distance.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            distance,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$reviews reviews',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
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
                    color: Colors.black.withOpacity(
                      theme.brightness == Brightness.light ? 0.05 : 0.4,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (availability.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            availability,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  if (price.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            price,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Services offered',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: services
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                s,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _hasPendingRequestedJob
                    ? null
                    : () async {
                        final sent = await _showRequestJobDialog(context, provider);
                        if (sent) {
                          await _checkPendingJobForProvider(provider);
                        }
                      },
                icon: const Icon(Icons.assignment_outlined),
                label: Text(_hasPendingRequestedJob ? 'Request pending' : 'Request Job'),
              ),
            ),
            if (_hasPendingRequestedJob && _pendingJobId != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showCancelRequestDialog(provider),
                  child: const Text(
                    'Cancel request',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
