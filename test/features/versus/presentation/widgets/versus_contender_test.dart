import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/services/storage_service.dart';
import 'package:versed/core/widgets/app_crown_icon.dart';
import 'package:versed/features/fits/controllers/saved_fits_controller.dart';
import 'package:versed/features/fits/models/fit.dart';
import 'package:versed/features/versus/presentation/widgets/contender_metadata.dart';
import 'package:versed/features/versus/presentation/widgets/versus_contender.dart';

class _FakeSavedFits extends SavedFitsController {
  _FakeSavedFits(this.fits);

  final List<Fit> fits;

  @override
  Future<List<Fit>> build() async => fits;
}

class _FakeStorageService implements StorageService {
  @override
  String fitImageUrl(String path) => 'https://cdn.test/fits/$path';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _fitId = 'fit-1';

/// Pumps a single card and reports what each of its gestures fired.
Future<({List<String> events})> _pumpCard(
  WidgetTester tester, {
  List<Fit> saved = const [],
  bool isHighlighted = true,
  bool isWinner = false,
  bool isLoser = false,
  String? ownerHandle = '@styleuser',
  int winCount = 42,
  int streak = 0,
}) async {
  final events = <String>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_FakeStorageService()),
        savedFitsControllerProvider.overrideWith(() => _FakeSavedFits(saved)),
      ],
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 240,
              height: 300,
              child: VersusContender(
                fitId: _fitId,
                imagePath: 'user-1/fit.jpg',
                ownerHandle: ownerHandle,
                winCount: winCount,
                streak: streak,
                isWinner: isWinner,
                isLoser: isLoser,
                isHighlighted: isHighlighted,
                isDimmed: false,
                duration: Duration.zero,
                skeletonPhase: 0,
                semanticLabel: 'Bottom left outfit',
                onTapDown: (_) => events.add('vote'),
                onLongPress: () => events.add('long-press'),
                onToggleSave: () => events.add('save'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  return (events: events);
}

/// The fade the card wraps [target] in. Nearest first: the card's own fade-out
/// for a lost round sits further up the tree.
double _opacityAround(WidgetTester tester, Finder target) {
  return tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: target, matching: find.byType(AnimatedOpacity)).first,
      )
      .opacity;
}

void main() {
  testWidgets('the bookmark takes the tap instead of the vote surface', (
    tester,
  ) async {
    final result = await _pumpCard(tester);

    await tester.tap(find.byType(SaveFitButton));
    await tester.pump();

    expect(result.events, ['save']);
  });

  testWidgets('the bookmark is hidden until the card is tapped once', (
    tester,
  ) async {
    final result = await _pumpCard(tester, isHighlighted: false);

    final opacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(SaveFitButton),
            matching: find.byType(AnimatedOpacity),
          )
          // Nearest first: the card's own fade-out for a lost round is further
          // up the tree.
          .first,
    );
    expect(opacity.opacity, 0);

    // Invisible means untouchable: the tap belongs to the card underneath.
    await tester.tap(find.byType(SaveFitButton), warnIfMissed: false);
    await tester.pump();

    expect(result.events, ['vote']);
  });

  testWidgets('tapping the photo still votes', (tester) async {
    final result = await _pumpCard(tester);

    await tester.tap(find.byType(VersusContender));
    await tester.pump();

    expect(result.events, ['vote']);
  });

  testWidgets('the owner handle appears after one tap highlights the card', (
    tester,
  ) async {
    await _pumpCard(tester);

    expect(_opacityAround(tester, find.text('@styleuser')), 0.82);
    expect(find.text('@styleuser'), findsOneWidget);
  });

  testWidgets('the owner handle is hidden before the card is highlighted', (
    tester,
  ) async {
    await _pumpCard(tester, isHighlighted: false);

    expect(_opacityAround(tester, find.text('@styleuser')), 0);
    expect(find.bySemanticsLabel('@styleuser'), findsNothing);
  });

  testWidgets('a missing owner handle still shows the win count', (
    tester,
  ) async {
    await _pumpCard(tester, ownerHandle: null);

    expect(find.textContaining('@'), findsNothing);
    expect(find.text('42'), findsOneWidget);
    expect(find.bySemanticsLabel('42 wins'), findsOneWidget);
  });

  testWidgets('the win count appears with a crown at the bottom right', (
    tester,
  ) async {
    await _pumpCard(tester, winCount: 1);

    expect(find.byType(AppCrownIcon), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('1 win'), findsOneWidget);

    final position = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.byType(AppCrownIcon),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(position.right, 8);
    expect(position.bottom, 4);
  });

  testWidgets('all highlighted overlays share a softer opacity', (
    tester,
  ) async {
    await _pumpCard(tester);

    expect(_opacityAround(tester, find.byType(SaveFitButton)), 0.82);
    expect(_opacityAround(tester, find.byType(AppCrownIcon)), 0.82);
  });

  testWidgets('a run of two or more is badged once the card wins', (
    tester,
  ) async {
    await _pumpCard(tester, streak: 3, isWinner: true, isHighlighted: false);

    expect(_opacityAround(tester, find.byType(StreakChip)), 0.82);
    expect(find.bySemanticsLabel('3 wins in a row'), findsOneWidget);
  });

  testWidgets('a single win is not a streak', (tester) async {
    await _pumpCard(tester, streak: 1, isWinner: true, isHighlighted: false);

    expect(find.byType(StreakChip), findsNothing);
  });

  testWidgets('a fit with no run at all is not badged', (tester) async {
    await _pumpCard(tester, streak: 0, isWinner: true, isHighlighted: false);

    expect(find.byType(StreakChip), findsNothing);
  });

  testWidgets('the streak stays hidden while the card is merely highlighted', (
    tester,
  ) async {
    // Seeing a run before voting would nudge the vote, so the badge waits for
    // the crown even though the handle and win count are already out.
    await _pumpCard(tester, streak: 4);

    expect(_opacityAround(tester, find.byType(StreakChip)), 0);
    expect(_opacityAround(tester, find.byType(AppCrownIcon)), 0.82);
    expect(find.bySemanticsLabel('4 wins in a row'), findsNothing);
  });

  testWidgets('the streak takes the corner the win count had', (tester) async {
    await _pumpCard(tester, streak: 4, isWinner: true, isHighlighted: false);

    Positioned cornerOf(Finder target) => tester.widget<Positioned>(
      find.ancestor(of: target, matching: find.byType(Positioned)).first,
    );

    final streakCorner = cornerOf(find.byType(StreakChip));
    final winsCorner = cornerOf(find.byType(AppCrownIcon));

    expect(streakCorner.right, winsCorner.right);
    expect(streakCorner.bottom, winsCorner.bottom);
    // ...and the win count is out of the way while it is there.
    expect(_opacityAround(tester, find.byType(AppCrownIcon)), 0);
  });

  testWidgets('the losing card is not badged for the run it just ended', (
    tester,
  ) async {
    await _pumpCard(tester, streak: 4, isLoser: true, isHighlighted: false);

    expect(_opacityAround(tester, find.byType(StreakChip)), 0);
  });

  testWidgets('an already saved fit shows a filled bookmark', (tester) async {
    await _pumpCard(
      tester,
      saved: [Fit.empty.copyWith(id: _fitId, ownerId: 'user-2')],
    );

    expect(
      find.descendant(
        of: find.byType(SaveFitButton),
        matching: find.byIcon(CupertinoIcons.bookmark_fill),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Remove from saved'), findsOneWidget);
  });

  testWidgets('an unsaved fit offers to save it', (tester) async {
    await _pumpCard(tester);

    expect(
      find.descendant(
        of: find.byType(SaveFitButton),
        matching: find.byIcon(CupertinoIcons.bookmark),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Save this fit'), findsOneWidget);
  });
}
