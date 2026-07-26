import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/features/profile/controllers/profile_controller.dart';
import 'package:versed/features/profile/models/profile_model.dart';
import 'package:versed/features/profile/presentation/pages/edit_profile_page.dart';

/// Stands in for the real controller so the page can be driven without
/// Supabase: it records what the page asked for and replays a canned answer.
class _FakeProfileController extends ProfileController {
  _FakeProfileController({this.isAvailable = true, this.failure});

  final bool isAvailable;
  final String? failure;

  final List<String> availabilityChecks = [];
  String? savedUsername;
  String? savedDisplayName;
  int saveCount = 0;

  @override
  Future<ProfileSummary?> build() async => null;

  @override
  Future<bool> isUsernameAvailable(String username) async {
    availabilityChecks.add(username);
    return isAvailable;
  }

  @override
  Future<String?> updateProfile({
    required String username,
    required String? displayName,
  }) async {
    saveCount++;
    savedUsername = username;
    savedDisplayName = displayName;
    return failure;
  }
}

Future<_FakeProfileController> _pumpEditProfile(
  WidgetTester tester, {
  String? displayName = 'Ada Lovelace',
  String? username = 'ada',
  bool isAvailable = true,
  String? failure,
  List<bool>? popResults,
}) async {
  final controller = _FakeProfileController(
    isAvailable: isAvailable,
    failure: failure,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileControllerProvider.overrideWith(() => controller)],
      child: CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                CupertinoPageRoute<bool>(
                  builder: (_) => EditProfilePage(
                    initialDisplayName: displayName,
                    initialUsername: username,
                  ),
                ),
              );
              popResults?.add(result ?? false);
            },
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

void main() {
  // AppButton awaits a haptic before running its callback, and an unanswered
  // platform channel never completes under the test binding.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('seeds the fields and keeps Save disabled until something '
      'changes', (tester) async {
    final controller = await _pumpEditProfile(tester);

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(controller.saveCount, 0);
  });

  testWidgets('saves the edited name and handle, then pops with success', (
    tester,
  ) async {
    final popResults = <bool>[];
    final controller = await _pumpEditProfile(tester, popResults: popResults);

    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Ada Byron',
    );
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(controller.saveCount, 1);
    expect(controller.savedUsername, 'ada');
    expect(controller.savedDisplayName, 'Ada Byron');
    expect(popResults, [true]);
  });

  testWidgets('clearing the display name is a saveable change', (
    tester,
  ) async {
    final controller = await _pumpEditProfile(tester);

    await tester.enterText(find.byType(CupertinoTextField).first, '');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // The controller turns the empty field into a null display name.
    expect(controller.saveCount, 1);
    expect(controller.savedDisplayName, '');
  });

  testWidgets('does not check availability for the handle the user already '
      'has', (tester) async {
    final controller = await _pumpEditProfile(tester);

    await tester.enterText(find.byType(CupertinoTextField).last, 'adax');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(CupertinoTextField).last, 'ada');
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.availabilityChecks, ['adax']);
    expect(find.text('@ada is free.'), findsNothing);
  });

  testWidgets('blocks saving a handle that is taken', (tester) async {
    final controller = await _pumpEditProfile(tester, isAvailable: false);

    await tester.enterText(find.byType(CupertinoTextField).last, 'grace');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('@grace is taken.'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(controller.saveCount, 0);
  });

  testWidgets('surfaces a failed save and stays on the page', (tester) async {
    final popResults = <bool>[];
    await _pumpEditProfile(
      tester,
      failure: 'That handle is taken.',
      popResults: popResults,
    );

    await tester.enterText(find.byType(CupertinoTextField).first, 'Ada B');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('That handle is taken.'), findsOneWidget);
    expect(popResults, isEmpty);
    expect(find.text('Save changes'), findsOneWidget);
  });
}
