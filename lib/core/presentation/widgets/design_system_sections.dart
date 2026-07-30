import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_widgets.dart';

class ButtonCatalogSection extends StatelessWidget {
  const ButtonCatalogSection({
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
    required this.onIconPressed,
    super.key,
  });

  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;
  final VoidCallback onIconPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Actions'),
        AppButton(label: 'Primary Action', onPressed: onPrimaryPressed),
        const SizedBox(height: 12),
        AppButton(
          label: 'Secondary Action',
          onPressed: onSecondaryPressed,
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            AppIconButton(
              icon: CupertinoIcons.add,
              onPressed: onIconPressed,
              semanticLabel: 'Add',
            ),
            const SizedBox(width: 12),
            const AppIconButton(
              icon: CupertinoIcons.heart,
              onPressed: null,
              semanticLabel: 'Favorite unavailable',
            ),
          ],
        ),
      ],
    );
  }
}

class InputCatalogSection extends StatelessWidget {
  const InputCatalogSection({
    required this.toggleValue,
    required this.checkboxValue,
    required this.onToggleChanged,
    required this.onCheckboxChanged,
    super.key,
  });

  final bool toggleValue;
  final bool checkboxValue;
  final ValueChanged<bool> onToggleChanged;
  final ValueChanged<bool> onCheckboxChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Inputs'),
        const AppTextField(
          placeholder: 'Add style tags (#streetwear, #thrift)…',
          semanticLabel: 'Style tags',
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        _ControlRow(
          label: 'Live battle alerts',
          control: AppToggleSwitch(
            value: toggleValue,
            onChanged: onToggleChanged,
            semanticLabel: 'Live battle alerts',
          ),
        ),
        const SizedBox(height: 8),
        _ControlRow(
          label: 'Include archived battles',
          control: AppCheckbox(
            value: checkboxValue,
            onChanged: onCheckboxChanged,
            semanticLabel: 'Include archived battles',
          ),
        ),
      ],
    );
  }
}

class OverlayCatalogSection extends StatelessWidget {
  const OverlayCatalogSection({
    required this.onShowModal,
    required this.onShowIsland,
    super.key,
  });

  final VoidCallback onShowModal;
  final ValueChanged<AppIslandStatus> onShowIsland;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Overlays'),
        AppButton(label: 'Open Native Sheet', onPressed: onShowModal),
        const SizedBox(height: 12),
        // The island has no static state worth previewing — it is the opening
        // and closing that is the component, so the catalog only offers ways
        // to fire it.
        Row(
          children: [
            for (final status in AppIslandStatus.values) ...[
              if (status != AppIslandStatus.values.first)
                const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: switch (status) {
                    AppIslandStatus.neutral => 'Neutral',
                    AppIslandStatus.success => 'Success',
                    AppIslandStatus.error => 'Error',
                  },
                  onPressed: () => onShowIsland(status),
                  variant: AppButtonVariant.secondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class ListCatalogSection extends StatelessWidget {
  const ListCatalogSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Bouncing List'),
        SizedBox(
          height: 132,
          child: AppListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return Container(
                width: 116,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${72 + index * 3}%',
                      style: AppTextStyles.tabularMetric.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text('WIN RATE', style: AppTextStyles.meta),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.label, required this.control});

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          control,
        ],
      ),
    );
  }
}
