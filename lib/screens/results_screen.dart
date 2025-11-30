import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analysis_service.dart';
import '../services/api_client.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isAnalyzing = true;
  String? _imagePath;
  Map<String, dynamic>? _analysisResult;
  final TextEditingController _chatController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLoadingVideos = false;
  String? _videoError;
  List<Map<String, dynamic>> _videoGuides = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isAnalyzing) {
      final routerState = GoRouterState.of(context);
      final args = routerState.extra ?? ModalRoute.of(context)?.settings.arguments;

      if (args is Map && args.containsKey('imagePath') && args.containsKey('analysisResult')) {
        _imagePath = args['imagePath'] as String;
        _analysisResult = args['analysisResult'] as Map<String, dynamic>;
        setState(() {
          _isAnalyzing = false;
        });
        _loadVideoGuides();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  String _cleanText(String value) {
    var text = value;
    // Remove basic Markdown bold markers that may appear in the AI response.
    text = text.replaceAll('**', '');
    return text.trim();
  }

  Future<void> _loadVideoGuides() async {
    final problemText = _analysisResult?['problem']?.toString().trim();
    if (problemText == null || problemText.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingVideos = true;
      _videoError = null;
    });

    try {
      final response = await ApiClient.instance.get(
        '/api/analysis/videos',
        queryParameters: {
          'q': '$problemText repair tutorial',
        },
      );

      if (response['success'] == true && response['videos'] is List) {
        final List<dynamic> raw = response['videos'] as List<dynamic>;
        setState(() {
          _videoGuides = raw
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      } else {
        setState(() {
          _videoGuides = [];
        });
      }
    } catch (error) {
      setState(() {
        _videoError = error.toString();
        _videoGuides = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVideos = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color ?? theme.iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Analysis Results',
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: theme.appBarTheme.iconTheme?.color ?? theme.iconTheme.color),
            onPressed: () {},
          ),
        ],
      ),
      body: _isAnalyzing
          ? _buildAnalyzingView()
          : SafeArea(child: _buildResultsView()),
    );
  }

  Widget _buildAnalyzingView() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology,
              size: 60,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Analyzing your photo...',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Our AI is identifying the problem and\nfinding the best solutions',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideo(String url) async {
    try {
      final uri = Uri.parse(url);
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video link.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open video link.')),
      );
    }
  }

  Widget _buildResultsView() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
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
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'DIY Fix'),
              Tab(text: 'Video Guide'),
              Tab(text: 'Chat'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDIYFixTab(),
              _buildVideoGuideTab(),
              _buildChatTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab() {
    final theme = Theme.of(context);
    final contextText = _analysisResult?['cause']?.toString() ?? '';

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[_messages.length - 1 - index];
              final isUser = message.isUser;
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? theme.colorScheme.onPrimary
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.05 : 0.4),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ask a follow-up question...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                color: Theme.of(context).colorScheme.primary,
                onPressed: _isSending
                    ? null
                    : () {
                        final text = _chatController.text.trim();
                        if (text.isEmpty) return;
                        _sendChatMessage(text, contextText);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendChatMessage(String text, String contextText) async {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _chatController.clear();
      _isSending = true;
    });

    try {
      final answer = await AnalysisService.instance.chat(
        question: text,
        context: contextText,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Widget _buildDIYFixTab() {
    final theme = Theme.of(context);
    final solution = _analysisResult?['solution'] as List<dynamic>? ?? [];
    final tools = _analysisResult?['tools'] as List<dynamic>? ?? [];
    final difficulty = _analysisResult?['difficulty'] as String? ?? 'Medium';
    final estimatedTime = _analysisResult?['estimatedTime'] as String? ?? '30-60 minutes';
    final safety = _analysisResult?['safety'] as List<dynamic>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Difficulty and Time Info
          Container(
            margin: const EdgeInsets.only(bottom: 20),
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Difficulty',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        difficulty,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Time',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        estimatedTime,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Safety Precautions
          if (safety.isNotEmpty) ...[
            Text(
              'Safety Precautions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Safety Notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...safety.map((precaution) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            _cleanText(precaution.toString()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
          
          // Required Tools
          if (tools.isNotEmpty) ...[
            Text(
              'Required Tools',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.only(bottom: 20),
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
                  ...tools.map((tool) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _cleanText(tool.toString()),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
          
          // Step-by-Step Solution
          Text(
            'Step-by-Step Fix',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...solution.asMap().entries.map((entry) {
            final index = entry.key;
            final step = _cleanText(entry.value.toString());
            return _buildStepCard(
              '${index + 1}',
              step.length > 50 ? step.substring(0, 50) + '...' : step,
              step,
              Icons.build,
              Colors.blue,
            );
          }).toList(),
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final rating = await showDialog<int>(
                  context: context,
                  builder: (dialogContext) {
                    int selected = 5;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          title: const Text('How well did this fix work?'),
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
                    '/api/users/mark-fixed',
                    body: {'rating': rating},
                    authenticated: true,
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thanks! Your fix was marked as completed.')),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit rating: $error')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Mark as Fixed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step, String title, String description, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            icon,
            color: color,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Video Tutorials',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingVideos) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (_videoError != null) ...[
            Text(
              'Could not load videos: $_videoError',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ] else if (_videoGuides.isEmpty) ...[
            const Text(
              'No video guides found for this problem yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ] else ...[
            ..._videoGuides.map((video) {
              final title = video['title']?.toString() ?? 'Video tutorial';
              final channel = video['channel']?.toString() ?? 'YouTube';
              final duration = video['duration']?.toString() ?? '';
              final url = video['url']?.toString() ?? '';
              return _buildVideoCard(
                title,
                channel,
                duration,
                '4.7',
                url,
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoCard(String title, String channel, String duration, String rating, String url) {
    return InkWell(
      onTap: () => _openVideo(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            // Video thumbnail
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
                image: url.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(
                          // Derive thumbnail URL from videoGuides when available; fallback to YouTube thumbnail pattern
                          'https://i.ytimg.com/vi/${Uri.parse(url).queryParameters['v']}/hqdefault.jpg',
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        channel,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}
