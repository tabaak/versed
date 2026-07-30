import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/services/storage_service.dart';
import 'package:versed/features/fits/models/fit.dart';
import 'package:versed/features/profile/presentation/widgets/profile_fits_grid.dart';

class _FakeStorageService implements StorageService {
  @override
  String fitImageUrl(String path) => 'https://cdn.test/fits/$path';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Each fit gets a distinct win rate, which is also its caption — that is
/// what makes an individual tile findable on screen.
List<Fit> _fits(int count) => [
  for (var i = 0; i < count; i++)
    Fit.empty.copyWith(
      id: 'fit-$i',
      ownerId: 'user-1',
      imagePath: 'user-1/fit-$i.jpg',
      wins: i,
      losses: 10 - i,
      ownerUsername: 'owner$i',
    ),
];

/// The vertical offset of every tile, in order.
List<double> _rowOffsets(WidgetTester tester, int count) => [
  for (var i = 0; i < count; i++) tester.getTopLeft(find.text('${i * 10}%')).dy,
];

Future<void> _pumpGrid(
  WidgetTester tester, {
  required double width,
  required int count,
  bool showOwner = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_FakeStorageService()),
      ],
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: ListView(
            children: [
              SizedBox(
                width: width,
                child: ProfileFitsGrid(
                  fits: _fits(count),
                  onFitTap: (_, _) {},
                  heroTagPrefix: 'test-fit',
                  showOwner: showOwner,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Widths that do not divide evenly by three are where a Wrap-based grid
  // spills a tile onto the next row, so sweep a realistic range of them.
  for (final width in [320.0, 360.0, 375.0, 390.0, 393.0, 428.0, 430.0]) {
    testWidgets('lays out three fits per row at ${width}pt', (tester) async {
      await _pumpGrid(tester, width: width, count: 7);

      final offsets = _rowOffsets(tester, 7);

      // Tiles 0-2 share a row, 3-5 share the next, 6 starts a third.
      expect(offsets[1], offsets[0]);
      expect(offsets[2], offsets[0]);
      expect(offsets[3], greaterThan(offsets[0]));
      expect(offsets[4], offsets[3]);
      expect(offsets[5], offsets[3]);
      expect(offsets[6], greaterThan(offsets[3]));
    });
  }

  testWidgets('saved fits stack three per row too, handle and all', (
    tester,
  ) async {
    await _pumpGrid(tester, width: 393, count: 7, showOwner: true);

    final offsets = _rowOffsets(tester, 7);

    expect(find.text('@owner0'), findsOneWidget);
    expect(offsets[2], offsets[0]);
    expect(offsets[3], greaterThan(offsets[0]));
    expect(offsets[5], offsets[3]);
  });

  testWidgets('a part-filled last row still starts at the left edge', (
    tester,
  ) async {
    await _pumpGrid(tester, width: 393, count: 4);

    expect(
      tester.getTopLeft(find.text('30%')).dx,
      tester.getTopLeft(find.text('0%')).dx,
    );
  });
}
