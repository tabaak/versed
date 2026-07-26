import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/widgets/app_image_cropper.dart';
import 'package:versed/features/profile/controllers/profile_controller.dart';
import 'package:versed/features/profile/models/profile_model.dart';
import 'package:versed/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:versed/features/upload/models/upload_state.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:versed/features/upload/services/image_pick_service.dart';

/// Stands in for the real controller so the page can be driven without
/// Supabase: it records what the page asked for and replays a canned answer.
class _FakeProfileController extends ProfileController {
  _FakeProfileController({this.isAvailable = true, this.failure});

  final bool isAvailable;
  final String? failure;

  final List<String> availabilityChecks = [];
  String? savedUsername;
  String? savedDisplayName;
  PickedFit? savedAvatar;
  Rect? savedAvatarCrop;
  bool savedRemoveAvatar = false;
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
    PickedFit? avatar,
    Rect? avatarCrop,
    bool removeAvatar = false,
  }) async {
    saveCount++;
    savedUsername = username;
    savedDisplayName = displayName;
    savedAvatar = avatar;
    savedAvatarCrop = avatarCrop;
    savedRemoveAvatar = removeAvatar;
    return failure;
  }
}

/// A real photo, tall enough that framing it is a meaningful choice: the
/// centered square starts 100px down.
const _photoWidth = 200;
const _photoHeight = 400;

final _photoBytes = () {
  final source = img.Image(width: _photoWidth, height: _photoHeight);
  img.fill(source, color: img.ColorRgb8(120, 120, 120));
  return img.encodeJpg(source);
}();

class _FakePickService implements ImagePickService {
  ImageSource? requestedSource;

  @override
  Future<PickedFit?> pick(ImageSource source) async {
    requestedSource = source;
    return PickedFit(
      bytes: _photoBytes,
      fileExtension: 'jpg',
      width: _photoWidth,
      height: _photoHeight,
    );
  }

  @override
  Object noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<_FakeProfileController> _pumpEditProfile(
  WidgetTester tester, {
  String? displayName = 'Ada Lovelace',
  String? username = 'ada',
  String? avatarUrl,
  ImagePickService? pickService,
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
      overrides: [
        profileControllerProvider.overrideWith(() => controller),
        if (pickService != null)
          imagePickServiceProvider.overrideWithValue(pickService),
      ],
      child: CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                CupertinoPageRoute<bool>(
                  builder: (_) => EditProfilePage(
                    initialDisplayName: displayName,
                    initialUsername: username,
                    initialAvatarUrl: avatarUrl,
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

/// The cropper pushes the button below the fold on a test-sized screen.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Save changes'),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
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

  testWidgets('stages a picked photo and sends it with the save', (
    tester,
  ) async {
    final pickService = _FakePickService();
    final controller = await _pumpEditProfile(
      tester,
      pickService: pickService,
    );

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    expect(pickService.requestedSource, ImageSource.gallery);
    // A staged photo is a change on its own, with no field edited.
    expect(find.text('Change photo'), findsOneWidget);
    // ...and it is framed rather than blindly centre-cropped.
    expect(find.byType(AppImageCropper), findsOneWidget);

    await _tapSave(tester);

    expect(controller.saveCount, 1);
    expect(controller.savedAvatar?.bytes, _photoBytes);
    expect(controller.savedRemoveAvatar, isFalse);
    // The cropper reported a frame on layout, so the save carries one.
    expect(controller.savedAvatarCrop, isNotNull);
  });

  testWidgets('removes the saved photo', (tester) async {
    final controller = await _pumpEditProfile(
      tester,
      avatarUrl: 'https://example.test/avatar.jpg',
    );

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(find.text('Add photo'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(controller.savedRemoveAvatar, isTrue);
    expect(controller.savedAvatar, isNull);
  });

  testWidgets('offers no removal when there is no photo to remove', (
    tester,
  ) async {
    await _pumpEditProfile(tester);

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(find.text('Choose from library'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
  });

  testWidgets('sends the frame the user dragged, not the centered one', (
    tester,
  ) async {
    final controller = await _pumpEditProfile(
      tester,
      pickService: _FakePickService(),
    );

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    // Dragging the photo down reveals what was above the square.
    await tester.drag(find.byType(AppImageCropper), const Offset(0, 40));
    await tester.pump();
    await _tapSave(tester);

    final crop = controller.savedAvatarCrop;
    expect(crop, isNotNull);
    expect(crop!.width, moreOrLessEquals(_photoWidth.toDouble()));
    // The centered square would start 100px down; this one starts higher.
    expect(crop.top, lessThan(100));
    expect(crop.top, greaterThan(0));
  });
}
