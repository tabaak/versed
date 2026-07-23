import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_widgets.dart';
import '../widgets/design_system_sections.dart';

class DesignSystemPage extends StatefulWidget {
  const DesignSystemPage({super.key});

  @override
  State<DesignSystemPage> createState() => _DesignSystemPageState();
}

class _DesignSystemPageState extends State<DesignSystemPage> {
  bool _toggleValue = true;
  bool _checkboxValue = false;

  void _showSuccessToast() {
    AppToast.success(context: context, message: 'Primary action confirmed.');
  }

  void _showTopNotification() {
    AppToast.error(
      context: context,
      message: 'Upload paused. Check your connection.',
    );
  }

  void _showBottomNotification() {
    AppToast.success(
      context: context,
      message: 'Outfit saved to your archive.',
    );
  }

  void _showModal() {
    AppModal.showBottomSheet<void>(
      context: context,
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(500),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Ready to enter?', style: AppTextStyles.screenTitle),
              const SizedBox(height: 8),
              const Text(
                'Your fit will be matched against another look.',
                textAlign: TextAlign.center,
                style: AppTextStyles.secondaryBody,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Confirm',
                onPressed: () => Navigator.of(modalContext).pop(),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Not Now',
                onPressed: () => Navigator.of(modalContext).pop(),
                variant: AppButtonVariant.secondary,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: Column(
        children: [
          AppNavigationBar(
            title: 'UI Catalog',
            trailing: AppIconButton(
              icon: CupertinoIcons.ellipsis,
              onPressed: _showModal,
              semanticLabel: 'More catalog actions',
              backgroundColor: AppColors.canvas,
            ),
          ),
          Expanded(
            child: AppListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                ButtonCatalogSection(
                  onPrimaryPressed: _showSuccessToast,
                  onSecondaryPressed: _showModal,
                  onIconPressed: _showSuccessToast,
                ),
                const SizedBox(height: 28),
                InputCatalogSection(
                  toggleValue: _toggleValue,
                  checkboxValue: _checkboxValue,
                  onToggleChanged: (value) {
                    setState(() => _toggleValue = value);
                  },
                  onCheckboxChanged: (value) {
                    setState(() => _checkboxValue = value);
                  },
                ),
                const SizedBox(height: 28),
                OverlayCatalogSection(
                  onShowModal: _showModal,
                  onShowTopNotification: _showTopNotification,
                  onShowBottomNotification: _showBottomNotification,
                ),
                const SizedBox(height: 28),
                const ListCatalogSection(),
                const SizedBox(height: 28),
                const AppSectionHeader(title: 'Empty State'),
                AppEmptyState(
                  icon: CupertinoIcons.photo_on_rectangle,
                  title: 'No battles yet',
                  message:
                      'Upload your first fit to enter the VERSED rotation.',
                  actionLabel: 'Upload Fit',
                  onAction: _showModal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
