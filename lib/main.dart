import 'package:flutter/cupertino.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/presentation/pages/auth_page.dart';

void main() => runApp(const VersedApp());

void _handleGoogleSignIn() {}

class VersedApp extends StatelessWidget {
  const VersedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'VERSED',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.canvas,
        primaryColor: AppColors.accent,
        barBackgroundColor: AppColors.canvas,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: AuthPage(onGoogleSignIn: _handleGoogleSignIn),
    );
  }
}
