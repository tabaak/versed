import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/theme/app_colors.dart';
import 'package:versed/features/profile/models/profile_model.dart';
import 'package:versed/features/profile/presentation/widgets/profile_stats_row.dart';

Future<void> _pumpRow(WidgetTester tester, ProfileStats stats) {
  return tester.pumpWidget(
    CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(child: ProfileStatsRow(stats: stats)),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the best streak rather than a live one', (tester) async {
    await _pumpRow(
      tester,
      const ProfileStats(wins: 12, losses: 4, bestStreak: 7),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
  });

  testWidgets('stays monochrome — amber belongs to a live run on a fit', (
    tester,
  ) async {
    await _pumpRow(
      tester,
      const ProfileStats(wins: 3, losses: 0, bestStreak: 3),
    );

    final values = tester.widgetList<Text>(find.byType(Text));
    for (final text in values) {
      expect(text.style?.color, isNot(AppColors.streak));
    }
  });

  testWidgets('a profile with no battles reads zero rather than blank', (
    tester,
  ) async {
    await _pumpRow(tester, ProfileStats.empty);

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
  });
}
