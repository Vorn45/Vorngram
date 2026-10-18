import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/telegram_theme.dart';

class VoiceNotePlayer extends StatefulWidget {
  final String? audioSource;
  final bool isOut;
  final bool isDark;

  const VoiceNotePlayer({
    super.key,
    this.audioSource,
    required this.isOut,
    required this.isDark,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  int _currentSeconds = 0;
  final int _totalSeconds = 18;
  Timer? _playbackTimer;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _waveController.repeat(reverse: true);
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_currentSeconds < _totalSeconds) {
            _currentSeconds++;
          } else {
            _isPlaying = false;
            _currentSeconds = 0;
            _waveController.stop();
            timer.cancel();
          }
        });
      });
    } else {
      _waveController.stop();
      _playbackTimer?.cancel();
    }
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isOut ? Colors.white : TelegramTheme.primaryBlue;
    final inactiveColor = widget.isOut ? Colors.white38 : Colors.grey.shade400;
    final metaColor = widget.isOut ? Colors.white70 : (widget.isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 19,
              backgroundColor: activeColor,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isOut ? (widget.isDark ? const Color(0xFF1B2734) : TelegramTheme.primaryBlue) : Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(20, (i) {
                        final waveHeights = [8, 14, 20, 10, 16, 24, 18, 12, 22, 16, 26, 14, 18, 12, 20, 14, 10, 16, 12, 8];
                        final rawHeight = waveHeights[i % waveHeights.length].toDouble();
                        final dynamicHeight = _isPlaying
                            ? (rawHeight * (0.6 + 0.4 * ((i + _waveController.value * 5) % 2))).clamp(4.0, 26.0)
                            : rawHeight;

                        final progress = _currentSeconds / _totalSeconds;
                        final isPassed = (i / 20.0) <= progress;

                        return Container(
                          width: 3,
                          height: dynamicHeight,
                          decoration: BoxDecoration(
                            color: isPassed ? activeColor : inactiveColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying
                          ? '${_formatTime(_currentSeconds)} / ${_formatTime(_totalSeconds)}'
                          : _formatTime(_totalSeconds),
                      style: TextStyle(color: metaColor, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    if (_isPlaying)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Playing',
                          style: TextStyle(color: activeColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _playbackTimer?.cancel();
    super.dispose();
  }
}
