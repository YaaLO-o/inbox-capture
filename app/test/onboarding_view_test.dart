import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/settings_service.dart';
import 'package:inbox_app/ui/onboarding_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('首次引导展示统一 Universal Capture 数据目录', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    await tester.pumpWidget(
      OnboardingView(settings: SettingsService(), onVaultSelected: (_) {}),
    );

    expect(find.textContaining('Universal Capture'), findsOneWidget);
    expect(find.textContaining('素材/Inbox'), findsNothing);
  });
}
