import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_bar.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../upload/controllers/upload_controller.dart';
import '../../../upload/presentation/pages/upload_page.dart';
import '../../../versus/presentation/pages/versus_page.dart';

/// Signed-in shell: keeps each tab alive and swaps them via the tab bar.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  AppTab _activeTab = AppTab.versus;

  void _onTabSelected(AppTab tab) {
    // Tapping upload while already there is a "start over": drop the staged
    // photo so the tab shows its empty state again. Tabs are kept alive, so
    // without this the last pick would sit there until it was replaced.
    if (tab == _activeTab) {
      if (tab == AppTab.upload) {
        ref.read(uploadControllerProvider.notifier).clear();
      }
      return;
    }

    setState(() => _activeTab = tab);
  }

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
          AppTabBar(activeTab: _activeTab, onTabSelected: _onTabSelected),
        ],
      ),
    );
  }
}
