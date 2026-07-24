import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_initializer.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';

Future<void> main() async {
  await AppInitializer.init();
  runApp(const ProviderScope(child: VersedApp()));
}

class VersedApp extends StatelessWidget {
  const VersedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
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
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        return CupertinoPageRoute<void>(
          settings: settings,
          builder: (_) => const AuthGate(),
        );
      },
    );
  }
}
