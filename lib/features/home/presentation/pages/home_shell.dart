import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_bar.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../upload/presentation/pages/upload_page.dart';
import '../../../versus/presentation/pages/versus_page.dart';

/// Signed-in shell: keeps each tab alive and swaps them via the tab bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _activeTab = AppTab.versus;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: Column(
        children: [
          Expanded(
            // The tab bar already covers the bottom safe-area inset, so the
            // tab pages must not reserve it again.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: IndexedStack(
                index: _activeTab.index,
                children: const [VersusPage(), UploadPage(), ProfilePage()],
              ),
            ),
          ),
          AppTabBar(
            activeTab: _activeTab,
            onTabSelected: (tab) => setState(() => _activeTab = tab),
          ),
        ],
      ),
    );
  }
}
