import 'package:flutter/cupertino.dart';

import 'core/theme/app_colors.dart';
import 'core/presentation/pages/design_system_page.dart';

void main() => runApp(const VersedApp());

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
      home: DesignSystemPage(),
    );
  }
}
