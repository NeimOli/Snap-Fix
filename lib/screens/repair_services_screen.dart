import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';

class RepairServicesScreen extends StatefulWidget {
  const RepairServicesScreen({super.key});

  @override
  State<RepairServicesScreen> createState() => _RepairServicesScreenState();
}

class _RepairServicesScreenState extends State<RepairServicesScreen> {
  String _selectedCategory = 'All';
  String _selectedSort = 'Distance';

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _userJobs = [];
  final Map<String, Map<String, dynamic>> _activeJobsByServiceId = {};

  final List<String> _categories = ['All', 'Plumbing', 'Electronics', 'Appliances', 'Furniture'];
  final List<String> _sortOptions = ['Distance', 'Rating', 'Price', 'Availability'];

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadUserJobs();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.get(
        '/api/services',
        queryParameters: {
          'category': _selectedCategory,
          'sort': _selectedSort.toLowerCase(),
        },
      );

      if (response['success'] == true && response['services'] is List) {
        final list = response['services'] as List;
        setState(() {
          _services = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message']?.toString() ?? 'Failed to load services';
          _isLoading = false;
        });
      }
    } on ApiException catch (error) {
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Failed to load services: $error';
        _isLoading = false;
      });
    }
  }

  bool _isActiveJobStatus(String? status) {
    final s = status?.toLowerCase();
    return s == 'accepted' || s == 'in_progress';
  }

  Future<void> _loadUserJobs() async {
    try {
      final response = await ApiClient.instance.get(
        '/api/jobs/user',
        authenticated: true,
      );
      final list = (response['jobs'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _userJobs = list;
      _activeJobsByServiceId.clear();

      for (final job in _userJobs) {
        final status = job['status']?.toString();
        if (!_isActiveJobStatus(status)) continue;

        final service = job['service'] as Map<String, dynamic>?;
        if (service == null) continue;
        final serviceId = service['_id']?.toString();
        if (serviceId == null || serviceId.isEmpty) continue;

        // For now, if multiple active jobs exist for same service, last one wins.
        _activeJobsByServiceId[serviceId] = job;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Ignore errors here; services list still works even if jobs fail.
    }
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a phone call.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a phone call.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Repair Services',
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: theme.iconTheme.color),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: theme.iconTheme.color),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildServicesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Sort options (shown first)
          Row(
            children: [
              Text(
                'Sort by:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sortOptions.length,
                    itemBuilder: (context, index) {
                      final sort = _sortOptions[index];
                      final isSelected = _selectedSort == sort;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSort = sort;
                          });
                          _loadServices();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            sort,
                            style: TextStyle(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Category filter
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _loadServices();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_services.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No services found for the selected filters.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return _buildServiceCard(service);
      },
    );
  }

  Color _getStatusColor(String availability) {
    final text = availability.toLowerCase();
    if (text.contains('available now')) {
      return Colors.green;
    }
    if (text.contains('available in') || text.contains('hour')) {
      return Colors.orange;
    }
    if (text.contains('tomorrow') || text.contains('later')) {
      return Colors.blue;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final theme = Theme.of(context);

    final String name = service['name']?.toString() ?? 'Service Provider';
    final double rating = (service['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviews = (service['reviews'] as num?)?.toInt() ?? 0;
    final double? distanceMiles = (service['distance'] as num?)?.toDouble();
    final String distanceText =
        distanceMiles != null ? '${distanceMiles.toStringAsFixed(1)} miles' : '';
    num? ratePerHour = service['ratePerHour'] as num?;
    String price = service['price']?.toString() ?? '';
    // If backend stored 0 or empty price, fall back to ratePerHour (default 50)
    if (price.trim().isEmpty || price.trim() == 'Rs 0' || price.trim() == 'Rs 0/hour') {
      final num effectiveRate = (ratePerHour ?? 50);
      price = 'Rs ${effectiveRate.toStringAsFixed(0)}/hour';
    }
    final String availability = service['availability']?.toString() ?? '';
    final String category = service['category']?.toString() ?? '';
    final List<String> servicesOffered =
        (service['services'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final Color statusColor = _getStatusColor(availability);
    final bool isAvailableNow = availability.toLowerCase().contains('available now');

    final String serviceId = service['_id']?.toString() ?? '';
    final Map<String, dynamic>? activeJob =
        serviceId.isNotEmpty ? _activeJobsByServiceId[serviceId] : null;
    final bool hasActiveJob = activeJob != null;
    Map<String, dynamic>? jobProvider;
    String? jobProviderPhone;
    String? jobProviderName;
    String? jobId;
    if (hasActiveJob) {
      jobProvider = activeJob['provider'] as Map<String, dynamic>?;
      jobProviderPhone = jobProvider != null ? jobProvider['phone']?.toString() : null;
      jobProviderName = jobProvider != null
          ? (jobProvider['fullName']?.toString() ?? jobProvider['name']?.toString())
          : null;
      jobId = activeJob['_id']?.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              // Service provider image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // Service info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            availability,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.toStringAsFixed(1)} ($reviews reviews)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.location_on,
                          color: theme.iconTheme.color?.withOpacity(0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Services offered
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: servicesOffered.map((serviceName) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  serviceName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Price and action button
          Row(
            children: [
              Expanded(
                child: Text(
                  price,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (hasActiveJob && jobId != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPhone(jobProviderPhone),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
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
                          'providerName': jobProviderName ?? name,
                          'providerPhone': jobProviderPhone,
                        },
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isAvailableNow
                        ? () {
                            context.go('/provider-profile', extra: service);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isAvailableNow ? 'See details' : 'Busy',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
