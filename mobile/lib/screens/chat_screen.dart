import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api.dart';
import '../main.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isDriver;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isDriver,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _driverName;
  String? _jobId;
  String? _orderId;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  final _quickReplies = [
    "I'm here",
    "On my way",
    "5 minutes away",
    "Can you come to me?",
    "I'm at the pickup point",
  ];

  final _driverReplies = [
    "I'm on my way to you!",
    "I'll be there in about 2 minutes",
    "I can see the location, coming now",
    "Please look for a green Bajaj Boxer",
    "I'm wearing a helmet, standing by the bike",
    "Okay, no problem!",
    "Got it!",
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _jobId == null && _orderId == null) {
      _driverName = args['driverName'];
      _jobId = args['jobId'];
      _orderId = args['orderId'];
      _connectWebSocket();
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final messages = await Api.getChatHistory(jobId: _jobId, orderId: _orderId);
      if (mounted && messages.isNotEmpty) {
        setState(() {
          for (final m in messages) {
            _messages.add(ChatMessage(
              id: m['id'].toString(),
              text: m['message'] ?? '',
              isDriver: m['sender_type'] == 'driver',
              timestamp: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
            ));
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
    if (_messages.isEmpty) {
      _addDriverMessage("Hi! I'm on my way to pick you up. Let me know if you have any questions.");
    }
  }

  void _connectWebSocket() {
    final roomId = _jobId ?? _orderId;
    if (roomId == null) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(Api.wsChatRoom(roomId)));
      _wsSub = _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data);
            if (parsed['type'] == 'chat' && parsed['message'] != null) {
              final msg = parsed['message'];
              if (msg['sender_type'] == 'driver' && mounted) {
                setState(() {
                  _messages.add(ChatMessage(
                    id: msg['id'].toString(),
                    text: msg['message'] ?? '',
                    isDriver: true,
                    timestamp: DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now(),
                  ));
                });
                _scrollToBottom();
              }
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _addDriverMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isDriver: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text.trim(),
        isDriver: false,
        timestamp: DateTime.now(),
      ));
    });
    _messageController.clear();
    _scrollToBottom();

    // Persist via API
    try {
      await Api.sendChatMessage(
        jobId: _jobId,
        orderId: _orderId,
        message: text.trim(),
        senderType: 'rider',
      );
    } catch (_) {}

    // Mock driver reply if no real WebSocket is connected
    setState(() => _isTyping = true);
    Timer(Duration(milliseconds: 800 + (text.length * 20)), () {
      if (mounted) {
        setState(() => _isTyping = false);
        final reply = _driverReplies[DateTime.now().millisecond % _driverReplies.length];
        _addDriverMessage(reply);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FambaColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: FambaColors.primary.withOpacity(0.2),
              child: Text(
                (_driverName ?? 'D')[0].toUpperCase(),
                style: const TextStyle(
                  color: FambaColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName ?? 'Driver',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: FambaColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: FambaColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isTyping ? 'Typing...' : 'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isTyping ? FambaColors.primary : Colors.grey.shade500,
                        fontWeight: _isTyping ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calling driver (simulated)'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FambaColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.call_rounded,
                color: FambaColors.primary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _typingIndicator();
                }
                return _messageBubble(_messages[index]);
              },
            ),
          ),

          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickReplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _quickReplyChip(_quickReplies[index]);
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FambaColors.background,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(_messageController.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: FambaColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: FambaColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(ChatMessage message) {
    final isDriver = message.isDriver;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isDriver ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isDriver) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: FambaColors.primary.withOpacity(0.2),
              child: Text(
                (_driverName ?? 'D')[0].toUpperCase(),
                style: const TextStyle(
                  color: FambaColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDriver ? Colors.white : FambaColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isDriver ? 4 : 18),
                  bottomRight: Radius.circular(isDriver ? 18 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isDriver ? FambaColors.textPrimary : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isDriver
                              ? Colors.grey.shade500
                              : Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                      if (!isDriver) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isDriver) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: FambaColors.primary.withOpacity(0.2),
            child: Text(
              (_driverName ?? 'D')[0].toUpperCase(),
              style: const TextStyle(
                color: FambaColors.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _typingDot(0),
                const SizedBox(width: 4),
                _typingDot(1),
                const SizedBox(width: 4),
                _typingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = ((value + delay) % 1);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: FambaColors.primary.withOpacity(0.3 + (animValue * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _quickReplyChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FambaColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: FambaColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
