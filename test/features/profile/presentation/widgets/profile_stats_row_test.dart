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

/// The colour of one stat's value, found through the cell's own semantics
/// label so a number that appears twice in the row is not mistaken for the
/// other one.
Color? _colorOf(WidgetTester tester, String value, {required String label}) {
  final cell = find.byWidgetPredicate(
    (widget) =>
        widget is Semantics && widget.properties.label == '$label: $value',
  );

  return tester
      .widget<Text>(find.descendant(of: cell, matching: find.text(value)))
      .style
      ?.color;
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

  testWidgets('the streak is the only amber number in the row', (tester) async {
    await _pumpRow(
      tester,
      const ProfileStats(wins: 3, losses: 0, bestStreak: 3),
    );

    expect(_colorOf(tester, '3', label: 'Best streak'), AppColors.streak);
    expect(_colorOf(tester, '3', label: 'Wins'), AppColors.textPrimary);
    expect(_colorOf(tester, '0', label: 'Losses'), AppColors.textPrimary);
    expect(_colorOf(tester, '100%', label: 'Win rate'), AppColors.textPrimary);
  });

  testWidgets('a profile with no record yet gets no gold zero', (tester) async {
    await _pumpRow(tester, ProfileStats.empty);

    expect(_colorOf(tester, '0', label: 'Best streak'), AppColors.textPrimary);
  });

  testWidgets('a profile with no battles reads zero rather than blank', (
    tester,
  ) async {
    await _pumpRow(tester, ProfileStats.empty);

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
  });
}
