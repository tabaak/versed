import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

enum AppTab { versus, upload, profile }

/// Bottom tab bar: versus and profile flank a raised upload action button.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.activeTab,
    required this.onTabSelected,
    super.key,
  });

  final AppTab activeTab;
  final ValueChanged<AppTab> onTabSelected;

  void _select(AppTab tab) {
    if (tab == activeTab) return;
    HapticFeedback.selectionClick();
    onTabSelected(tab);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _TabItem(
                icon: CupertinoIcons.square_split_2x1,
                activeIcon: CupertinoIcons.square_split_2x1_fill,
                label: 'Versus',
                isActive: activeTab == AppTab.versus,
                onPressed: () => _select(AppTab.versus),
              ),
              _UploadItem(
                isActive: activeTab == AppTab.upload,
                onPressed: () => _select(AppTab.upload),
              ),
              _TabItem(
                icon: CupertinoIcons.person,
                activeIcon: CupertinoIcons.person_fill,
                label: 'Profile',
                isActive: activeTab == AppTab.profile,
                onPressed: () => _select(AppTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.textPrimary : AppColors.textTertiary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isActive ? activeIcon : icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  height: 1,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadItem extends StatelessWidget {
  const _UploadItem({required this.isActive, required this.onPressed});

  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: 'Upload photo',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 48,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accent : AppColors.elevatedSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.add,
                size: 20,
                color: isActive ? AppColors.onAccent : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
