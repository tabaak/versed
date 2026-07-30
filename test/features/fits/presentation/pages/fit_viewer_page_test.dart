import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/services/storage_service.dart';
import 'package:versed/features/fits/controllers/my_fits_controller.dart';
import 'package:versed/features/fits/controllers/saved_fits_controller.dart';
import 'package:versed/features/fits/models/fit.dart';
import 'package:versed/features/fits/presentation/pages/fit_viewer_page.dart';
import 'package:versed/features/fits/presentation/widgets/fit_image.dart';
import 'package:versed/features/fits/services/fit_service.dart';

class _FakeMyFits extends MyFitsController {
  _FakeMyFits(this.fits);

  final List<Fit> fits;

  /// The fits handed to [deleteFit], so a test can assert the menu retired the
  /// right one without a Supabase client anywhere near it.
  final List<Fit> retired = [];

  @override
  Future<List<Fit>> build() async => fits;

  @override
  Future<void> deleteFit(Fit fit) async => retired.add(fit);
}

class _FakeSavedFits extends SavedFitsController {
  _FakeSavedFits(this.fits);

  final List<Fit> fits;

  @override
  Future<List<Fit>> build() async => fits;
}

/// The viewer only ever asks storage to turn a path into a URL — the photo
/// itself never loads in a test, and [FitImage] draws its skeleton instead.
class _FakeStorageService implements StorageService {
  @override
  String fitImageUrl(String path) => 'https://cdn.test/fits/$path';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Records reports instead of sending them. Every other method is off limits:
/// the viewer reaching for one would be a mistake worth failing on.
class _FakeFitService implements FitService {
  _FakeFitService(this.onReport);

  final void Function(String fitId, FitReportReason reason) onReport;

  @override
  Future<void> report({
    required String fitId,
    required FitReportReason reason,
    String? note,
  }) async {
    onReport(fitId, reason);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _ownFit = Fit.empty.copyWith(
  id: 'own-1',
  ownerId: 'me',
  imagePath: 'me/one.jpg',
  wins: 7,
  losses: 3,
);

final _savedFit = Fit.empty.copyWith(
  id: 'saved-1',
  ownerId: 'someone',
  imagePath: 'someone/one.jpg',
  wins: 1,
  losses: 3,
  ownerUsername: 'nova',
);

/// Pumps a page whose only job is to open the viewer, so the Hero has a route
/// to fly out of the way it does from the profile grid.
Future<_FakeMyFits> _openViewer(
  WidgetTester tester, {
  required Fit fit,
  required bool isOwn,
  List<Fit> saved = const [],
  void Function(String fitId, FitReportReason reason)? onReport,
}) async {
  final myFits = _FakeMyFits([fit]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_FakeStorageService()),
        fitServiceProvider.overrideWithValue(
          _FakeFitService(onReport ?? (_, _) {}),
        ),
        myFitsControllerProvider.overrideWith(() => myFits),
        savedFitsControllerProvider.overrideWith(() => _FakeSavedFits(saved)),
      ],
      child: CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () => FitViewerPage.open(
                  context,
                  fit: fit,
                  heroTag: 'tile-${fit.id}',
                  isOwn: isOwn,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return myFits;
}

void main() {
  setUp(() {
    // The action sheet awaits a haptic before it presents, and an unmocked
    // platform channel never answers in a test — without this the overflow
    // menu simply never opens.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  testWidgets('shows views and win rate for your own fit', (tester) async {
    await _openViewer(tester, fit: _ownFit, isOwn: true);

    expect(find.byType(FitViewerPage), findsOneWidget);
    // 7 wins and 3 losses: ten battles seen, seventy percent of them won.
    expect(find.text('10'), findsOneWidget);
    expect(find.text('views'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('win rate'), findsOneWidget);
  });

  testWidgets('leaves the handle off your own fit', (tester) async {
    await _openViewer(tester, fit: _ownFit, isOwn: true);

    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets("shows the owner's handle on a saved fit", (tester) async {
    await _openViewer(tester, fit: _savedFit, isOwn: false);

    expect(find.text('@nova'), findsOneWidget);
  });

  testWidgets('offers to save a fit that is not saved yet', (tester) async {
    await _openViewer(tester, fit: _savedFit, isOwn: false);

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('reads as saved once the fit is in the saved list', (
    tester,
  ) async {
    await _openViewer(tester, fit: _savedFit, isOwn: false, saved: [_savedFit]);

    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('the overflow menu retires your own fit', (tester) async {
    final myFits = await _openViewer(tester, fit: _ownFit, isOwn: true);

    await tester.tap(find.bySemanticsLabel('More options'));
    await tester.pumpAndSettle();

    // Once to choose it, once to confirm it — retiring is not undoable.
    await tester.tap(find.text('Retire fit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retire fit'));
    await tester.pumpAndSettle();

    expect(myFits.retired, [_ownFit]);
    // Retiring closes the viewer — there is nothing left to look at.
    expect(find.byType(FitViewerPage), findsNothing);

    // Lets the confirmation toast time itself out; its dismissal timer would
    // otherwise still be pending when the tree is torn down.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('the overflow menu offers to report someone else\'s fit', (
    tester,
  ) async {
    await _openViewer(tester, fit: _savedFit, isOwn: false);

    await tester.tap(find.bySemanticsLabel('More options'));
    await tester.pumpAndSettle();

    expect(find.text('Report fit'), findsOneWidget);
    // Retiring is the owner's call, and a save is dropped with the bookmark
    // rather than from this menu.
    expect(find.text('Retire fit'), findsNothing);
    expect(find.text('Remove from saved'), findsNothing);
  });

  testWidgets('the overflow menu cannot report your own fit', (tester) async {
    await _openViewer(tester, fit: _ownFit, isOwn: true);

    await tester.tap(find.bySemanticsLabel('More options'));
    await tester.pumpAndSettle();

    expect(find.text('Report fit'), findsNothing);
  });

  testWidgets('your own fit can be saved to the gallery', (tester) async {
    await _openViewer(tester, fit: _ownFit, isOwn: true);

    await tester.tap(find.bySemanticsLabel('More options'));
    await tester.pumpAndSettle();

    expect(find.text('Save to gallery'), findsOneWidget);
  });

  testWidgets('a saved fit can be saved to the gallery too', (tester) async {
    await _openViewer(tester, fit: _savedFit, isOwn: false);

    await tester.tap(find.bySemanticsLabel('More options'));
    await tester.pumpAndSettle();

    expect(find.text('Save to gallery'), findsOneWidget);
  });

  testWidgets('picking a report reason sends it', (tester) async {
    final reported = <(String, FitReportReason)>[];
    await _openViewer(
      tester,
      fit: _savedFit,
      isOwn: false,
      onReport: (fitId, reason) => reported.add((fitId, reason)),
    );

    await tester.tap(find.bySemanticsLabel('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report fit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(FitReportReason.spam.label));
    await tester.pumpAndSettle();

    expect(reported, [(_savedFit.id, FitReportReason.spam)]);

    // Lets the confirmation toast time itself out.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a tap on the backdrop closes the viewer', (tester) async {
    await _openViewer(tester, fit: _ownFit, isOwn: true);

    // Top-left corner: outside the photo, outside every control.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(FitViewerPage), findsNothing);
  });

  testWidgets('a downward fling dismisses the viewer', (tester) async {
    await _openViewer(tester, fit: _ownFit, isOwn: true);

    await tester.fling(find.byType(FitImage), const Offset(0, 300), 1200);
    await tester.pumpAndSettle();

    expect(find.byType(FitViewerPage), findsNothing);
  });
}
