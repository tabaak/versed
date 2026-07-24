import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_empty_state.dart';

/// Placeholder screen for submitting an outfit photo into the arena.
class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('VERSED', style: AppTextStyles.wordmark),
        border: null,
      ),
      child: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: AppEmptyState(
            icon: CupertinoIcons.camera,
            title: 'Upload your fit',
            message: 'Drop a photo of your outfit and let the arena decide.',
          ),
        ),
      ),
    );
  }
}
