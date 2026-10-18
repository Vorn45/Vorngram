```
██╗   ██╗ ██████╗ ██████╗ ███╗   ██╗ ██████╗ ██████╗  █████╗ ███╗   ███╗
██║   ██║██╔═══██╗██╔══██╗████╗  ██║██╔════╝ ██╔══██╗██╔══██╗████╗ ████║
██║   ██║██║   ██║██████╔╝██╔██╗ ██║██║  ███╗██████╔╝███████║██╔████╔██║
╚██╗ ██╔╝██║   ██║██╔══██╗██║╚██╗██║██║   ██║██╔══██╗██╔══██║██║╚██╔╝██║
 ╚████╔╝ ╚██████╔╝██║  ██║██║ ╚████║╚██████╔╝██║  ██║██║  ██║██║ ╚═╝ ██║
  ╚═══╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

                   ██████╗  █████╗ ███╗   ███╗██████╗  ██████╗ 
                  ██╔════╝ ██╔══██╗████╗ ████║██╔══██╗██╔═══██╗
                  ██║      ███████║██╔████╔██║██████╔╝██║   ██║
                  ██║      ██╔══██║██║╚██╔╝██║██╔══██╗██║   ██║
                  ╚██████╗ ██║  ██║██║ ╚═╝ ██║██████╔╝╚██████╔╝
                   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═════╝  ╚═════╝ 
```

<div align="center">

### 🇰🇭 Vorngram Cambo • Next-Gen Telegram Client & WebRTC Platform
**Real-Time MTProto Messaging • Zero-Server Native Client • WebRTC Voice/Video Calling • Bot Bridge**

[![GitHub](https://img.shields.io/badge/GITHUB-Vorngram--Cambo-181717?style=for-the-badge&logo=github)](https://github.com/Vorn45/Vorngram)
[![Platform](https://img.shields.io/badge/PLATFORM-FLUTTER%20%7C%20ANDROID-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Engine](https://img.shields.io/badge/ENGINE-MTPROTO%20TDLIB-2AABEE?style=for-the-badge&logo=telegram)](https://core.telegram.org/tdlib)
[![WebRTC](https://img.shields.io/badge/CALLS-WEBRTC-333333?style=for-the-badge&logo=webrtc)](https://webrtc.org)
[![License](https://img.shields.io/badge/LICENSE-MIT-00C853?style=for-the-badge)](LICENSE)

</div>

---

## ⚡ Quick Start

```bash
$ git clone https://github.com/Vorn45/Vorngram.git
$ cd Vorngram
$ setup.bat              # on Windows (or ./setup.sh on macOS / Linux)
$ flutter run
```

---

## 📁 Repository Structure

```
Vorngram/
├── lib/                   # 📱 Flutter Mobile App (Dart)
│   ├── models/            # Chat & User models
│   ├── screens/           # Home, Chat, Auth, Settings, Call screens
│   ├── services/          # TelegramService & TDLib native MTProto direct service
│   ├── theme/             # Authentic Telegram Dark & Light themes
│   └── widgets/           # ChatBubble, TelegramDrawer, VoiceNotePlayer
│
├── android/               # 🤖 Android native runner with precompiled libtdjson.so binaries
├── ios/                   # 🍏 iOS native runner
├── web/                   # 🌐 Web application runner
│
└── server/                # 🖥️ Node.js Real-time Backend & Web Client
    ├── src/
    │   ├── server.js          # WebRTC signaling, rooms & bot bridge
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

## 🚀 Running the Project

### 📱 1. Mobile App (Flutter)
```bash
flutter pub get
flutter run
```

To build a production release APK for Android:
```bash
flutter build apk --release
```
*The APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.*

### 🖥️ 2. Companion Backend Server (`server/`)
```bash
cd server
npm install
npm start
```
*Opens at `http://localhost:3000` with the WebRTC Calling Portal & Fake Message Studio.*

---

## 📄 License
Distributed under the MIT License. See `LICENSE` for more information.
