import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:telegram_app/main.dart';
import 'package:telegram_app/services/telegram_service.dart';

void main() {
  testWidgets('Telegram app loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TelegramService()),
        ],
        child: const TelegramMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Telegram'), findsWidgets);
  });
}
