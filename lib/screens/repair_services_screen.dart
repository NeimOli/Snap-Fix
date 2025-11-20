import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RepairServicesScreen extends StatefulWidget {
  const RepairServicesScreen({super.key});

  @override
  State<RepairServicesScreen> createState() => _RepairServicesScreenState();
}

class _RepairServicesScreenState extends State<RepairServicesScreen> {
  String _selectedCategory = 'All';
  String _selectedSort = 'Distance';

  final List<String> _categories = ['All', 'Plumbing', 'Electronics', 'Appliances', 'Furniture'];
  final List<String> _sortOptions = ['Distance', 'Rating', 'Price', 'Availability'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Repair Services',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
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
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Sort options
          Row(
            children: [
              const Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
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
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.grey[200] : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            sort,
                            style: TextStyle(
                              color: isSelected ? Colors.black87 : Colors.grey[600],
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
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    final services = [
      {
        'name': 'Mike\'s Plumbing',
        'rating': 4.9,
        'reviews': 127,
        'distance': '0.8 miles',
        'price': 'Rs 9,975/hour',
        'availability': 'Available now',
        'statusColor': Colors.green,
        'category': 'Plumbing',
        'image': 'https://example.com/mike.jpg',
        'services': ['Faucet repair', 'Pipe leaks', 'Drain cleaning'],
      },
      {
        'name': 'Quick Fix Services',
        'rating': 4.7,
        'reviews': 89,
        'distance': '1.2 miles',
        'price': 'Rs 8,645/hour',
        'availability': 'Available in 2 hours',
        'statusColor': Colors.orange,
        'category': 'Electronics',
        'image': 'https://example.com/quickfix.jpg',
        'services': ['Phone repair', 'Laptop fixes', 'TV repair'],
      },
      {
        'name': 'Pro Repair Co.',
        'rating': 4.8,
        'reviews': 203,
        'distance': '2.1 miles',
        'price': 'Rs 11,305/hour',
        'availability': 'Available tomorrow',
        'statusColor': Colors.blue,
        'category': 'Appliances',
        'image': 'https://example.com/prorepair.jpg',
        'services': ['Washing machine', 'Refrigerator', 'Dishwasher'],
      },
      {
        'name': 'Furniture Fixers',
        'rating': 4.6,
        'reviews': 45,
        'distance': '1.5 miles',
        'price': 'Rs 7,980/hour',
        'availability': 'Available now',
        'statusColor': Colors.green,
        'category': 'Furniture',
        'image': 'https://example.com/furniture.jpg',
        'services': ['Chair repair', 'Table fixes', 'Cabinet repair'],
      },
      {
        'name': 'Tech Solutions',
        'rating': 4.9,
        'reviews': 156,
        'distance': '0.5 miles',
        'price': 'Rs 9,310/hour',
        'availability': 'Available in 1 hour',
        'statusColor': Colors.orange,
        'category': 'Electronics',
        'image': 'https://example.com/tech.jpg',
        'services': ['Computer repair', 'Gaming console', 'Audio equipment'],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Added bottom padding
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(service);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  color: Colors.grey[200],
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
                            service['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (service['statusColor'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            service['availability'],
                            style: TextStyle(
                              color: service['statusColor'],
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
                          '${service['rating']} (${service['reviews']} reviews)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.location_on,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service['distance'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
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
            children: (service['services'] as List<String>).map((serviceName) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Price and action buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  service['price'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'View Profile',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
