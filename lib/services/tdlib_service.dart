import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib_next/handy_tdlib_next.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_model.dart';

class TdLibService extends ChangeNotifier {
  static const int apiId = 2040;
  static const String apiHash = 'b18441a1ff607e10a989891a5462e627';

  int? _clientId;
  bool _isRunning = false;
  bool _isInitialized = false;

  bool _isAuthorized = false;
  bool get isAuthorized => _isAuthorized;

  String _authStep = 'phone'; // 'phone', 'code', '2fa', 'ready'
  String get authStep => _authStep;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;

  TelegramUser _currentUser = TelegramUser(
    id: 'me',
    username: 'Telegram User',
    avatar: '✈️',
    phoneNumber: '',
    bio: 'Connected directly via TDLib 🚀',
  );
  TelegramUser get currentUser => _currentUser;

  final Map<int, ChatRoom> _chatRoomsMap = {};
  List<ChatRoom> get chatRooms => _chatRoomsMap.values.toList();

  final Map<int, List<ChatMessage>> _chatMessagesMap = {};
  List<ChatMessage> getChatMessages(int chatId) => _chatMessagesMap[chatId] ?? [];

  int? _selectedChatId;
  int? get selectedChatId => _selectedChatId;

  Future<void> start() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _isLoading = true;
    notifyListeners();

    try {
      if (Platform.isAndroid) {
        await TdPlugin.initialize();
      }
      _clientId = TdPlugin.instance.tdCreateClientId();

      // Set low verbosity to avoid spamming logcat
      TdPlugin.instance.tdExecute(
        jsonEncode(const SetLogVerbosityLevel(newVerbosityLevel: 1).toJson(0)),
      );

      _isRunning = true;
      _startReceiveLoop();
    } catch (e) {
      _errorMessage = 'Failed to initialize TDLib: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _send(TdFunction function, [int extra = 0]) {
    if (_clientId == null) return;
    final jsonStr = jsonEncode(function.toJson(extra));
    TdPlugin.instance.tdSend(_clientId!, jsonStr);
  }

  void _startReceiveLoop() {
    // Run TDLib receive loop using microtasks / periodic timer to keep Flutter UI 60fps
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_isRunning || _clientId == null) {
        timer.cancel();
        return;
      }

      while (true) {
        final res = TdPlugin.instance.tdReceive(0.0);
        if (res == null || res.isEmpty) break;

        try {
          final obj = convertJsonToObject(res);
          if (obj != null) {
            _handleTdObject(obj);
          }
        } catch (e) {
          if (kDebugMode) print('TDLib parse error: $e');
        }
      }
    });
  }

  void _handleTdObject(TdObject obj) {
    if (obj is UpdateAuthorizationState) {
      _handleAuthState(obj.authorizationState);
    } else if (obj is UpdateNewChat) {
      _handleNewChat(obj.chat);
    } else if (obj is UpdateChatLastMessage) {
      _handleChatLastMessage(obj);
    } else if (obj is UpdateNewMessage) {
      _handleNewMessage(obj.message);
    } else if (obj is UpdateUser) {
      _handleUserUpdate(obj.user);
    } else if (obj is User) {
      _handleCurrentUser(obj);
    } else if (obj is TdError) {
      _errorMessage = obj.message;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleAuthState(AuthorizationState state) async {
    if (state is AuthorizationStateWaitTdlibParameters) {
      final dir = await getApplicationDocumentsDirectory();
      final setParams = SetTdlibParameters(
        useTestDc: false,
        databaseDirectory: '${dir.path}/tdlib_data',
        filesDirectory: '${dir.path}/tdlib_files',
        databaseEncryptionKey: '',
        useFileDatabase: true,
        useChatInfoDatabase: true,
        useMessageDatabase: true,
        useSecretChats: false,
        apiId: apiId,
        apiHash: apiHash,
        systemLanguageCode: 'en',
        deviceModel: 'Android Phone',
        systemVersion: 'Android',
        applicationVersion: '1.0.0',
      );
      _send(setParams);
    } else if (state is AuthorizationStateWaitPhoneNumber) {
      _isAuthorized = false;
      _authStep = 'phone';
      _isLoading = false;
      notifyListeners();
    } else if (state is AuthorizationStateWaitCode) {
      _isAuthorized = false;
      _authStep = 'code';
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } else if (state is AuthorizationStateWaitPassword) {
      _isAuthorized = false;
      _authStep = '2fa';
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } else if (state is AuthorizationStateReady) {
      _isAuthorized = true;
      _authStep = 'ready';
      _isLoading = false;
      _errorMessage = null;

      // Request current user profile and chat list
      _send(const GetMe());
      _send(const LoadChats(limit: 50));
      notifyListeners();
    } else if (state is AuthorizationStateLoggingOut) {
      _isLoading = true;
      notifyListeners();
    } else if (state is AuthorizationStateClosed) {
      _isAuthorized = false;
      _authStep = 'phone';
      _isLoading = false;
      _chatRoomsMap.clear();
      _chatMessagesMap.clear();
      notifyListeners();
    }
  }

  void _handleNewChat(Chat chat) {
    String typeStr = 'user';
    final chatType = chat.type;
    if (chatType is ChatTypeSupergroup || chatType is ChatTypeBasicGroup) {
      typeStr = 'group';
    } else if (chatType is ChatTypeSupergroup && chatType.isChannel) {
      typeStr = 'channel';
    }

    String lastMsgText = '';
    String lastMsgTime = '';
    if (chat.lastMessage != null) {
      final content = chat.lastMessage!.content;
      if (content is MessageText) {
        lastMsgText = content.text.text;
      } else if (content is MessagePhoto) {
        lastMsgText = '📷 Photo';
      } else if (content is MessageVoiceNote) {
        lastMsgText = '🎤 Voice message';
      } else {
        lastMsgText = 'Media message';
      }
      lastMsgTime = DateTime.fromMillisecondsSinceEpoch(chat.lastMessage!.date * 1000)
          .toLocal()
          .toString()
          .split(' ')
          .last
          .substring(0, 5);
    }

    _chatRoomsMap[chat.id] = ChatRoom(
      id: chat.id.toString(),
      name: chat.title,
      avatar: typeStr == 'channel' ? '📢' : (typeStr == 'group' ? '👥' : '👤'),
      description: 'Real Telegram ${typeStr.toUpperCase()}',
      lastMessage: lastMsgText,
      lastTime: lastMsgTime,
      unreadCount: chat.unreadCount,
      isChannel: typeStr == 'channel',
    );
    notifyListeners();
  }

  void _handleChatLastMessage(UpdateChatLastMessage update) {
    if (_chatRoomsMap.containsKey(update.chatId)) {
      final old = _chatRoomsMap[update.chatId]!;
      String text = old.lastMessage;
      String time = old.lastTime;
      if (update.lastMessage != null) {
        final content = update.lastMessage!.content;
        if (content is MessageText) {
          text = content.text.text;
        } else if (content is MessagePhoto) {
          text = '📷 Photo';
        } else if (content is MessageVoiceNote) {
          text = '🎤 Voice message';
        }
        time = DateTime.fromMillisecondsSinceEpoch(update.lastMessage!.date * 1000)
            .toLocal()
            .toString()
            .split(' ')
            .last
            .substring(0, 5);
      }
      _chatRoomsMap[update.chatId] = ChatRoom(
        id: old.id,
        name: old.name,
        avatar: old.avatar,
        description: old.description,
        lastMessage: text,
        lastTime: time,
        unreadCount: old.unreadCount,
        isChannel: old.isChannel,
      );
      notifyListeners();
    }
  }

  void _handleNewMessage(Message msg) {
    String text = '';
    final content = msg.content;
    if (content is MessageText) {
      text = content.text.text;
    } else if (content is MessagePhoto) {
      text = '📷 Photo';
    } else if (content is MessageVoiceNote) {
      text = '🎤 Voice note';
    }

    final newMsg = ChatMessage(
      id: 'td_${msg.id}',
      senderId: msg.isOutgoing ? 'me' : 'other',
      senderName: msg.isOutgoing ? 'You' : 'User',
      avatar: msg.isOutgoing ? '👤' : '👥',
      text: text,
      roomId: msg.chatId.toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(msg.date * 1000)
          .toLocal()
          .toString()
          .split(' ')
          .last
          .substring(0, 5),
      isOutgoing: msg.isOutgoing,
    );

    if (!_chatMessagesMap.containsKey(msg.chatId)) {
      _chatMessagesMap[msg.chatId] = [];
    }
    _chatMessagesMap[msg.chatId]!.add(newMsg);
    notifyListeners();
  }

  void _handleCurrentUser(User user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    _currentUser = TelegramUser(
      id: user.id.toString(),
      username: name.isNotEmpty ? name : (user.usernames?.activeUsernames.firstOrNull ?? 'Telegram User'),
      avatar: '✈️',
      phoneNumber: user.phoneNumber.isNotEmpty ? '+${user.phoneNumber}' : '',
      bio: '@${user.usernames?.activeUsernames.firstOrNull ?? 'telegram'} • Direct TDLib Connection',
    );
    notifyListeners();
  }

  void _handleUserUpdate(User user) {
    if (user.id.toString() == _currentUser.id) {
      _handleCurrentUser(user);
    }
  }

  // --- User Authentication Actions ---

  void setPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    _phoneNumber = cleanPhone;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _send(SetAuthenticationPhoneNumber(phoneNumber: cleanPhone));
  }

  void checkAuthCode(String code) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _send(CheckAuthenticationCode(code: code.trim()));
  }

  void check2FAPassword(String password) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _send(CheckAuthenticationPassword(password: password.trim()));
  }

  void logOut() {
    _isLoading = true;
    notifyListeners();

    _send(const LogOut());
  }

  void sendMessage(int chatId, String text) {
    if (text.trim().isEmpty) return;
    _send(SendMessage(
      chatId: chatId,
      messageThreadId: 0,
      inputMessageContent: InputMessageText(
        clearDraft: true,
        text: FormattedText(text: text.trim(), entities: const []),
      ),
    ));
  }

  void selectChat(int chatId) {
    _selectedChatId = chatId;
    _send(GetChatHistory(
      chatId: chatId,
      fromMessageId: 0,
      offset: 0,
      limit: 50,
      onlyLocal: false,
    ));
    notifyListeners();
  }

  @override
  void dispose() {
    _isRunning = false;
    super.dispose();
  }
}
