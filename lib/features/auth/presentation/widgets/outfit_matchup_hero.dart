import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class OutfitMatchupHero extends StatefulWidget {
  const OutfitMatchupHero({super.key});

  @override
  State<OutfitMatchupHero> createState() => _OutfitMatchupHeroState();
}

class _OutfitMatchupHeroState extends State<OutfitMatchupHero> {
  static const _matchups = [
    _OutfitMatchup(
      leftAsset: 'assets/auth/outfit1.png',
      rightAsset: 'assets/auth/outfit2.png',
      leftNumber: 1,
      rightNumber: 2,
      winner: _MatchupSide.right,
    ),
    _OutfitMatchup(
      leftAsset: 'assets/auth/outfit3.jpg',
      rightAsset: 'assets/auth/outfit4.jpg',
      leftNumber: 3,
      rightNumber: 4,
      winner: _MatchupSide.left,
    ),
    _OutfitMatchup(
      leftAsset: 'assets/auth/outfit5.jpg',
      rightAsset: 'assets/auth/outfit6.jpg',
      leftNumber: 5,
      rightNumber: 6,
      winner: _MatchupSide.right,
    ),
  ];

  Timer? _timer;
  int _matchupIndex = 0;
  bool _winnerRevealed = false;
  bool? _animationsDisabled;
  bool _imagesPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheOutfits();

    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) return;

    _animationsDisabled = animationsDisabled;
    _timer?.cancel();

    if (animationsDisabled) {
      _winnerRevealed = true;
    } else {
      _winnerRevealed = false;
      _scheduleNextStep();
    }
  }

  void _precacheOutfits() {
    if (_imagesPrecached) return;
    _imagesPrecached = true;

    for (final matchup in _matchups) {
      precacheImage(
        ResizeImage(
          AssetImage(matchup.leftAsset),
          width: 1000,
          allowUpscaling: false,
        ),
        context,
      );
      precacheImage(
        ResizeImage(
          AssetImage(matchup.rightAsset),
          width: 1000,
          allowUpscaling: false,
        ),
        context,
      );
    }
  }

  void _scheduleNextStep() {
    final delay = _winnerRevealed
        ? const Duration(milliseconds: 1400)
        : const Duration(milliseconds: 1600);

    _timer = Timer(delay, () {
      if (!mounted) return;

      setState(() {
        if (_winnerRevealed) {
          _matchupIndex = (_matchupIndex + 1) % _matchups.length;
          _winnerRevealed = false;
        } else {
          _winnerRevealed = true;
        }
      });

      _scheduleNextStep();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchup = _matchups[_matchupIndex];

    return Semantics(
      image: true,
      label: _winnerRevealed
          ? 'Outfit ${matchup.winnerNumber} wins the style battle'
          : 'Outfit ${matchup.leftNumber} versus outfit ${matchup.rightNumber}',
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _OutfitPair(
              key: ValueKey(_matchupIndex),
              matchup: matchup,
              winnerRevealed: _winnerRevealed,
              animationsDisabled: _animationsDisabled ?? false,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutfitPair extends StatelessWidget {
  const _OutfitPair({
    required this.matchup,
    required this.winnerRevealed,
    required this.animationsDisabled,
    super.key,
  });

  final _OutfitMatchup matchup;
  final bool winnerRevealed;
  final bool animationsDisabled;

  @override
  Widget build(BuildContext context) {
    final duration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 500);
    final versusFadeDuration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 100);
    final leftWins = winnerRevealed && matchup.winner == _MatchupSide.left;
    final rightWins = winnerRevealed && matchup.winner == _MatchupSide.right;

    return ColoredBox(
      color: AppColors.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leftFraction = leftWins
              ? 0.62
              : rightWins
              ? 0.38
              : 0.5;

          return Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    width: constraints.maxWidth * leftFraction,
                    child: _OutfitPhoto(
                      key: ValueKey('outfit-${matchup.leftNumber}'),
                      assetPath: matchup.leftAsset,
                      isWinner: leftWins,
                      isDimmed: rightWins,
                      duration: duration,
                    ),
                  ),
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    width: constraints.maxWidth * (1 - leftFraction),
                    child: _OutfitPhoto(
                      key: ValueKey('outfit-${matchup.rightNumber}'),
                      assetPath: matchup.rightAsset,
                      isWinner: rightWins,
                      isDimmed: leftWins,
                      duration: duration,
                    ),
                  ),
                ],
              ),
              Center(
                child: AnimatedOpacity(
                  duration: versusFadeDuration,
                  opacity: winnerRevealed ? 0 : 1,
                  child: Container(
                    width: 36,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.canvas, width: 2),
                    ),
                    child: const Text(
                      'VS',
                      style: AppTextStyles.matchupDivider,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OutfitPhoto extends StatelessWidget {
  const _OutfitPhoto({
    required this.assetPath,
    required this.isWinner,
    required this.isDimmed,
    required this.duration,
    super.key,
  });

  final String assetPath;
  final bool isWinner;
  final bool isDimmed;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: isWinner ? AppColors.accent : AppColors.canvas,
            width: isWinner ? 3 : 1,
          ),
        ),
        child: AnimatedOpacity(
          duration: duration,
          opacity: isDimmed ? 0.48 : 1,
          child: ExcludeSemantics(
            child: Image(
              image: ResizeImage(
                AssetImage(assetPath),
                width: 1000,
                allowUpscaling: false,
              ),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

enum _MatchupSide { left, right }

class _OutfitMatchup {
  const _OutfitMatchup({
    required this.leftAsset,
    required this.rightAsset,
    required this.leftNumber,
    required this.rightNumber,
    required this.winner,
  });

  final String leftAsset;
  final String rightAsset;
  final int leftNumber;
  final int rightNumber;
  final _MatchupSide winner;

  int get winnerNumber {
    return winner == _MatchupSide.left ? leftNumber : rightNumber;
  }
}
