import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/auth_intro.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/outfit_matchup_hero.dart';
import '../widgets/versed_wordmark.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({this.onGoogleSignIn, this.isLoading = false, super.key});

  final VoidCallback? onGoogleSignIn;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 40.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VersedWordmark(),
                      const SizedBox(height: 20),
                      const Expanded(child: Center(child: OutfitMatchupHero())),
                      const SizedBox(height: 24),
                      const AuthIntro(),
                      const SizedBox(height: 24),
                      GoogleSignInButton(
                        isLoading: isLoading,
                        onPressed: onGoogleSignIn,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'By continuing, you agree to our Terms and '
                        'Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.meta,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
