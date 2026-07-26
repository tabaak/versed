import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

enum AppTab { versus, upload, profile }

const _indicatorDuration = Duration(milliseconds: 320);
const _indicatorCurve = Curves.easeOutCubic;

/// Bottom tab bar: versus and profile flank a raised upload action button.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.activeTab,
    required this.onTabSelected,
    super.key,
  });

  final AppTab activeTab;

  /// Fires on every tap, including a tap on the tab that is already active —
  /// a re-tap is how a tab is reset to its starting screen.
  final ValueChanged<AppTab> onTabSelected;

  void _select(AppTab tab) {
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
          child: Stack(
            children: [
              _SlidingIndicator(activeTab: activeTab),
              Row(
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill that glides along the top edge to sit above the active tab.
class _SlidingIndicator extends StatelessWidget {
  const _SlidingIndicator({required this.activeTab});

  final AppTab activeTab;

  static const _width = 50.0;

  /// Tabs share the row equally, so their centres land at 1/6, 1/2 and 5/6.
  double get _centreFraction => switch (activeTab) {
    AppTab.versus => 1 / 6,
    AppTab.upload => 1 / 2,
    AppTab.profile => 5 / 6,
  };

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: _centreFraction, end: _centreFraction),
            duration: _indicatorDuration,
            curve: _indicatorCurve,
            builder: (context, fraction, child) => Stack(
              children: [
                Positioned(
                  top: 0,
                  left: constraints.maxWidth * fraction - _width / 2,
                  child: child!,
                ),
              ],
            ),
            child: Container(
              width: _width,
              height: 3,
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(2)),
              ),
            ),
          );
        },
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  height: 1,
                  letterSpacing: 0.2,
                ),
                child: Text(label),
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
