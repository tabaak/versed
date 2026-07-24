import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_text_styles.dart';

class AuthIntro extends StatelessWidget {
  const AuthIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Put your style\nto the test.',
      style: AppTextStyles.display,
    );
  }
}
