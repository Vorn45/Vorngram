import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../services/telegram_service.dart';
import '../theme/telegram_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/telegram_avatar.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final isComp = _textController.text.trim().isNotEmpty;
      if (isComp != _isComposing) {
        setState(() {
          _isComposing = isComp;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final tgService = Provider.of<TelegramService>(context, listen: false);
    tgService.sendMessage(
      roomId: widget.room.id,
      text: text,
    );

    _textController.clear();
    setState(() {
      _isComposing = false;
      _showEmojiPicker = false;
    });

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _handleSendVoiceNote() {
    final tgService = Provider.of<TelegramService>(context, listen: false);
    tgService.sendMessage(
      roomId: widget.room.id,
      text: '',
      voiceNote: 'voice_${DateTime.now().millisecondsSinceEpoch}.ogg',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎤 Voice note sent!'),
        duration: Duration(seconds: 1),
      ),
    );
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _openAttachmentSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? TelegramTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attachmentItem(
                    icon: Icons.photo_library,
                    color: Colors.blue,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendMockMedia('📷 Photo shared');
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.camera_alt,
                    color: Colors.redAccent,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendMockMedia('📸 Snapshot taken');
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.insert_drive_file,
                    color: Colors.amber.shade700,
                    label: 'File',
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendMockMedia('📄 Document.pdf (2.4 MB)');
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.location_on,
                    color: Colors.green,
                    label: 'Location',
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendMockMedia('📍 Live Location Shared');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _sendMockMedia(String label) {
    final tgService = Provider.of<TelegramService>(context, listen: false);
    tgService.sendMessage(
      roomId: widget.room.id,
      text: label,
    );
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Widget _attachmentItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tgService = Provider.of<TelegramService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = tgService.getMessages(widget.room.id);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            TelegramAvatar(
              name: widget.room.name,
              imageOrEmoji: widget.room.avatar,
              radius: 19,
              enableViewer: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.room.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.room.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: Colors.white),
                      ],
                    ],
                  ),
                  Text(
                    widget.room.isChannel
                        ? '${widget.room.onlineCount} subscribers'
                        : (widget.room.isBot
                            ? 'bot'
                            : '${widget.room.onlineCount} members, online'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? TelegramTheme.darkSubtext : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Voice Call',
            onPressed: () {
              tgService.startCall(widget.room.name, isVideo: false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    peerName: widget.room.name,
                    peerAvatar: widget.room.avatar,
                    isVideo: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video Call',
            onPressed: () {
              tgService.startCall(widget.room.name, isVideo: true);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    peerName: widget.room.name,
                    peerAvatar: widget.room.avatar,
                    isVideo: true,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'search', child: Text('Search')),
              const PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
              const PopupMenuItem(value: 'clear', child: Text('Clear history')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? TelegramTheme.darkChatBg : TelegramTheme.lightChatBg,
        ),
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet.\nSay hello! 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? TelegramTheme.darkSubtext : Colors.grey.shade600,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (ctx, index) {
                        final msg = messages[index];
                        return ChatBubble(
                          message: msg,
                          isDark: isDark,
                          peerAvatar: widget.room.avatar,
                          onReactionSelected: (emoji) {
                            tgService.addReaction(widget.room.id, msg.id, emoji);
                          },
                        );
                      },
                    ),
            ),

            // Emoji Tray (optional expandable)
            if (_showEmojiPicker)
              Container(
                height: 180,
                color: isDark ? TelegramTheme.darkSurface : Colors.white,
                padding: const EdgeInsets.all(8),
                child: GridView.count(
                  crossAxisCount: 7,
                  children: [
                    '😀', '😂', '😍', '🔥', '🚀', '❤️', '👍',
                    '😎', '🎉', '👏', '🤖', '✨', '⚡', '💯',
                    '💎', '🙌', '🤩', '🎯', '🥳', '💪', '🤝',
                  ].map((e) {
                    return InkWell(
                      onTap: () {
                        _textController.text += e;
                        _textController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _textController.text.length),
                        );
                      },
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: isDark ? TelegramTheme.darkSurface : Colors.white,
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showEmojiPicker ? Icons.keyboard : Icons.sentiment_satisfied_alt,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
                      },
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? TelegramTheme.darkCard : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onPressed: _openAttachmentSheet,
                    ),
                    _isComposing
                        ? CircleAvatar(
                            radius: 20,
                            backgroundColor: TelegramTheme.primaryBlue,
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white, size: 18),
                              onPressed: _handleSendMessage,
                            ),
                          )
                        : CircleAvatar(
                            radius: 20,
                            backgroundColor: TelegramTheme.primaryBlue,
                            child: IconButton(
                              icon: const Icon(Icons.mic, color: Colors.white, size: 20),
                              onPressed: _handleSendVoiceNote,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
