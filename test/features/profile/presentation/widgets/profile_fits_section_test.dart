import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/services/storage_service.dart';
import 'package:versed/features/fits/controllers/my_fits_controller.dart';
import 'package:versed/features/fits/controllers/saved_fits_controller.dart';
import 'package:versed/features/fits/models/fit.dart';
import 'package:versed/features/fits/presentation/widgets/fit_image.dart';
import 'package:versed/features/profile/presentation/widgets/profile_fits_section.dart';

class _FakeMyFits extends MyFitsController {
  _FakeMyFits(this.fits);

  final List<Fit> fits;

  @override
  Future<List<Fit>> build() async => fits;
}

class _FakeSavedFits extends SavedFitsController {
  _FakeSavedFits(this.fits);

  final List<Fit> fits;

  @override
  Future<List<Fit>> build() async => fits;
}

/// The grid only ever asks storage to turn a path into a URL; the image behind
/// it never loads in a test, and [FitImage] draws its own placeholder then.
class _FakeStorageService implements StorageService {
  @override
  String fitImageUrl(String path) => 'https://cdn.test/fits/$path';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _ownFit = Fit.empty.copyWith(
  id: 'own-1',
  ownerId: 'user-1',
  imagePath: 'user-1/own.jpg',
  wins: 3,
  losses: 2,
);

final _savedFit = Fit.empty.copyWith(
  id: 'saved-1',
  ownerId: 'user-2',
  imagePath: 'user-2/saved.jpg',
  wins: 7,
  losses: 1,
  ownerUsername: 'bob',
);

final _retiredFit = Fit.empty.copyWith(
  id: 'saved-2',
  ownerId: 'user-3',
  imagePath: 'user-3/gone.jpg',
  ownerUsername: 'cass',
  deletedAt: DateTime.utc(2026, 7, 1),
);

Future<List<Fit>> _pumpSection(
  WidgetTester tester, {
  List<Fit> own = const [],
  List<Fit> saved = const [],
}) async {
  final tapped = <Fit>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_FakeStorageService()),
        myFitsControllerProvider.overrideWith(() => _FakeMyFits(own)),
        savedFitsControllerProvider.overrideWith(() => _FakeSavedFits(saved)),
      ],
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: ListView(
            children: [
              ProfileFitsSection(
                onOwnFitTap: (fit, _) => tapped.add(fit),
                onSavedFitTap: (fit, _) => tapped.add(fit),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // One pump to let both controllers settle out of their loading state.
  await tester.pump();

  return tapped;
}

void main() {
  testWidgets('opens on the user own fits and counts both sections', (
    tester,
  ) async {
    await _pumpSection(tester, own: [_ownFit], saved: [_savedFit]);

    expect(find.text('Your fits  1'), findsOneWidget);
    expect(find.text('Saved  1'), findsOneWidget);

    // The own-fit win rate is on screen; the saved fit's owner is not.
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('@bob'), findsNothing);
  });

  testWidgets('switching to saved shows other people fits, with their handle', (
    tester,
  ) async {
    await _pumpSection(tester, own: [_ownFit], saved: [_savedFit]);

    await tester.tap(find.text('Saved  1'));
    await tester.pumpAndSettle();

    expect(find.text('@bob'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('60%'), findsNothing);
  });

  testWidgets('a retired fit keeps its tile and says so', (tester) async {
    await _pumpSection(tester, saved: [_retiredFit]);

    await tester.tap(find.text('Saved  1'));
    await tester.pumpAndSettle();

    expect(find.text('Retired'), findsOneWidget);
    // Nothing tries to render the purged photo.
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('tapping a saved tile hands the fit back to the page', (
    tester,
  ) async {
    final tapped = await _pumpSection(tester, saved: [_savedFit]);

    await tester.tap(find.text('Saved  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@bob'));

    expect(tapped, [_savedFit]);
  });

  testWidgets('both sections stack their fits three per row', (tester) async {
    final many = [
      for (var i = 0; i < 5; i++)
        Fit.empty.copyWith(
          id: 'fit-$i',
          ownerId: 'user-$i',
          imagePath: 'user-$i/fit.jpg',
          wins: i,
          losses: 10 - i,
          ownerUsername: 'owner$i',
        ),
    ];

    await _pumpSection(tester, own: many, saved: many);

    // The section sits inside a Column and an AnimatedSwitcher, either of
    // which could hand the grid looser constraints than the screen width.
    for (final _ in [0, 1]) {
      final offsets = [
        for (var i = 0; i < 5; i++)
          tester.getTopLeft(find.text('${i * 10}%')).dy,
      ];

      expect(offsets[1], offsets[0]);
      expect(offsets[2], offsets[0]);
      expect(offsets[3], greaterThan(offsets[0]));
      expect(offsets[4], offsets[3]);

      await tester.tap(find.text('Saved  5'));
      await tester.pumpAndSettle();
    }
  });

  // A row that does not fill leaves the Wrap narrower than the section, and
  // the AnimatedSwitcher around it centers loose children — so one or two
  // fits used to drift into the middle of the screen.
  for (final count in [1, 2]) {
    testWidgets('$count fit(s) start at the left edge, not the middle', (
      tester,
    ) async {
      final fits = [
        for (var i = 0; i < count; i++)
          Fit.empty.copyWith(
            id: 'fit-$i',
            ownerId: 'user-$i',
            imagePath: 'user-$i/fit.jpg',
            wins: i,
            ownerUsername: 'owner$i',
          ),
      ];

      await _pumpSection(tester, own: fits, saved: fits);

      final sectionLeft = tester.getTopLeft(find.byType(ProfileFitsSection)).dx;

      for (final _ in [0, 1]) {
        expect(tester.getTopLeft(find.byType(FitImage).first).dx, sectionLeft);

        await tester.tap(find.text('Saved  $count'));
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('an empty saved section explains how to fill it', (tester) async {
    await _pumpSection(tester, own: [_ownFit]);

    await tester.tap(find.text('Saved  0'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing saved yet'), findsOneWidget);
  });
}
