import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/services/storage_service.dart';
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
  String? ownerHandle = '@styleuser',
  int viewCount = 42,
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
                viewCount: viewCount,
                isWinner: false,
                isLoser: false,
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

    final metadata = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(ContenderMetadata),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );

    expect(metadata.opacity, 0.82);
    expect(find.text('@styleuser'), findsOneWidget);
  });

  testWidgets('the owner handle is hidden before the card is highlighted', (
    tester,
  ) async {
    await _pumpCard(tester, isHighlighted: false);

    final metadata = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(ContenderMetadata),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );

    expect(metadata.opacity, 0);
    expect(find.bySemanticsLabel('@styleuser'), findsNothing);
  });

  testWidgets('a missing owner handle still shows the view count', (
    tester,
  ) async {
    await _pumpCard(tester, ownerHandle: null);

    expect(find.text('@styleuser'), findsNothing);
    expect(find.text('42'), findsOneWidget);
    expect(find.bySemanticsLabel('42 views'), findsOneWidget);
  });

  testWidgets('the completed view count appears at the bottom right', (
    tester,
  ) async {
    await _pumpCard(tester, viewCount: 1);

    expect(find.byIcon(CupertinoIcons.eye), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('1 view'), findsOneWidget);
  });

  testWidgets('all highlighted overlays share a softer opacity', (
    tester,
  ) async {
    await _pumpCard(tester);

    final bookmarkOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(SaveFitButton),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    final metadataOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(ContenderMetadata),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );

    expect(bookmarkOpacity.opacity, 0.82);
    expect(metadataOpacity.opacity, 0.82);
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
