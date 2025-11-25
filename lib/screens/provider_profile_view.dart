import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';

class ProviderProfileView extends StatelessWidget {
  const ProviderProfileView({super.key});

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

  Future<void> _showRequestJobDialog(BuildContext context, Map<String, dynamic> provider) async {
    final descriptionController = TextEditingController();
    final timeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
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
                      decoration: const InputDecoration(
                        labelText: 'Preferred time (optional)',
                        border: OutlineInputBorder(),
                      ),
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
                              Navigator.of(dialogContext).pop();
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
                onPressed: () => _showRequestJobDialog(context, provider),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Request Job'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
