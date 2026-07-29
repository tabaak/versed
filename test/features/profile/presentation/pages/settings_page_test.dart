import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/widgets/app_toggle.dart';
import 'package:versed/features/auth/controllers/auth_controller.dart';
import 'package:versed/features/auth/models/auth_model.dart';
import 'package:versed/features/profile/presentation/pages/settings_page.dart';

/// Stands in for the real controller so sign-out can be driven without
/// Supabase: it records the call and replays either outcome.
class _FakeAuthController extends AuthController {
  _FakeAuthController({this.fails = false});

  final bool fails;
  int signOutCount = 0;

  // Synchronous on purpose: an async build would settle after signOut and
  // overwrite the outcome this fake was asked to replay.
  @override
  AuthModel? build() => null;

  @override
  Future<void> signOut() async {
    signOutCount++;
    state = fails
        ? AsyncError(Exception('offline'), StackTrace.empty)
        : const AsyncData(null);
  }
}

Future<_FakeAuthController> _pumpSettings(
  WidgetTester tester, {
  bool fails = false,
}) async {
  final controller = _FakeAuthController(fails: fails);

  // Every control here awaits its haptic before acting, and an unanswered
  // platform channel leaves that await hanging — so the taps would do nothing.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => Navigator.of(context).push<void>(
              CupertinoPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return controller;
}

/// Walks the confirm sheet the sign-out row opens.
Future<void> _tapSignOut(WidgetTester tester) async {
  await tester.tap(find.text('Sign out'));
  await tester.pumpAndSettle();
  // The row and the sheet's action share the label; the sheet's is the last.
  await tester.tap(find.text('Sign out').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('carries the settings rows off the profile tab', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Public profile'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('flips a toggle in place', (tester) async {
    await _pumpSettings(tester);

    final toggle = find.byType(AppToggleSwitch).first;
    expect(tester.widget<AppToggleSwitch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<AppToggleSwitch>(toggle).value, isFalse);
  });

  testWidgets('an unfinished row says so instead of going nowhere', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.text('Account is coming soon.'), findsOneWidget);

    // The toast times itself out; leaving it running outlives the test.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('signing out steps aside for the auth gate', (tester) async {
    final controller = await _pumpSettings(tester);

    await _tapSignOut(tester);

    expect(controller.signOutCount, 1);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('a failed sign-out stays on the page', (tester) async {
    final controller = await _pumpSettings(tester, fails: true);

    await _tapSignOut(tester);

    expect(controller.signOutCount, 1);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
