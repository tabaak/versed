import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/widgets/app_tab_bar.dart';

void main() {
  Future<List<AppTab>> pumpTabBar(WidgetTester tester, AppTab activeTab) async {
    final selections = <AppTab>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: AppTabBar(activeTab: activeTab, onTabSelected: selections.add),
      ),
    );

    return selections;
  }

  testWidgets('reports a tap on another tab', (tester) async {
    final selections = await pumpTabBar(tester, AppTab.versus);

    // The label sits on both the tab's Semantics wrapper and its text.
    await tester.tap(find.bySemanticsLabel('Profile').first);

    expect(selections, [AppTab.profile]);
  });

  testWidgets('reports a re-tap on the active tab', (tester) async {
    final selections = await pumpTabBar(tester, AppTab.upload);

    await tester.tap(find.bySemanticsLabel('Upload photo'));

    expect(selections, [AppTab.upload]);
  });
}
