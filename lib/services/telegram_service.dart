import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat_model.dart';
import 'tdlib_service.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class TelegramService extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  String _serverUrl = 'ws://10.0.2.2:3000'; // Default for Android Emulator
  String get serverUrl => _serverUrl;

  // Direct Native TDLib Mode (Zero Servers Needed)
  bool _useDirectTdLib = true;
  bool get useDirectTdLib => _useDirectTdLib;

  final TdLibService tdLib = TdLibService();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  TelegramUser _currentUser = TelegramUser(
    id: 'usr_me',
    username: 'Telegram User',
    avatar: '👨‍🚀',
    phoneNumber: '+1 888 777 5555',
    bio: 'Coding with Antigravity 🚀',
  );
  TelegramUser get currentUser => _currentUser;

  // Telegram MTProto Account Linking State
  bool _isTgAccountLinked = false;
  bool get isTgAccountLinked => _isTgAccountLinked;

  bool _isAuthLoading = false;
  bool get isAuthLoading => _isAuthLoading;

  String? _authError;
  String? get authError => _authError;

  String _authStep = 'phone'; // 'phone', 'code', '2fa', 'linked'
  String get authStep => _authStep;

  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;

  // Active Call state
  bool _isCallActive = false;
  bool get isCallActive => _isCallActive;
  String? _activeCallPeer;
  String? get activeCallPeer => _activeCallPeer;
  bool _isCallVideo = false;
  bool get isCallVideo => _isCallVideo;
  bool _isCallMuted = false;
  bool get isCallMuted => _isCallMuted;
  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  // Rooms and messages
  List<ChatRoom> _rooms = [];
  List<ChatRoom> get rooms => _rooms;

  final Map<String, List<ChatMessage>> _messages = {};
  List<ChatMessage> getMessages(String roomId) => _messages[roomId] ?? [];

  String _selectedRoomId = 'room-general';
  String get selectedRoomId => _selectedRoomId;

  TelegramService() {
    _initDefaultRooms();
    _loadPreferences();
    _initDirectTdLib();
  }

  void _initDirectTdLib() {
    tdLib.addListener(_onTdLibUpdated);
    tdLib.start();
  }

  void _onTdLibUpdated() {
    if (!_useDirectTdLib) return;

    _status = tdLib.isAuthorized ? ConnectionStatus.connected : ConnectionStatus.connecting;
    _isTgAccountLinked = tdLib.isAuthorized;
    _isAuthLoading = tdLib.isLoading;
    _authError = tdLib.errorMessage;

    if (tdLib.isAuthorized) {
      _authStep = 'linked';
      _currentUser = tdLib.currentUser;

      if (tdLib.chatRooms.isNotEmpty) {
        final existingIds = tdLib.chatRooms.map((r) => r.id).toSet();
        final combined = <ChatRoom>[...tdLib.chatRooms];
        for (final r in _rooms) {
          if (!existingIds.contains(r.id)) {
            combined.add(r);
          }
        }
        _rooms = combined;
      }
    } else {
      _authStep = tdLib.authStep;
    }
    notifyListeners();
  }

  void _initDefaultRooms() {
    _rooms = [
      ChatRoom(
        id: 'saved-messages',
        name: 'Saved Messages',
        avatar: '🔖',
        description: 'Your personal cloud storage and forward stash',
        lastMessage: 'Tap to save media, notes, or links',
        lastTime: '7:42 AM',
        isPinned: true,
      ),
      ChatRoom(
        id: 'room-durov',
        name: 'Pavel Durov',
        avatar: '✈️',
        description: 'Official Telegram Channel of Pavel Durov',
        lastMessage: 'Freedom and privacy will always prevail. 🚀',
        lastTime: '11:15 AM',
        isPinned: true,
        isChannel: true,
        isVerified: true,
        onlineCount: 950000000,
      ),
      ChatRoom(
        id: 'room-general',
        name: 'Telegram World General',
        avatar: '🌍',
        description: 'Global real-time chat with WebRTC calling',
        lastMessage: 'Welcome to the global room! Feel free to say hi.',
        lastTime: '10:00 AM',
        onlineCount: 42,
      ),
      ChatRoom(
        id: 'room-bot',
        name: 'Secret Message Bot',
        avatar: '🤖',
        description: 'Telegram Bot Bridge & Live updates',
        lastMessage: 'Live Telegram Bot Bridge is connected to @SecreteMessage123454321ceeetbot',
        lastTime: '09:30 AM',
        isBot: true,
      ),
      ChatRoom(
        id: 'room-devs',
        name: 'Flutter & WebRTC Devs',
        avatar: '💻',
        description: 'Developers building cross-platform real-time apps',
        lastMessage: 'Native Flutter app is now synced with backend server!',
        lastTime: 'Yesterday',
        onlineCount: 18,
      ),
    ];

    // Default seeded messages
    _messages['saved-messages'] = [
      ChatMessage(
        id: 'saved-1',
        senderId: _currentUser.id,
        senderName: _currentUser.username,
        avatar: _currentUser.avatar,
        text: '📌 Welcome to your Saved Messages cloud storage! You can store notes, audio, and attachments here.',
        roomId: 'saved-messages',
        timestamp: '07:42 AM',
        isOutgoing: true,
      ),
    ];

    _messages['room-durov'] = [
      ChatMessage(
        id: 'durov-1',
        senderId: 'user_durov',
        senderName: 'Pavel Durov',
        avatar: '✈️',
        text: 'Welcome to my official Telegram channel. Today we continue our mission for global privacy and free speech.',
        roomId: 'room-durov',
        timestamp: '10:00 AM',
        isVerified: true,
      ),
      ChatMessage(
        id: 'durov-2',
        senderId: 'user_durov',
        senderName: 'Pavel Durov',
        avatar: '✈️',
        text: 'Over 950 million active users rely on Telegram every month. Freedom and privacy will always prevail. 🚀',
        roomId: 'room-durov',
        timestamp: '11:15 AM',
        isVerified: true,
      ),
    ];

    _messages['room-general'] = [
      ChatMessage(
        id: 'gen-1',
        senderId: 'system',
        senderName: 'System Core',
        avatar: '🛡️',
        text: 'Welcome to Telegram World General! Real-time messaging, WebRTC Calling, and Bot bridges are active.',
        roomId: 'room-general',
        timestamp: '10:00 AM',
        isSystem: true,
      ),
      ChatMessage(
        id: 'gen-2',
        senderId: 'usr_sarah',
        senderName: 'Sarah Jenkins',
        avatar: '👩‍💻',
        text: 'Hey everyone! Testing the new Flutter mobile app client. The UI feels incredibly smooth! ✨',
        roomId: 'room-general',
        timestamp: '10:02 AM',
      ),
    ];

    _messages['room-bot'] = [
      ChatMessage(
        id: 'bot-1',
        senderId: 'bot_secret',
        senderName: 'Secret Message Bot',
        avatar: '🤖',
        text: 'Live Telegram Bot Bridge is connected to @SecreteMessage123454321ceeetbot. You can chat here or on Telegram.',
        roomId: 'room-bot',
        timestamp: '09:30 AM',
        isSystem: true,
      ),
    ];

    _messages['room-devs'] = [
      ChatMessage(
        id: 'dev-1',
        senderId: 'usr_alex',
        senderName: 'Alex River',
        avatar: '⚡',
        text: 'Flutter 3.32 with Dart 3.8 works great on mobile, desktop, and web!',
        roomId: 'room-devs',
        timestamp: 'Yesterday',
      ),
    ];
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _serverUrl = savedUrl;
      }
      final savedUsername = prefs.getString('username');
      final savedAvatar = prefs.getString('avatar');
      if (savedUsername != null && savedUsername.isNotEmpty) {
        _currentUser = TelegramUser(
          id: _currentUser.id,
          username: savedUsername,
          avatar: savedAvatar ?? _currentUser.avatar,
          phoneNumber: _currentUser.phoneNumber,
          bio: _currentUser.bio,
        );
      }
      notifyListeners();
      connect();
    } catch (e) {
      if (kDebugMode) print('Prefs load error: $e');
      connect();
    }
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', url);
    } catch (_) {}
    disconnect();
    connect();
    notifyListeners();
  }

  Future<void> updateProfile({required String username, required String avatar, String? bio}) async {
    _currentUser = TelegramUser(
      id: _currentUser.id,
      username: username,
      avatar: avatar,
      phoneNumber: _currentUser.phoneNumber,
      bio: bio ?? _currentUser.bio,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('avatar', avatar);
    } catch (_) {}

    if (_status == ConnectionStatus.connected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'set-profile',
        'username': username,
        'avatar': avatar,
      }));
    }

    notifyListeners();
  }

  void selectRoom(String roomId) {
    _selectedRoomId = roomId;
    if (_useDirectTdLib) {
      final cId = int.tryParse(roomId);
      if (cId != null) {
        tdLib.selectChat(cId);
      }
    } else if (_status == ConnectionStatus.connected && _channel != null) {
      final isRealTg = int.tryParse(roomId) != null || roomId.startsWith('-');
      if (isRealTg) {
        _channel!.sink.add(jsonEncode({
          'type': 'tg-get-messages',
          'chatId': roomId,
        }));
      } else {
        _channel!.sink.add(jsonEncode({
          'type': 'join-room',
          'roomId': roomId,
        }));
      }
    }
    notifyListeners();
  }

  void connect() {
    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) {
      return;
    }

    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final uri = Uri.parse(_serverUrl);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _onDataReceived(data);
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (err) {
          if (kDebugMode) print('WebSocket error: $err');
          _handleDisconnect();
        },
      );

      _status = ConnectionStatus.connected;
      notifyListeners();

      // Send initial profile handshake
      _channel!.sink.add(jsonEncode({
        'type': 'set-profile',
        'username': _currentUser.username,
        'avatar': _currentUser.avatar,
      }));

      // Join current room
      _channel!.sink.add(jsonEncode({
        'type': 'join-room',
        'roomId': _selectedRoomId,
      }));
    } catch (e) {
      if (kDebugMode) print('Connection exception: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _status = ConnectionStatus.disconnected;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    notifyListeners();

    // Try auto-reconnect after 5 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_status == ConnectionStatus.disconnected) {
        connect();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  void _onDataReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString());
      final type = data['type'] as String?;

      switch (type) {
        case 'init-ack':
          final isLinked = data['tgAccount'] != null && data['tgAccount']['isConnected'] == true;
          _isTgAccountLinked = isLinked;
          if (isLinked) {
            final u = data['tgAccount']['user'];
            if (u != null) {
              _currentUser = TelegramUser(
                id: u['id']?.toString() ?? _currentUser.id,
                username: u['displayName'] ?? u['username'] ?? _currentUser.username,
                avatar: '✈️',
                phoneNumber: u['phone'] != null ? '+${u['phone']}' : _currentUser.phoneNumber,
                bio: '@${u['username'] ?? 'telegram'} • Real Telegram Account',
              );
            }
            _authStep = 'linked';
          } else {
            _authStep = 'phone';
            if (data['user'] != null) {
              final u = data['user'];
              _currentUser = TelegramUser(
                id: u['id'] ?? _currentUser.id,
                username: _currentUser.username.isNotEmpty ? _currentUser.username : (u['username'] ?? 'User'),
                avatar: _currentUser.avatar.isNotEmpty ? _currentUser.avatar : (u['avatar'] ?? '👨‍🚀'),
                phoneNumber: _currentUser.phoneNumber,
                bio: _currentUser.bio,
              );
            }
          }
          if (data['history'] != null && data['history'] is List) {
            final hist = (data['history'] as List)
                .map((m) => ChatMessage.fromJson(m, currentUserId: _currentUser.id))
                .toList();
            _messages['room-general'] = hist;
          }
          notifyListeners();
          break;

        case 'tg-dialogs':
          if (data['dialogs'] != null && data['dialogs'] is List) {
            final realRooms = <ChatRoom>[];
            for (final d in (data['dialogs'] as List)) {
              final type = d['type']?.toString() ?? 'user';
              final isChannel = type == 'channel';
              final isBot = type == 'bot';
              realRooms.add(ChatRoom(
                id: d['id']?.toString() ?? '',
                name: d['name'] ?? 'Chat',
                avatar: d['avatar'] ?? (isChannel ? '📢' : (type == 'group' ? '👥' : '👤')),
                description: 'Real Telegram ${type.toUpperCase()}',
                lastMessage: d['lastMessage'] ?? '',
                lastTime: d['lastMessageTime'] ?? '',
                isPinned: d['isPinned'] ?? false,
                isChannel: isChannel,
                isBot: isBot,
                unreadCount: d['unreadCount'] ?? 0,
              ));
            }
            final realIds = realRooms.map((r) => r.id).toSet();
            for (final r in _rooms) {
              if (!realIds.contains(r.id)) {
                realRooms.add(r);
              }
            }
            _rooms = realRooms;
            notifyListeners();
          }
          break;

        case 'tg-messages':
          final chatId = data['chatId']?.toString();
          if (chatId != null && data['messages'] is List) {
            final room = _rooms.cast<ChatRoom?>().firstWhere(
              (r) => r?.id == chatId,
              orElse: () => null,
            );
            final roomAvatar = room?.avatar ?? '👤';

            final msgs = (data['messages'] as List).map((m) {
              final isOut = m['isOut'] == true;
              final msgAvatar = m['avatar'] ?? (isOut ? _currentUser.avatar : roomAvatar);
              return ChatMessage(
                id: m['id']?.toString() ?? 'tg_${DateTime.now().millisecondsSinceEpoch}',
                senderId: isOut ? _currentUser.id : (m['senderId']?.toString() ?? 'tg_user'),
                senderName: m['senderName'] ?? (isOut ? 'You' : 'Member'),
                avatar: msgAvatar,
                text: m['text'] ?? '',
                media: m['media'],
                voiceNote: m['voiceNote'],
                roomId: chatId,
                timestamp: m['timestamp'] ?? '',
                isOutgoing: isOut,
              );
            }).toList();
            _messages[chatId] = msgs;
            notifyListeners();
          }
          break;

        case 'new-message':
          if (data['message'] != null) {
            final msg = ChatMessage.fromJson(data['message'], currentUserId: _currentUser.id);
            _appendMessage(msg);
          }
          break;

        case 'room-history':
          final rId = data['roomId'] as String?;
          if (rId != null && data['history'] is List) {
            final hist = (data['history'] as List)
                .map((m) => ChatMessage.fromJson(m, currentUserId: _currentUser.id))
                .toList();
            _messages[rId] = hist;
            notifyListeners();
          }
          break;

        case 'tg-live-message':
          if (data['message'] != null) {
            final tg = data['message'];
            final chatId = tg['chatId']?.toString() ?? 'room-bot';
            final room = _rooms.cast<ChatRoom?>().firstWhere(
              (r) => r?.id == chatId,
              orElse: () => null,
            );
            final roomAvatar = room?.avatar ?? '👤';
            final isOut = tg['isOut'] == true;
            final msg = ChatMessage(
              id: tg['id'] ?? 'tg_${DateTime.now().millisecondsSinceEpoch}',
              senderId: isOut ? _currentUser.id : (tg['senderId']?.toString() ?? 'tg_user'),
              senderName: tg['senderName'] ?? (isOut ? 'You' : 'Member'),
              avatar: tg['avatar'] ?? (isOut ? _currentUser.avatar : roomAvatar),
              text: tg['text'] ?? '',
              media: tg['media'],
              voiceNote: tg['voiceNote'],
              roomId: chatId,
              timestamp: tg['timestamp'] ?? DateFormat('hh:mm a').format(DateTime.now()),
              isOutgoing: isOut,
            );
            _appendMessage(msg);
          }
        case 'tg-send-code-res':
          _isAuthLoading = false;
          if (data['success'] == true) {
            _authStep = 'code';
            _authError = null;
          } else {
            _authError = data['error'] ?? 'Failed to send login code. Please check your phone number.';
          }
          notifyListeners();
          break;

        case 'tg-verify-code-res':
          _isAuthLoading = false;
          if (data['requires2FA'] == true) {
            _authStep = '2fa';
            _authError = null;
          } else if (data['success'] == true) {
            _isTgAccountLinked = true;
            _authStep = 'linked';
            _authError = null;
            if (data['user'] != null) {
              final u = data['user'];
              _currentUser = TelegramUser(
                id: u['id']?.toString() ?? _currentUser.id,
                username: u['displayName'] ?? u['username'] ?? _currentUser.username,
                avatar: '✈️',
                phoneNumber: u['phone'] != null ? '+${u['phone']}' : _currentUser.phoneNumber,
                bio: '@${u['username'] ?? 'telegram'} • Real Telegram Account',
              );
            }
          } else {
            _authError = data['error'] ?? 'Invalid verification code. Please try again.';
          }
          notifyListeners();
          break;

        case 'tg-verify-2fa-res':
          _isAuthLoading = false;
          if (data['success'] == true) {
            _isTgAccountLinked = true;
            _authStep = 'linked';
            _authError = null;
            if (data['user'] != null) {
              final u = data['user'];
              _currentUser = TelegramUser(
                id: u['id']?.toString() ?? _currentUser.id,
                username: u['displayName'] ?? u['username'] ?? _currentUser.username,
                avatar: '✈️',
                phoneNumber: u['phone'] != null ? '+${u['phone']}' : _currentUser.phoneNumber,
                bio: '@${u['username'] ?? 'telegram'} • Real Telegram Account',
              );
            }
          } else {
            _authError = data['error'] ?? 'Incorrect 2FA password.';
          }
          notifyListeners();
          break;

        case 'tg-logout-res':
          _isTgAccountLinked = false;
          _authStep = 'phone';
          _isAuthLoading = false;
          _authError = null;
          _initDefaultRooms();
          notifyListeners();
          break;

        case 'call-incoming':
          _isCallActive = true;
          _activeCallPeer = data['fromName'] ?? 'Caller';
          _isCallVideo = data['isVideo'] ?? false;
          notifyListeners();
          break;

        case 'call-ended':
          endCall();
          break;
      }
    } catch (e) {
      if (kDebugMode) print('Failed parsing incoming WS payload: $e');
    }
  }

  void _appendMessage(ChatMessage msg) {
    if (!_messages.containsKey(msg.roomId)) {
      _messages[msg.roomId] = [];
    }
    _messages[msg.roomId]!.add(msg);

    // Update room preview
    final idx = _rooms.indexWhere((r) => r.id == msg.roomId);
    if (idx != -1) {
      final r = _rooms[idx];
      _rooms[idx] = r.copyWith(
        lastMessage: msg.text.isNotEmpty ? msg.text : (msg.voiceNote != null ? '🎤 Voice message' : '📷 Photo'),
        lastTime: msg.timestamp,
      );
    }
    notifyListeners();
  }

  void sendMessage({required String roomId, required String text, String? media, String? voiceNote}) {
    final nowTime = DateFormat('hh:mm a').format(DateTime.now());
    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUser.id,
      senderName: _currentUser.username,
      avatar: _currentUser.avatar,
      text: text,
      media: media,
      voiceNote: voiceNote,
      roomId: roomId,
      timestamp: nowTime,
      isOutgoing: true,
    );

    _appendMessage(newMsg);

    if (_useDirectTdLib) {
      final cId = int.tryParse(roomId);
      if (cId != null) {
        tdLib.sendMessage(cId, text.isNotEmpty ? text : (voiceNote != null ? '🎤 Voice message' : ''));
      }
    } else if (_status == ConnectionStatus.connected && _channel != null) {
      final isRealTg = int.tryParse(roomId) != null || roomId.startsWith('-');
      if (isRealTg) {
        _channel!.sink.add(jsonEncode({
          'type': 'tg-send-message',
          'chatId': roomId,
          'text': text.isNotEmpty ? text : (voiceNote != null ? '🎤 Voice message' : ''),
          'voiceNote': voiceNote,
        }));
      } else {
        _channel!.sink.add(jsonEncode({
          'type': 'send-message',
          'roomId': roomId,
          'text': text,
          'media': media,
          'voiceNote': voiceNote,
        }));
      }
    }
  }

  void addReaction(String roomId, String messageId, String emoji) {
    final list = _messages[roomId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final m = list[idx];
        final updated = List<String>.from(m.reactions);
        if (updated.contains(emoji)) {
          updated.remove(emoji);
        } else {
          updated.add(emoji);
        }
        list[idx] = ChatMessage(
          id: m.id,
          senderId: m.senderId,
          senderName: m.senderName,
          avatar: m.avatar,
          text: m.text,
          media: m.media,
          voiceNote: m.voiceNote,
          roomId: m.roomId,
          timestamp: m.timestamp,
          isOutgoing: m.isOutgoing,
          isSystem: m.isSystem,
          isVerified: m.isVerified,
          reactions: updated,
        );
        notifyListeners();
      }
    }
  }

  void startCall(String peerName, {bool isVideo = false}) {
    _isCallActive = true;
    _activeCallPeer = peerName;
    _isCallVideo = isVideo;
    _isCallMuted = false;
    _isSpeakerOn = false;
    notifyListeners();

    if (_status == ConnectionStatus.connected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'call-initiate',
        'target': peerName,
        'isVideo': isVideo,
      }));
    }
  }

  void toggleMute() {
    _isCallMuted = !_isCallMuted;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
  }

  void endCall() {
    _isCallActive = false;
    _activeCallPeer = null;
    notifyListeners();

    if (_status == ConnectionStatus.connected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'call-end',
      }));
    }
  }

  void resetAuthFlow() {
    _authStep = _isTgAccountLinked ? 'linked' : 'phone';
    _authError = null;
    _isAuthLoading = false;
    notifyListeners();
  }

  void setAuthStep(String step) {
    _authStep = step;
    _authError = null;
    notifyListeners();
  }

  void sendTelegramAuthCode(String phone, {String? apiId, String? apiHash}) {
    if (_useDirectTdLib) {
      _pendingPhone = phone.trim();
      _isAuthLoading = true;
      _authError = null;
      notifyListeners();
      tdLib.setPhoneNumber(_pendingPhone!);
      return;
    }

    if (_status != ConnectionStatus.connected || _channel == null) {
      _authError = 'Not connected to server. Please check your connection.';
      notifyListeners();
      return;
    }
    _isAuthLoading = true;
    _authError = null;
    _pendingPhone = phone.trim();
    notifyListeners();

    _channel!.sink.add(jsonEncode({
      'type': 'tg-send-code',
      'phone': _pendingPhone,
      'apiId': apiId,
      'apiHash': apiHash,
    }));
  }

  void verifyTelegramAuthCode(String code) {
    if (_useDirectTdLib) {
      _isAuthLoading = true;
      _authError = null;
      notifyListeners();
      tdLib.checkAuthCode(code);
      return;
    }

    if (_status != ConnectionStatus.connected || _channel == null) {
      _authError = 'Not connected to server.';
      notifyListeners();
      return;
    }
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    _channel!.sink.add(jsonEncode({
      'type': 'tg-verify-code',
      'code': code.trim(),
    }));
  }

  void verifyTelegram2FA(String password) {
    if (_useDirectTdLib) {
      _isAuthLoading = true;
      _authError = null;
      notifyListeners();
      tdLib.check2FAPassword(password);
      return;
    }

    if (_status != ConnectionStatus.connected || _channel == null) {
      _authError = 'Not connected to server.';
      notifyListeners();
      return;
    }
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    _channel!.sink.add(jsonEncode({
      'type': 'tg-verify-2fa',
      'password': password,
    }));
  }

  void unlinkTelegramAccount() {
    if (_useDirectTdLib) {
      tdLib.logOut();
      _isTgAccountLinked = false;
      _authStep = 'phone';
      _authError = null;
      _isAuthLoading = false;
      _currentUser = TelegramUser(
        id: 'usr_me',
        username: 'Telegram User',
        avatar: '👨‍🚀',
        phoneNumber: '+1 888 777 5555',
        bio: 'Ready to connect real account 🚀',
      );
      _initDefaultRooms();
      notifyListeners();
      return;
    }

    if (_channel != null && _status == ConnectionStatus.connected) {
      _channel!.sink.add(jsonEncode({
        'type': 'tg-logout',
      }));
    }
    _isTgAccountLinked = false;
    _authStep = 'phone';
    _authError = null;
    _isAuthLoading = false;
    _currentUser = TelegramUser(
      id: 'usr_me',
      username: 'Telegram User',
      avatar: '👨‍🚀',
      phoneNumber: '+1 888 777 5555',
      bio: 'Ready to connect real account 🚀',
    );
    _initDefaultRooms();
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
