import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telegram_service.dart';
import '../theme/telegram_theme.dart';
import 'telegram_avatar.dart';
import '../screens/settings_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/auth_screen.dart';

class TelegramDrawer extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const TelegramDrawer({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final tgService = Provider.of<TelegramService>(context);
    final user = tgService.currentUser;

    return Drawer(
      backgroundColor: isDarkMode ? TelegramTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          // User Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: isDarkMode ? TelegramTheme.darkCard : TelegramTheme.primaryBlue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TelegramAvatar(
                      name: user.username,
                      imageOrEmoji: user.avatar,
                      radius: 32,
                      enableViewer: true,
                    ),
                    IconButton(
                      icon: Icon(
                        isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                        color: Colors.white,
                      ),
                      onPressed: onToggleTheme,
                      tooltip: 'Toggle Theme',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TelegramAuthScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (tgService.isTgAccountLinked) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 16, color: Colors.white),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tgService.isTgAccountLinked
                                  ? (user.phoneNumber ?? '')
                                  : 'Tap to Link Telegram Account',
                              style: TextStyle(
                                color: tgService.isTgAccountLinked ? Colors.white70 : Colors.amberAccent,
                                fontSize: 13,
                                fontWeight: tgService.isTgAccountLinked ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_right, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(
                  icon: tgService.isTgAccountLinked ? Icons.verified_user : Icons.phone_iphone,
                  title: tgService.isTgAccountLinked ? 'My Telegram Account' : 'Link Phone & Account',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TelegramAuthScreen()),
                    );
                  },
                ),
                _drawerTile(
                  icon: Icons.group_outlined,
                  title: 'New Group',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Create Group feature')),
                    );
                  },
                ),
                _drawerTile(
                  icon: Icons.person_outline,
                  title: 'Contacts',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _drawerTile(
                  icon: Icons.call_outlined,
                  title: 'Calls',
                  onTap: () {
                    Navigator.pop(context);
                    tgService.startCall('Sarah Jenkins');
                  },
                ),
                _drawerTile(
                  icon: Icons.bookmark_border,
                  title: 'Saved Messages',
                  onTap: () {
                    Navigator.pop(context);
                    final savedRoom = tgService.rooms.firstWhere(
                      (r) => r.id == 'saved-messages',
                      orElse: () => tgService.rooms.first,
                    );
                    tgService.selectRoom(savedRoom.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(room: savedRoom),
                      ),
                    );
                  },
                ),
                _drawerTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _drawerTile(
                  icon: Icons.person_add_outlined,
                  title: 'Invite Friends',
                  onTap: () => Navigator.pop(context),
                ),
                _drawerTile(
                  icon: Icons.help_outline,
                  title: 'Telegram Features',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Server Connection Indicator at Bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDarkMode ? Colors.black26 : Colors.grey.shade100,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
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
                Expanded(
                  child: Text(
                    tgService.status == ConnectionStatus.connected
                        ? 'Backend Connected'
                        : (tgService.status == ConnectionStatus.connecting
                            ? 'Connecting Server...'
                            : 'Offline (Demo Mode)'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  child: const Text(
                    'Setup',
                    style: TextStyle(
                      color: TelegramTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600, size: 24),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
