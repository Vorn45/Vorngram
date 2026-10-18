import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telegram_service.dart';
import '../theme/telegram_theme.dart';
import '../widgets/telegram_avatar.dart';

class TelegramAuthScreen extends StatefulWidget {
  const TelegramAuthScreen({super.key});

  @override
  State<TelegramAuthScreen> createState() => _TelegramAuthScreenState();
}

class _TelegramAuthScreenState extends State<TelegramAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _apiIdController = TextEditingController();
  final TextEditingController _apiHashController = TextEditingController();

  bool _showAdvanced = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<TelegramService>(context, listen: false);
    service.resetAuthFlow();
    if (service.pendingPhone != null && service.pendingPhone!.isNotEmpty) {
      _phoneController.text = service.pendingPhone!;
    } else if (service.currentUser.phoneNumber != null && service.currentUser.phoneNumber!.isNotEmpty && !service.currentUser.phoneNumber!.contains('888 777')) {
      _phoneController.text = service.currentUser.phoneNumber!;
    } else {
      _phoneController.text = '+855';
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _apiIdController.dispose();
    _apiHashController.dispose();
    super.dispose();
  }

  void _sendCode(TelegramService service) {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone == '+') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number with country code')),
      );
      return;
    }
    service.sendTelegramAuthCode(
      phone,
      apiId: _apiIdController.text.trim().isNotEmpty ? _apiIdController.text.trim() : null,
      apiHash: _apiHashController.text.trim().isNotEmpty ? _apiHashController.text.trim() : null,
    );
  }

  void _verifyCode(TelegramService service) {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 5-digit verification code')),
      );
      return;
    }
    service.verifyTelegramAuthCode(code);
  }

  void _verify2FA(TelegramService service) {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your 2FA password')),
      );
      return;
    }
    service.verifyTelegram2FA(pwd);
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<TelegramService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          service.authStep == 'linked' ? 'Telegram Account' : 'Link Telegram Account',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (service.isTgAccountLinked)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Unlink Account',
              onPressed: () {
                _confirmUnlink(context, service);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header Graphic
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: service.isTgAccountLinked
                        ? [Colors.teal, Colors.green]
                        : [TelegramTheme.primaryBlue, const Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (service.isTgAccountLinked ? Colors.green : TelegramTheme.primaryBlue)
                          .withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Center(
                  child: Icon(
                    service.isTgAccountLinked ? Icons.check_circle_outline : Icons.send_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error banner if any
            if (service.authError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        service.authError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Content based on step
            if (service.isTgAccountLinked) ...[
              _buildLinkedStep(service, isDark),
            ] else if (service.authStep == 'code') ...[
              _buildCodeStep(service, isDark),
            ] else if (service.authStep == '2fa') ...[
              _build2FAStep(service, isDark),
            ] else ...[
              _buildPhoneStep(service, isDark),
            ],
          ],
        ),
      ),
    );
  }

  // STEP 1: Phone number
  Widget _buildPhoneStep(TelegramService service, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Your Phone Number',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your phone number in international format.\nWe will send a code via Telegram app or SMS.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 18, letterSpacing: 1.1),
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '+855 10 843 612',
            prefixIcon: const Icon(Icons.phone_iphone, color: TelegramTheme.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        // Advanced Settings toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Custom API Credentials',
              style: TextStyle(
                color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
                fontSize: 13,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Text(_showAdvanced ? 'Hide' : 'Configure'),
            ),
          ],
        ),

        if (_showAdvanced) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _apiIdController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Telegram API ID (Optional)',
              hintText: 'Default: 2040',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiHashController,
            decoration: InputDecoration(
              labelText: 'Telegram API Hash (Optional)',
              hintText: 'Default: official hash',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TelegramTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: service.isAuthLoading ? null : () => _sendCode(service),
            child: service.isAuthLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Send Verification Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // STEP 2: Verification Code
  Widget _buildCodeStep(TelegramService service, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Enter Verification Code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: "We've sent a code to your Telegram app or via SMS to \n"),
              TextSpan(
                text: service.pendingPhone ?? _phoneController.text,
                style: const TextStyle(fontWeight: FontWeight.bold, color: TelegramTheme.primaryBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '• • • • •',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TelegramTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: service.isAuthLoading ? null : () => _verifyCode(service),
            child: service.isAuthLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Verify Code & Link Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            service.setAuthStep('phone');
          },
          child: const Text('Wrong phone number? Change'),
        ),
      ],
    );
  }

  // STEP 3: 2FA Password
  Widget _build2FAStep(TelegramService service, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Two-Step Verification',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Your Telegram account has cloud Two-Step Verification enabled.\nPlease enter your 2FA password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? TelegramTheme.darkSubtext : TelegramTheme.lightSubtext,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: '2FA Password',
            prefixIcon: const Icon(Icons.lock_outline, color: TelegramTheme.primaryBlue),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TelegramTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: service.isAuthLoading ? null : () => _verify2FA(service),
            child: service.isAuthLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Confirm Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            service.setAuthStep('code');
          },
          child: const Text('Back to Code'),
        ),
      ],
    );
  }

  // STEP 4: Connected / Linked State
  Widget _buildLinkedStep(TelegramService service, bool isDark) {
    final user = service.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Account Linked!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Telegram account is connected and synced.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // User info card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? TelegramTheme.darkSurface : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? TelegramTheme.darkDivider : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              TelegramAvatar(
                name: user.username,
                imageOrEmoji: user.avatar,
                radius: 40,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      user.username,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: TelegramTheme.primaryBlue, size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                user.phoneNumber ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? TelegramTheme.darkSubtext : Colors.grey.shade700,
                ),
              ),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  user.bio!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: TelegramTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.chat),
            label: const Text('Open My Chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Unlink / Switch Account'),
          onPressed: () {
            _confirmUnlink(context, service);
          },
        ),
      ],
    );
  }

  void _confirmUnlink(BuildContext context, TelegramService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Telegram Account?'),
        content: const Text(
          'Are you sure you want to disconnect this Telegram account? You will need to verify your phone number again to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              service.unlinkTelegramAccount();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Telegram account unlinked')),
              );
            },
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }
}
