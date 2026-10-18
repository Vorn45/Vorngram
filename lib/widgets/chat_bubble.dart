import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../theme/telegram_theme.dart';
import '../screens/photo_view_screen.dart';
import 'telegram_avatar.dart';
import 'voice_note_player.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final VoidCallback? onLongPress;
  final Function(String emoji)? onReactionSelected;
  final String? peerAvatar;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isDark,
    this.onLongPress,
    this.onReactionSelected,
    this.peerAvatar,
  });

  Color _getSenderColor(String name) {
    final colors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.amber,
      Colors.greenAccent,
      Colors.cyanAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];
    final code = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[code % colors.length];
  }

  void _showReactionSheet(BuildContext context) {
    final emojis = ['❤️', '👍', '🔥', '🎉', '😂', '👏', '🚀', '💯'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? TelegramTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((e) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  onReactionSelected?.call(e);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    e,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.black38 : Colors.black12,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final isOut = message.isOutgoing;
    final bubbleColor = isOut
        ? (isDark ? TelegramTheme.darkOutMessage : TelegramTheme.lightOutMessage)
        : (isDark ? TelegramTheme.darkInMessage : TelegramTheme.lightInMessage);

    final textColor = isOut
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white : Colors.black87);

    final metaColor = isOut
        ? (isDark ? Colors.white60 : Colors.black45)
        : (isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisAlignment: isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOut) ...[
            TelegramAvatar(
              name: message.senderName,
              imageOrEmoji: (message.avatar.isNotEmpty && message.avatar != '👤')
                  ? message.avatar
                  : ((peerAvatar != null && peerAvatar!.isNotEmpty && peerAvatar != '👤') ? peerAvatar! : message.avatar),
              radius: 16,
              enableViewer: true,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                _showReactionSheet(context);
                onLongPress?.call();
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isOut ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isOut ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender Name for Incoming
                    if (!isOut) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              color: _getSenderColor(message.senderName),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (message.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: TelegramTheme.primaryBlue, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],

                    // Photo / Picture Media
                    if (message.media != null && message.media!.isNotEmpty) ...[
                      _buildMediaPreview(context),
                      const SizedBox(height: 6),
                    ],

                    // Voice Note UI
                    if (message.voiceNote != null) ...[
                      VoiceNotePlayer(
                        audioSource: message.voiceNote,
                        isOut: isOut,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Text Content
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),

                    // Timestamp and Status
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Spacer(),
                        Text(
                          message.timestamp,
                          style: TextStyle(
                            color: metaColor,
                            fontSize: 11,
                          ),
                        ),
                        if (isOut) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all,
                            size: 14,
                            color: isDark ? TelegramTheme.primaryBlue : Colors.blueAccent,
                          ),
                        ],
                      ],
                    ),

                    // Reaction Chips
                    if (message.reactions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: message.reactions.map((r) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.white54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(r, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context) {
    final mediaStr = message.media!;
    final isNet = mediaStr.startsWith('http');
    Uint8List? bytes;
    if (!isNet) {
      try {
        String clean = mediaStr;
        if (clean.contains(',')) clean = clean.split(',')[1];
        bytes = base64Decode(clean);
      } catch (_) {}
    }

    final heroTag = 'media_${message.id}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewScreen(
              imageSource: isNet ? mediaStr : null,
              imageBytes: bytes,
              title: message.senderName,
              subtitle: message.timestamp,
              heroTag: heroTag,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Hero(
          tag: heroTag,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 260,
              maxWidth: 320,
            ),
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                  )
                : (isNet
                    ? Image.network(
                        mediaStr,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 140,
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54, size: 36),
                          ),
                        ),
                      )
                    : Container(
                        height: 140,
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.white54, size: 36),
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}
