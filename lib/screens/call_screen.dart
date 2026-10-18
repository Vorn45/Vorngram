import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telegram_service.dart';
import '../theme/telegram_theme.dart';
import '../widgets/telegram_avatar.dart';

class CallScreen extends StatefulWidget {
  final String peerName;
  final String peerAvatar;
  final bool isVideo;

  const CallScreen({
    super.key,
    required this.peerName,
    required this.peerAvatar,
    this.isVideo = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _callTimer;
  int _seconds = 0;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Simulate connection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _seconds++;
            });
          }
        });
      }
    });
  }

  String _formatDuration(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tgService = Provider.of<TelegramService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF101921),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Telegram Encryption Key Emojis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      tgService.endCall();
                      Navigator.pop(context);
                    },
                  ),
                  // Telegram signature 4-emoji verification keys
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🦊', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 4),
                        Text('⚡', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 4),
                        Text('🎸', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 4),
                        Text('💎', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched Camera')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Peer Info
            Text(
              widget.peerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConnected
                  ? _formatDuration(_seconds)
                  : (widget.isVideo ? 'Telegram Video Calling...' : 'Telegram Calling...'),
              style: TextStyle(
                color: _isConnected ? Colors.white70 : TelegramTheme.primaryBlue,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 12, color: Colors.white54),
                SizedBox(width: 4),
                Text(
                  'End-to-end encrypted',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),

            const Spacer(),

            // Video Preview or Avatar Pulse Animation
            if (widget.isVideo)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2734),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TelegramTheme.primaryBlue.withValues(alpha: 0.4), width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: TelegramAvatar(
                        name: widget.peerName,
                        imageOrEmoji: widget.peerAvatar,
                        radius: 54,
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('HD 60 FPS', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              )
            else
              AnimatedBuilder(
                animation: _animController,
                builder: (ctx, child) {
                  return Container(
                    width: 140 + (_animController.value * 24),
                    height: 140 + (_animController.value * 24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TelegramTheme.primaryBlue.withValues(alpha: 0.15 * (1 - _animController.value)),
                    ),
                    child: Center(
                      child: TelegramAvatar(
                        name: widget.peerName,
                        imageOrEmoji: widget.peerAvatar,
                        radius: 54,
                      ),
                    ),
                  );
                },
              ),

            const Spacer(),

            // Call Actions Control Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF17212B),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Mute Button
                  IconButton(
                    icon: Icon(
                      tgService.isCallMuted ? Icons.mic_off : Icons.mic,
                      color: tgService.isCallMuted ? Colors.redAccent : Colors.white,
                      size: 28,
                    ),
                    onPressed: () => tgService.toggleMute(),
                  ),
                  // Video Toggle
                  IconButton(
                    icon: Icon(
                      widget.isVideo ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Video toggled')),
                      );
                    },
                  ),
                  // Speaker
                  IconButton(
                    icon: Icon(
                      tgService.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      color: tgService.isSpeakerOn ? TelegramTheme.primaryBlue : Colors.white,
                      size: 28,
                    ),
                    onPressed: () => tgService.toggleSpeaker(),
                  ),
                  // End Call Button
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.redAccent,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.white, size: 28),
                      onPressed: () {
                        tgService.endCall();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }
}
