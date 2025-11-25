import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      // First try backend
      final response = await ApiClient.instance.get(
        '/api/history',
        authenticated: true,
      );

      final items = (response['items'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as Map<String, dynamic>))
          .toList();

      // Sync to local cache for offline use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('analysis_history', jsonEncode(items));

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      // Fallback to local cache if backend fails
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('analysis_history');
        if (raw != null) {
          final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
          setState(() {
            _items = list.whereType<Map<String, dynamic>>().toList();
            _loading = false;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _items = [];
        _loading = false;
      });
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
          'History',
          style: theme.textTheme.titleLarge,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No past analyses yet. Run a scan to see history here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final problem = item['problem']?.toString() ?? 'Problem';
                    final cause = item['cause']?.toString() ?? '';
                    final createdAt = item['createdAt']?.toString();
                    final dateText = createdAt != null
                        ? DateTime.tryParse(createdAt)?.toLocal().toString().split('.').first
                        : null;

                    return InkWell(
                      onTap: () {
                        final solution = (item['solution'] as List<dynamic>? ?? [])
                            .map((e) => e.toString())
                            .toList();

                        context.push(
                          '/results',
                          extra: <String, dynamic>{
                            'imagePath': '',
                            'analysisResult': <String, dynamic>{
                              'problem': problem,
                              'cause': cause,
                              'solution': solution,
                              'tools': const <String>[],
                              'difficulty': 'Medium',
                              'estimatedTime': '30-60 minutes',
                              'safety': const <String>[],
                            },
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.05 : 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              problem,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (cause.isNotEmpty)
                              Text(
                                cause,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                ),
                              ),
                            if (dateText != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                dateText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
