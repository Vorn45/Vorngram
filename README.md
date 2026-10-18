# ✈️ Telegram Mobile App (Flutter & Dart)

A native Flutter cross-platform mobile application replicating the authentic Telegram mobile client experience with real-time WebSocket messaging, WebRTC calling UI, dark/light themes, and seamless sync with your local Node.js backend & Telegram Bot bridge.

---

## ✨ Features

- **Authentic Telegram UI**:
  - Sleek Telegram Dark & Light themes (with Telegram Blue `#2AABEE`, dark chat background `#0E1621`, and message bubbles).
  - Side navigation drawer with profile header, phone number, saved messages, contacts, calls, and settings.
  - Chat list tabs: **All**, **Channels**, **Bots**, and **Groups** with unread count pills, pins, and verified checkmarks (e.g. Pavel Durov, Secret Bot).
- **Interactive Chat Interface**:
  - Outgoing and incoming message bubbles with read checkmarks (`✓✓`), timestamps, and sender accent colors.
  - Interactive reaction picker (❤️, 👍, 🔥, 🎉, 😂, 👏, 🚀) via long press.
  - Animated voice notes widget with audio waveforms.
  - Attachment bottom sheet (Gallery, Camera, Files, Live Location).
  - Quick emoji tray and text input.
- **Voice & Video Calling**:
  - Telegram end-to-end encrypted 4-emoji verification keys (🦊 ⚡ 🎸 💎).
  - Ringing/pulsing animation, call duration timer, speaker toggle, mic mute, and camera flip.
- **Backend & Telegram Bridge Integration**:
  - Built-in `TelegramService` connecting to your local Node.js WebSocket backend (`ws://10.0.2.2:3000` for Android emulator or `ws://localhost:3000` for desktop/tunnel).
  - Seamless fallback demo mode: the app runs immediately even before starting the backend!

---

## 🚀 How to Run

### 1. Run on Windows Desktop (Fastest Preview)
Double-click `run-windows.bat` or run:
```bash
cd d:\Tool\telegram_app
flutter run -d windows
```

### 2. Run on Android Emulator (Pixel 7)
Double-click `run-android.bat` or run:
```bash
cd d:\Tool\telegram_app
flutter emulators --launch Pixel_7
flutter run -d android
```

### 3. Build Android APK
Double-click `build-apk.bat` or run:
```bash
cd d:\Tool\telegram_app
flutter build apk
```
The generated `.apk` will be in `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🔗 Connecting to the Backend Server

1. Start your Node.js backend in `d:\Tool\Telegram`:
   ```bash
   cd d:\Tool\Telegram
   npm start
   ```
2. Open the Telegram Flutter app -> Menu / Drawer -> **Settings**.
3. Under **Backend Server & WebSocket**, enter:
   - For Android Emulator: `ws://10.0.2.2:3000`
   - For Windows Desktop: `ws://localhost:3000`
   - For remote testing: Your Cloudflare tunnel URL from `start-public-free.bat` (e.g. `wss://...`)
4. Tap **Connect / Save URL**.
