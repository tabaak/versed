import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/theme/app_colors.dart';
import 'package:versed/core/widgets/app_island.dart';

/// Pumps a page with a button that raises an island, and taps it.
///
/// [viewPaddingTop] stands in for the hardware: 59 is what every Dynamic
/// Island iPhone reports, and anything less is a notch or a flat top.
Future<void> _raiseIsland(
  WidgetTester tester, {
  String message = 'Fit retired.',
  AppIslandStatus status = AppIslandStatus.success,
  double viewPaddingTop = 59,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewPadding: EdgeInsets.only(top: viewPaddingTop),
          padding: EdgeInsets.only(top: viewPaddingTop),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () => AppIsland.show(
                context: context,
                message: message,
                status: status,
              ),
              child: const Text('raise'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('raise'));

  // Two frames, both of which leave the island closed: the first builds the
  // overlay and starts the spring from its post-frame callback, and a ticker's
  // opening tick is always a zero-length one. Only after this does advancing
  // the clock actually move the animation.
  await tester.pump();
  await tester.pump();
}

/// The pill's own box — the one whose size the spring drives.
Size _islandSize(WidgetTester tester) {
  return tester.getSize(find.byKey(AppIsland.shapeKey));
}

void main() {
  testWidgets('opens from the hardware footprint rather than full size', (
    tester,
  ) async {
    await _raiseIsland(tester, message: 'A message long enough to expand.');

    // The frame it appears on, it is still the size of the cutout.
    final atRest = _islandSize(tester);
    expect(atRest.width, closeTo(126, 1));

    await tester.pump(const Duration(milliseconds: 150));
    expect(_islandSize(tester).width, greaterThan(atRest.width));

    await tester.pumpAndSettle();
  });

  testWidgets('settles wider than it started and shows the message', (
    tester,
  ) async {
    await _raiseIsland(tester, message: 'Saved to your gallery.');
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Saved to your gallery.'), findsOneWidget);
    expect(_islandSize(tester).width, greaterThan(126));

    await tester.pumpAndSettle();
  });

  testWidgets('collapses and removes itself once its time is up', (
    tester,
  ) async {
    await _raiseIsland(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Fit retired.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Fit retired.'), findsNothing);
  });

  testWidgets('a tap dismisses it early', (tester) async {
    await _raiseIsland(tester);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Fit retired.'));
    await tester.pumpAndSettle();

    expect(find.text('Fit retired.'), findsNothing);
  });

  testWidgets('a second message replaces the first instead of stacking', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoButton(
                    onPressed: () =>
                        AppIsland.success(context: context, message: 'First'),
                    child: const Text('first'),
                  ),
                  CupertinoButton(
                    onPressed: () =>
                        AppIsland.error(context: context, message: 'Second'),
                    child: const Text('second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('first'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('First'), findsOneWidget);

    await tester.tap(find.text('second'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('keeps its content clear of the Dynamic Island cutout', (
    tester,
  ) async {
    await _raiseIsland(tester, message: 'Saved to your gallery.');
    await tester.pump(const Duration(milliseconds: 600));

    // The cutout is opaque hardware occupying y 11 through 48.33. Anything
    // drawn above that line is behind the sensors and invisible on a real
    // phone, however correct it looks in a simulator screenshot.
    const cutoutBottom = 11 + 37.33;
    expect(
      tester.getTopLeft(find.text('Saved to your gallery.')).dy,
      greaterThanOrEqualTo(cutoutBottom),
    );
    expect(
      tester.getTopLeft(find.byType(Icon)).dy,
      greaterThanOrEqualTo(cutoutBottom),
    );

    // And the island itself has grown down past the cutout to make room.
    expect(_islandSize(tester).height, greaterThan(37.33));

    await tester.pumpAndSettle();
  });

  testWidgets('sits below the status bar where there is no cutout', (
    tester,
  ) async {
    await _raiseIsland(tester, viewPaddingTop: 20);
    await tester.pump(const Duration(milliseconds: 600));

    // 20pt of status bar plus the 8pt gap the fallback leaves.
    expect(tester.getTopLeft(find.text('Fit retired.')).dy, greaterThan(28));

    await tester.pumpAndSettle();
  });

  testWidgets('opens instantly when animations are switched off', (
    tester,
  ) async {
    await _raiseIsland(tester, disableAnimations: true);
    // A single frame, no time advanced: with motion off it is already open.
    await tester.pump();

    expect(_islandSize(tester).width, greaterThan(126));

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('carries the status colour into its icon', (tester) async {
    await _raiseIsland(tester, status: AppIslandStatus.error);
    await tester.pump(const Duration(milliseconds: 600));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppColors.error);

    await tester.pumpAndSettle();
  });
}
