class TelegramUser {
  final String id;
  final String username;
  final String avatar;
  final String? phoneNumber;
  final String? bio;
  final bool isOnline;

  TelegramUser({
    required this.id,
    required this.username,
    required this.avatar,
    this.phoneNumber,
    this.bio,
    this.isOnline = true,
  });

  factory TelegramUser.fromJson(Map<String, dynamic> json) {
    return TelegramUser(
      id: json['id'] ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      username: json['username'] ?? 'Anonymous',
      avatar: json['avatar'] ?? '👤',
      phoneNumber: json['phoneNumber'] ?? '+1 234 567 8900',
      bio: json['bio'] ?? 'Hey there! I am using Telegram.',
      isOnline: json['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'avatar': avatar,
    'phoneNumber': phoneNumber,
    'bio': bio,
    'isOnline': isOnline,
  };
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String avatar;
  final String text;
  final String? media; // base64 or url
  final String? voiceNote;
  final String roomId;
  final String timestamp;
  final bool isOutgoing;
  final bool isSystem;
  final bool isVerified;
  final List<String> reactions;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.avatar,
    required this.text,
    this.media,
    this.voiceNote,
    required this.roomId,
    required this.timestamp,
    this.isOutgoing = false,
    this.isSystem = false,
    this.isVerified = false,
    this.reactions = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final senderId = json['senderId']?.toString() ?? '';
    final isOut = currentUserId != null ? senderId == currentUserId : (json['isOutgoing'] ?? false);

    return ChatMessage(
      id: json['id'] ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: json['senderName'] ?? 'Member',
      avatar: json['avatar'] ?? '👤',
      text: json['text'] ?? '',
      media: json['media'],
      voiceNote: json['voiceNote'],
      roomId: json['roomId'] ?? 'room-general',
      timestamp: json['timestamp'] ?? 'Now',
      isOutgoing: isOut,
      isSystem: json['isSystem'] ?? false,
      isVerified: json['isVerified'] ?? false,
      reactions: json['reactions'] != null ? List<String>.from(json['reactions']) : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'avatar': avatar,
    'text': text,
    'media': media,
    'voiceNote': voiceNote,
    'roomId': roomId,
    'timestamp': timestamp,
    'isOutgoing': isOutgoing,
    'isSystem': isSystem,
    'isVerified': isVerified,
    'reactions': reactions,
  };
}

class ChatRoom {
  final String id;
  final String name;
  final String avatar;
  final String description;
  final int unreadCount;
  final String lastMessage;
  final String lastTime;
  final bool isPinned;
  final bool isChannel;
  final bool isVerified;
  final bool isBot;
  final int onlineCount;

  ChatRoom({
    required this.id,
    required this.name,
    required this.avatar,
    required this.description,
    this.unreadCount = 0,
    required this.lastMessage,
    required this.lastTime,
    this.isPinned = false,
    this.isChannel = false,
    this.isVerified = false,
    this.isBot = false,
    this.onlineCount = 1,
  });

  ChatRoom copyWith({
    String? lastMessage,
    String? lastTime,
    int? unreadCount,
    int? onlineCount,
  }) {
    return ChatRoom(
      id: id,
      name: name,
      avatar: avatar,
      description: description,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      isPinned: isPinned,
      isChannel: isChannel,
      isVerified: isVerified,
      isBot: isBot,
      onlineCount: onlineCount ?? this.onlineCount,
    );
  }
}
