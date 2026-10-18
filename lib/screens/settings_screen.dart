import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telegram_service.dart';
import '../theme/telegram_theme.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final service = Provider.of<TelegramService>(context, listen: false);
    _urlController.text = service.serverUrl;
    _nameController.text = service.currentUser.username;
    _bioController.text = service.currentUser.bio ?? '';
  }

  void _showEditProfileDialog() {
    final service = Provider.of<TelegramService>(context, listen: false);
    String selectedAvatar = service.currentUser.avatar;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final avatars = ['👨‍🚀', '👩‍💻', '🧙‍♂️', '🤖', '🦊', '⚡', '🛡️', '👾', '👑', '🔥'];
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: avatars.map((a) {
                        final isSel = a == selectedAvatar;
                        return GestureDetector(
                          onTap: () => setDlgState(() => selectedAvatar = a),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? TelegramTheme.primaryBlue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(a, style: const TextStyle(fontSize: 28)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    service.updateProfile(
                      username: _nameController.text.trim().isNotEmpty
                          ? _nameController.text.trim()
                          : 'Telegram User',
                      avatar: selectedAvatar,
                      bio: _bioController.text.trim(),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tgService = Provider.of<TelegramService>(context);
    final user = tgService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            color: isDark ? TelegramTheme.darkSurface : Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: TelegramTheme.primaryBlue.withValues(alpha: 0.2),
                  child: Text(user.avatar, style: const TextStyle(fontSize: 36)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.phoneNumber ?? '+1 888 777 5555',
                        style: TextStyle(
                          color: isDark ? TelegramTheme.darkSubtext : Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.bio ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: TelegramTheme.primaryBlue),
                  onPressed: _showEditProfileDialog,
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Telegram MTProto Account Section
          _sectionHeader('TELEGRAM ACCOUNT'),
          Container(
            color: isDark ? TelegramTheme.darkSurface : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (tgService.isTgAccountLinked ? Colors.green : TelegramTheme.primaryBlue)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tgService.isTgAccountLinked ? Icons.verified : Icons.phone_iphone,
                  color: tgService.isTgAccountLinked ? Colors.green : TelegramTheme.primaryBlue,
                  size: 24,
                ),
              ),
              title: Text(
                tgService.isTgAccountLinked ? 'Real Telegram Account' : 'Link Telegram Account',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                tgService.isTgAccountLinked
                    ? 'Connected: ${tgService.currentUser.phoneNumber ?? ''} (${tgService.currentUser.username})'
                    : 'Tap to enter phone number and link account',
                style: TextStyle(
                  color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TelegramAuthScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Backend Connection Section
          _sectionHeader('BACKEND SERVER & WEBSOCKET'),
          Container(
            color: isDark ? TelegramTheme.darkSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tgService.status == ConnectionStatus.connected
                            ? Colors.green
                            : (tgService.status == ConnectionStatus.connecting
                                ? Colors.orange
                                : Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tgService.status == ConnectionStatus.connected
                          ? 'Connected to Live Server'
                          : (tgService.status == ConnectionStatus.connecting
                              ? 'Connecting...'
                              : 'Offline (Local Demo Mode)'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'WebSocket URL',
                    hintText: 'ws://10.0.2.2:3000 or wss://...',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TelegramTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Connect / Save URL'),
                      onPressed: () {
                        tgService.setServerUrl(_urlController.text.trim());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reconnecting to server...')),
                        );
                      },
                    ),
                    OutlinedButton(
                      child: const Text('Localhost'),
                      onPressed: () {
                        _urlController.text = 'ws://localhost:3000';
                        tgService.setServerUrl('ws://localhost:3000');
                      },
                    ),
                    OutlinedButton(
                      child: const Text('Emulator'),
                      onPressed: () {
                        _urlController.text = 'ws://10.0.2.2:3000';
                        tgService.setServerUrl('ws://10.0.2.2:3000');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Telegram Features
          _sectionHeader('SETTINGS'),
          Container(
            color: isDark ? TelegramTheme.darkSurface : Colors.white,
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications and Sounds',
                  subtitle: 'Enabled',
                ),
                _settingTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy and Security',
                  subtitle: 'Passcode, Two-Step Verification',
                ),
                _settingTile(
                  icon: Icons.storage_outlined,
                  title: 'Data and Storage',
                  subtitle: 'Network usage, Auto-download',
                ),
                _settingTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat Settings',
                  subtitle: 'Theme, Text Size, Emoji',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              'Telegram for Mobile\nFlutter 3.32 • Native Dart Client',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? TelegramTheme.darkSubtext : Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: TelegramTheme.primaryBlue,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {},
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
