import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/telegram_service.dart';
import 'theme/telegram_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive system status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelegramService()),
      ],
      child: const TelegramMobileApp(),
    ),
  );
}

class TelegramMobileApp extends StatefulWidget {
  const TelegramMobileApp({super.key});

  @override
  State<TelegramMobileApp> createState() => _TelegramMobileAppState();
}

class _TelegramMobileAppState extends State<TelegramMobileApp> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadThemePref();
  }

  Future<void> _loadThemePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool('is_dark_mode');
      if (dark != null) {
        setState(() {
          _isDarkMode = dark;
        });
      }
    } catch (_) {}
  }

  void _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', _isDarkMode);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram',
      debugShowCheckedModeBanner: false,
      theme: TelegramTheme.lightTheme,
      darkTheme: TelegramTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
