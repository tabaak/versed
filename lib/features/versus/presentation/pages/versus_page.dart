import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Main matchup screen: two outfits battle, double-tap picks the winner.
class VersusPage extends StatefulWidget {
  const VersusPage({super.key});

  @override
  State<VersusPage> createState() => _VersusPageState();
}

class _VersusPageState extends State<VersusPage> {
  static const _matchups = [
    _VersusMatchup(
      topAsset: 'assets/auth/outfit1.png',
      bottomAsset: 'assets/auth/outfit2.png',
    ),
    _VersusMatchup(
      topAsset: 'assets/auth/outfit3.jpg',
      bottomAsset: 'assets/auth/outfit4.jpg',
    ),
    _VersusMatchup(
      topAsset: 'assets/auth/outfit5.jpg',
      bottomAsset: 'assets/auth/outfit6.jpg',
    ),
  ];

  static const _winnerRevealDuration = Duration(milliseconds: 900);

  Timer? _advanceTimer;
  int _matchupIndex = 0;
  _VersusSide? _winner;
  bool _imagesPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheOutfits();
  }

  void _precacheOutfits() {
    if (_imagesPrecached) return;
    _imagesPrecached = true;

    for (final matchup in _matchups) {
      precacheImage(
        ResizeImage(
          AssetImage(matchup.topAsset),
          width: 1000,
          allowUpscaling: false,
        ),
        context,
      );
      precacheImage(
        ResizeImage(
          AssetImage(matchup.bottomAsset),
          width: 1000,
          allowUpscaling: false,
        ),
        context,
      );
    }
  }

  void _pickWinner(_VersusSide side) {
    if (_winner != null) return;

    setState(() => _winner = side);

    final revealDelay = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 300)
        : _winnerRevealDuration;

    _advanceTimer = Timer(revealDelay, () {
      if (!mounted) return;
      setState(() {
        _matchupIndex = (_matchupIndex + 1) % _matchups.length;
        _winner = null;
      });
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchup = _matchups[_matchupIndex];
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('VERSED', style: AppTextStyles.wordmark),
        border: null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: animationsDisabled
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _MatchupBoard(
                    key: ValueKey(_matchupIndex),
                    matchup: matchup,
                    winner: _winner,
                    animationsDisabled: animationsDisabled,
                    onPickWinner: _pickWinner,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _winner == null
                    ? 'Double-tap the outfit that wins'
                    : 'Winner locked in',
                style: AppTextStyles.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchupBoard extends StatelessWidget {
  const _MatchupBoard({
    required this.matchup,
    required this.winner,
    required this.animationsDisabled,
    required this.onPickWinner,
    super.key,
  });

  final _VersusMatchup matchup;
  final _VersusSide? winner;
  final bool animationsDisabled;
  final ValueChanged<_VersusSide> onPickWinner;

  @override
  Widget build(BuildContext context) {
    final duration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            Expanded(
              child: _VersusContender(
                assetPath: matchup.topAsset,
                isWinner: winner == _VersusSide.top,
                isLoser: winner == _VersusSide.bottom,
                duration: duration,
                semanticLabel: 'Top outfit',
                onDoubleTap: () => onPickWinner(_VersusSide.top),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _VersusContender(
                assetPath: matchup.bottomAsset,
                isWinner: winner == _VersusSide.bottom,
                isLoser: winner == _VersusSide.top,
                duration: duration,
                semanticLabel: 'Bottom outfit',
                onDoubleTap: () => onPickWinner(_VersusSide.bottom),
              ),
            ),
          ],
        ),
        AnimatedOpacity(
          duration: animationsDisabled
              ? Duration.zero
              : const Duration(milliseconds: 150),
          opacity: winner == null ? 1 : 0,
          child: Container(
            width: 44,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.canvas, width: 2),
            ),
            child: const Text('VS', style: AppTextStyles.matchupDivider),
          ),
        ),
      ],
    );
  }
}

class _VersusContender extends StatelessWidget {
  const _VersusContender({
    required this.assetPath,
    required this.isWinner,
    required this.isLoser,
    required this.duration,
    required this.semanticLabel,
    required this.onDoubleTap,
  });

  final String assetPath;
  final bool isWinner;
  final bool isLoser;
  final Duration duration;
  final String semanticLabel;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isWinner
          ? '$semanticLabel, winner'
          : '$semanticLabel, double-tap to pick as winner',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: onDoubleTap,
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOutBack,
          scale: isWinner
              ? 1.05
              : isLoser
              ? 0.92
              : 1,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOut,
            opacity: isLoser ? 0.35 : 1,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWinner ? AppColors.accent : AppColors.divider,
                  width: isWinner ? 3 : 1,
                ),
                boxShadow: isWinner
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 24,
                        ),
                      ]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: ExcludeSemantics(
                  child: Image(
                    image: ResizeImage(
                      AssetImage(assetPath),
                      width: 1000,
                      allowUpscaling: false,
                    ),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _VersusSide { top, bottom }

class _VersusMatchup {
  const _VersusMatchup({required this.topAsset, required this.bottomAsset});

  final String topAsset;
  final String bottomAsset;
}
