import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_empty_state.dart';

/// Placeholder screen for the user's profile, fits, and battle record.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
            icon: CupertinoIcons.person,
            title: 'Your profile',
            message: 'Your fits, wins, and streaks will live here.',
          ),
        ),
      ),
    );
  }
}
