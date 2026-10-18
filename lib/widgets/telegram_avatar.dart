import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../screens/photo_view_screen.dart';

class TelegramAvatar extends StatelessWidget {
  final String? imageOrEmoji;
  final String name;
  final double radius;
  final bool enableViewer;
  final VoidCallback? onTap;

  const TelegramAvatar({
    super.key,
    this.imageOrEmoji,
    required this.name,
    this.radius = 24,
    this.enableViewer = false,
    this.onTap,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFFFF512F), Color(0xFFDD2476)], // Red / Pink
    [Color(0xFF8A2387), Color(0xFFE94057)], // Purple / Red
    [Color(0xFF2193b0), Color(0xFF6dd5ed)], // Blue / Cyan
    [Color(0xFF11998e), Color(0xFF38ef7d)], // Green
    [Color(0xFFFC4A1A), Color(0xFFF7B733)], // Orange / Yellow
    [Color(0xFF7F00FF), Color(0xFFE100FF)], // Violet / Magenta
    [Color(0xFF2AABEE), Color(0xFF229ED9)], // Telegram Blue
  ];

  List<Color> _getGradient(String text) {
    if (text.isEmpty) return _gradients[6];
    final hash = text.codeUnits.fold(0, (a, b) => a + b);
    return _gradients[hash % _gradients.length];
  }

  String _getInitials(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'T';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final f = parts[0].isNotEmpty ? parts[0][0] : '';
      final l = parts[1].isNotEmpty ? parts[1][0] : '';
      return (f + l).toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  Uint8List? _getBytes(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('data:image') && !raw.startsWith('/9j/') && !raw.startsWith('iVBOR')) {
      return null;
    }
    try {
      String clean = raw;
      if (clean.contains(',')) {
        clean = clean.split(',')[1];
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNet = imageOrEmoji != null && imageOrEmoji!.startsWith('http');
    final bytes = _getBytes(imageOrEmoji);
    final hasImage = bytes != null || isNet;
    final isEmoji = imageOrEmoji != null && imageOrEmoji!.runes.length <= 2 && !hasImage;

    final grad = _getGradient(name);
    final heroTag = 'avatar_${name}_${identityHashCode(this)}';

    Widget avatarContent;

    if (bytes != null) {
      avatarContent = ClipOval(
        child: Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else if (isNet) {
      avatarContent = ClipOval(
        child: Image.network(
          imageOrEmoji!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackContent(grad),
        ),
      );
    } else if (isEmoji) {
      avatarContent = Center(
        child: Text(
          imageOrEmoji!,
          style: TextStyle(fontSize: radius * 0.95),
        ),
      );
    } else {
      avatarContent = _fallbackContent(grad);
    }

    final avatarBox = Hero(
      tag: heroTag,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: grad,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: avatarContent,
      ),
    );

    if (enableViewer || onTap != null) {
      return GestureDetector(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else if (hasImage) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoViewScreen(
                  imageSource: isNet ? imageOrEmoji : null,
                  imageBytes: bytes,
                  title: name,
                  subtitle: 'Profile Photo',
                  heroTag: heroTag,
                ),
              ),
            );
          } else {
            // View initials avatar full screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoViewScreen(
                  title: name,
                  subtitle: 'Profile Photo',
                  heroTag: heroTag,
                ),
              ),
            );
          }
        },
        child: avatarBox,
      );
    }

    return avatarBox;
  }

  Widget _fallbackContent(List<Color> grad) {
    return Center(
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
