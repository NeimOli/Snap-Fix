import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';

class JobChatScreen extends StatefulWidget {
  const JobChatScreen({super.key});

  @override
  State<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<JobChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  late String _jobId;
  String? _title;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    final extra = state.extra;
    if (extra is Map<String, dynamic>) {
      _jobId = extra['jobId']?.toString() ?? '';
      final providerName = extra['providerName']?.toString();
      _title = providerName != null && providerName.isNotEmpty ? providerName : 'Job Chat';
    } else {
      _jobId = '';
      _title = 'Job Chat';
    }

    if (_jobId.isNotEmpty && _isLoading) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.get(
        '/api/jobs/$_jobId/messages',
        authenticated: true,
      );
      final list = (response['messages'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as Map<String, dynamic>))
          .toList();
      setState(() {
        _messages = list;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending || _jobId.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final response = await ApiClient.instance.post(
        '/api/jobs/$_jobId/messages',
        body: {'text': text},
        authenticated: true,
      );
      final message = (response['message'] as Map<String, dynamic>);
      setState(() {
        _messages.add(message);
        _controller.clear();
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? 'Job Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final text = message['text']?.toString() ?? '';
                          final fromRole = message['fromRole']?.toString();
                          final isUserRole = fromRole == 'user';
                          final senderLabel = isUserRole ? 'User' : 'Provider';

                          final avatar = CircleAvatar(
                            radius: 16,
                            backgroundColor: isUserRole
                                ? theme.colorScheme.primary.withOpacity(0.15)
                                : theme.colorScheme.secondary.withOpacity(0.15),
                            child: Text(
                              senderLabel.isNotEmpty ? senderLabel[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isUserRole
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.secondary,
                              ),
                            ),
                          );

                          final bubble = Column(
                            crossAxisAlignment:
                                isUserRole ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isUserRole
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isUserRole
                                        ? Colors.white
                                        : theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                            ],
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: isUserRole
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isUserRole) ...[
                                  avatar,
                                  const SizedBox(width: 8),
                                  Flexible(child: bubble),
                                ] else ...[
                                  Flexible(child: bubble),
                                  const SizedBox(width: 8),
                                  avatar,
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
