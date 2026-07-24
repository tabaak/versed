import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
      leftAsset: 'assets/auth/outfit1.png',
      rightAsset: 'assets/auth/outfit2.png',
    ),
    _VersusMatchup(
      leftAsset: 'assets/auth/outfit3.jpg',
      rightAsset: 'assets/auth/outfit4.jpg',
    ),
    _VersusMatchup(
      leftAsset: 'assets/auth/outfit5.jpg',
      rightAsset: 'assets/auth/outfit6.jpg',
    ),
  ];

  static const _winnerRevealDuration = Duration(milliseconds: 900);
  static const _doubleTapWindow = Duration(milliseconds: 350);
  static const _highlightTimeout = Duration(milliseconds: 1500);
  static const _burstEmojis = ['🔥', '✨', '⚡', '💯', '👀', '👏'];

  final _boardKey = GlobalKey();
  final _random = Random();

  Timer? _advanceTimer;
  Timer? _highlightTimer;
  int _matchupIndex = 0;
  _VersusSide? _winner;
  _VersusSide? _highlighted;
  _VersusSide? _lastTapSide;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_EmojiBurst> _bursts = [];
  int _nextBurstId = 0;
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
      precacheImage(AssetImage(matchup.leftAsset), context);
      precacheImage(AssetImage(matchup.rightAsset), context);
    }
  }

  void _handleTapDown(_VersusSide side, Offset globalPosition) {
    if (_winner != null) return;

    final now = DateTime.now();
    final isDoubleTap =
        _lastTapSide == side && now.difference(_lastTapTime) < _doubleTapWindow;
    _lastTapSide = side;
    _lastTapTime = now;

    if (isDoubleTap) {
      HapticFeedback.mediumImpact();
      if (!MediaQuery.disableAnimationsOf(context)) {
        _spawnBurst(globalPosition);
      }
      _pickWinner(side);
    } else {
      HapticFeedback.selectionClick();
      _highlightTimer?.cancel();
      _highlightTimer = Timer(_highlightTimeout, () {
        if (!mounted) return;
        setState(() => _highlighted = null);
      });
      setState(() => _highlighted = side);
    }
  }

  void _spawnBurst(Offset globalPosition) {
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null) return;

    final origin = board.globalToLocal(globalPosition);
    final emoji = _burstEmojis[_random.nextInt(_burstEmojis.length)];

    setState(() {
      for (var i = 0; i < 3; i++) {
        // Random launch angle within an upward fan; gravity does the rest.
        final angle = -pi / 2 + (_random.nextDouble() - 0.5) * pi * 0.9;
        final speed = 120 + _random.nextDouble() * 120;
        _bursts.add(
          _EmojiBurst(
            id: _nextBurstId++,
            position: origin,
            emoji: emoji,
            velocity: Offset(cos(angle), sin(angle)) * speed,
            tilt: (_random.nextDouble() - 0.5) * 1.2,
          ),
        );
      }
    });
  }

  void _removeBurst(int id) {
    if (!mounted) return;
    setState(() => _bursts.removeWhere((burst) => burst.id == id));
  }

  void _pickWinner(_VersusSide side) {
    if (_winner != null) return;

    _highlightTimer?.cancel();
    setState(() {
      _winner = side;
      _highlighted = null;
    });

    final revealDelay = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 300)
        : _winnerRevealDuration;

    _advanceTimer = Timer(revealDelay, () {
      if (!mounted) return;
      setState(() {
        _matchupIndex = (_matchupIndex + 1) % _matchups.length;
        _winner = null;
        _lastTapSide = null;
      });
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _highlightTimer?.cancel();
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
                child: Stack(
                  key: _boardKey,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
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
                          highlighted: _highlighted,
                          animationsDisabled: animationsDisabled,
                          onTapDown: _handleTapDown,
                        ),
                      ),
                    ),
                    for (final burst in _bursts)
                      _EmojiBurstParticle(
                        key: ValueKey(burst.id),
                        burst: burst,
                        onCompleted: () => _removeBurst(burst.id),
                      ),
                  ],
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
    required this.highlighted,
    required this.animationsDisabled,
    required this.onTapDown,
    super.key,
  });

  final _VersusMatchup matchup;
  final _VersusSide? winner;
  final _VersusSide? highlighted;
  final bool animationsDisabled;
  final void Function(_VersusSide side, Offset globalPosition) onTapDown;

  @override
  Widget build(BuildContext context) {
    final duration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cards sit diagonally (bottom-left vs top-right) and overlap a
        // little vertically, so each one can be far larger than in a
        // side-by-side split.
        const aspectRatio = 4 / 5;
        const overlapFraction = 0.06;

        final cardWidth = min(
          0.74 * constraints.maxWidth,
          constraints.maxHeight * aspectRatio / (2 - overlapFraction),
        );
        final cardHeight = cardWidth / aspectRatio;
        final pairHeight = (2 - overlapFraction) * cardHeight;
        final topInset = (constraints.maxHeight - pairHeight) / 2;

        final leftCard = Positioned(
          left: 0,
          top: topInset + (1 - overlapFraction) * cardHeight,
          width: cardWidth,
          height: cardHeight,
          child: _VersusContender(
            assetPath: matchup.leftAsset,
            isWinner: winner == _VersusSide.left,
            isLoser: winner == _VersusSide.right,
            isHighlighted: highlighted == _VersusSide.left,
            duration: duration,
            semanticLabel: 'Bottom left outfit',
            onTapDown: (globalPosition) =>
                onTapDown(_VersusSide.left, globalPosition),
          ),
        );
        final rightCard = Positioned(
          right: 0,
          top: topInset,
          width: cardWidth,
          height: cardHeight,
          child: _VersusContender(
            assetPath: matchup.rightAsset,
            isWinner: winner == _VersusSide.right,
            isLoser: winner == _VersusSide.left,
            isHighlighted: highlighted == _VersusSide.right,
            duration: duration,
            semanticLabel: 'Top right outfit',
            onTapDown: (globalPosition) =>
                onTapDown(_VersusSide.right, globalPosition),
          ),
        );

        // The active card (winner, or highlighted) renders on top.
        final leftOnTop =
            winner == _VersusSide.left ||
            (winner == null && highlighted == _VersusSide.left);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (leftOnTop) ...[
              rightCard,
              leftCard,
            ] else ...[
              leftCard,
              rightCard,
            ],
            // The badge sits in the free column right of the bottom card,
            // level with the seam between the two cards.
            Positioned(
              left: cardWidth - 44 + (constraints.maxWidth - cardWidth) / 2 + 2,
              top: topInset + pairHeight / 2 - 16 + 31,
              child: AnimatedOpacity(
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
            ),
          ],
        );
      },
    );
  }
}

class _VersusContender extends StatelessWidget {
  const _VersusContender({
    required this.assetPath,
    required this.isWinner,
    required this.isLoser,
    required this.isHighlighted,
    required this.duration,
    required this.semanticLabel,
    required this.onTapDown,
  });

  final String assetPath;
  final bool isWinner;
  final bool isLoser;
  final bool isHighlighted;
  final Duration duration;
  final String semanticLabel;
  final ValueChanged<Offset> onTapDown;

  @override
  Widget build(BuildContext context) {
    final scale = isWinner
        ? 1.03
        : isLoser
        ? 0.92
        : isHighlighted
        ? 1.02
        : 1.0;
    final borderColor = isWinner
        ? AppColors.accent
        : isHighlighted
        ? AppColors.textSecondary
        : AppColors.divider;

    return Semantics(
      button: true,
      label: isWinner
          ? '$semanticLabel, winner'
          : '$semanticLabel, double-tap to pick as winner',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => onTapDown(details.globalPosition),
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOutBack,
          scale: scale,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOut,
            opacity: isLoser ? 0.55 : 1,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: isWinner ? 2 : 1),
                boxShadow: isWinner
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          blurRadius: 16,
                        ),
                      ]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: ExcludeSemantics(
                  child: Image(
                    image: AssetImage(assetPath),
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

class _EmojiBurstParticle extends StatelessWidget {
  const _EmojiBurstParticle({
    required this.burst,
    required this.onCompleted,
    super.key,
  });

  final _EmojiBurst burst;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: burst.position.dx - 12,
      top: burst.position.dy - 12,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          onEnd: onCompleted,
          builder: (context, progress, child) {
            // Projectile motion: launch along the burst velocity, then fall.
            const gravity = 560.0;
            final t = progress * 0.9;
            final offset = Offset(
              burst.velocity.dx * t,
              burst.velocity.dy * t + 0.5 * gravity * t * t,
            );
            final fade = progress < 0.6 ? 1.0 : 1 - (progress - 0.6) / 0.4;

            return Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: burst.tilt * progress * 2,
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.7 + 0.4 * progress,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: Text(
            burst.emoji,
            style: const TextStyle(fontSize: 24, height: 1),
          ),
        ),
      ),
    );
  }
}

enum _VersusSide { left, right }

class _VersusMatchup {
  const _VersusMatchup({required this.leftAsset, required this.rightAsset});

  final String leftAsset;
  final String rightAsset;
}

class _EmojiBurst {
  const _EmojiBurst({
    required this.id,
    required this.position,
    required this.emoji,
    required this.velocity,
    required this.tilt,
  });

  final int id;
  final Offset position;
  final String emoji;
  final Offset velocity;
  final double tilt;
}
