import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../services/telegram_service.dart';
import '../theme/telegram_theme.dart';
import '../widgets/telegram_drawer.dart';
import '../widgets/telegram_avatar.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = ['All', 'Channels', 'Bots', 'Groups'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  List<ChatRoom> _filterRooms(List<ChatRoom> rooms, int tabIndex, String query) {
    var filtered = rooms;
    if (tabIndex == 1) {
      filtered = rooms.where((r) => r.isChannel).toList();
    } else if (tabIndex == 2) {
      filtered = rooms.where((r) => r.isBot).toList();
    } else if (tabIndex == 3) {
      filtered = rooms.where((r) => !r.isChannel && !r.isBot && r.id != 'saved-messages').toList();
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((r) =>
          r.name.toLowerCase().contains(query.toLowerCase()) ||
          r.lastMessage.toLowerCase().contains(query.toLowerCase())).toList();
    }
    return filtered;
  }

  void _showNewChatDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Message'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Username or Channel',
              hintText: '@username',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = titleController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  final tempRoom = ChatRoom(
                    id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    avatar: '👤',
                    description: 'Direct message',
                    lastMessage: 'Tap to start conversation',
                    lastTime: 'Now',
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(room: tempRoom),
                    ),
                  );
                }
              },
              child: const Text('Start Chat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tgService = Provider.of<TelegramService>(context);
    final isDark = widget.isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      drawer: TelegramDrawer(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Search chats, channels...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : Row(
                children: [
                  const Text('Telegram'),
                  const SizedBox(width: 8),
                  if (tgService.status != ConnectionStatus.connected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tgService.status == ConnectionStatus.connecting
                            ? Colors.orange.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tgService.status == ConnectionStatus.connecting ? 'Connecting...' : 'Offline Demo',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          onTap: (_) => setState(() {}),
        ),
      ),
      body: Column(
        children: [
          if (!tgService.isTgAccountLinked)
            _buildLinkAccountBanner(context, isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.asMap().entries.map((entry) {
                final tabIndex = entry.key;
                final rooms = _filterRooms(tgService.rooms, tabIndex, _searchController.text.trim());

                if (rooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: isDark ? TelegramTheme.darkSubtext : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No chats found',
                          style: TextStyle(
                            color: isDark ? TelegramTheme.darkSubtext : Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (ctx, i) => Divider(
                    height: 1,
                    indent: 72,
                    color: isDark ? TelegramTheme.darkDivider : TelegramTheme.lightDivider,
                  ),
                  itemBuilder: (ctx, index) {
                    final room = rooms[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Stack(
                        children: [
                          TelegramAvatar(
                            name: room.name,
                            imageOrEmoji: room.avatar,
                            radius: 26,
                          ),
                          if (room.isPinned)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: TelegramTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.push_pin, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (room.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 15, color: TelegramTheme.primaryBlue),
                          ],
                          if (room.isBot) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('BOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          room.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            room.lastTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (room.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: TelegramTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                room.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (room.isPinned)
                            const Icon(Icons.push_pin, size: 16, color: Colors.grey)
                          else
                            const SizedBox(height: 16),
                        ],
                      ),
                      onTap: () {
                        tgService.selectRoom(room.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(room: room),
                          ),
                        );
                      },
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        tooltip: 'New Message',
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildLinkAccountBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TelegramTheme.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.08),
        border: Border(
          bottom: BorderSide(
            color: TelegramTheme.primaryBlue.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TelegramTheme.primaryBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_iphone, color: TelegramTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link Telegram Account',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Verify phone number to sync your chats',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TelegramTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelegramAuthScreen()),
              );
            },
            child: const Text('Link Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
