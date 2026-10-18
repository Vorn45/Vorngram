# 🚀 Vorngram - Complete Telegram Platform & Mobile Client

Vorngram is a full-featured Telegram client and real-time communication platform featuring direct MTProto TDLib connection (zero server needed), real-time WebRTC audio/video calling, a Telegram Bot bridge, and a custom message studio.

---

## 📁 Repository Structure

```
Vorngram/
├── lib/                   # 📱 Flutter Mobile App Source Code
│   ├── models/            # Chat & User data models
│   ├── screens/           # Home, Chat, Auth, Settings, Call screens
│   ├── services/          # TelegramService & TDLib native MTProto direct service
│   ├── theme/             # Official Telegram Dark & Light themes
│   └── widgets/           # ChatBubble, TelegramDrawer, VoiceNotePlayer
│
├── android/               # 🤖 Android runner with native TDLib (libtdjson.so) binaries
├── ios/                   # 🍏 iOS runner
├── web/                   # 🌐 Flutter Web runner
│
└── server/                # 🖥️ Node.js Real-time Backend & Web Client
    ├── src/
    │   ├── server.js          # WebRTC signaling, rooms & bot integration
    │   ├── telegramAccount.js # GramJS MTProto client & event listeners
    │   └── config.js          # Bot & server configuration
    ├── public/            # Web application & WebRTC video call interface
    └── .env.example       # Backend environment template
```

---

## ✨ Features

- **Direct Native MTProto Connection (0 Servers Needed):**
  - Integrated `handy_tdlib_next` for direct connection to Telegram Data Centers.
  - Multi-step phone number verification, 5-digit OTP, and 2FA cloud password support.
  - Complete sync for Channels, Groups, Direct Chats, and Saved Messages.
- **Node.js Companion Server (`server/`):**
  - WebRTC peer-to-peer audio and video calling signaling.
  - Telegram Bot Bridge with admin notifications.
  - 🎭 Fake Message Studio for message mocking and staging.
- **Authentic Telegram UI:**
  - Official Telegram Dark & Light themes (`#2AABEE`, `#0E1621`).
  - Interactive reaction picker (❤️, 👍, 🔥, 🎉, 😂, 👏, 🚀) via long press.
  - Animated voice notes widget with audio waveforms.
  - Attachment sheets (Gallery, Camera, Files, Location).

---

## 🚀 Getting Started

### 1. Mobile App (Flutter)
```bash
cd Vorngram
flutter pub get
flutter run
```

To build a release APK for Android:
```bash
flutter build apk --release
```

### 2. Companion Backend Server (`server/`)
```bash
cd Vorngram/server
npm install
cp .env.example .env
# Edit .env with your BOT_TOKEN and ADMIN_IDS
npm start
```

---

## 📄 License
MIT License
