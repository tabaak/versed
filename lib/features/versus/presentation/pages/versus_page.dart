import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_notification.dart';
import '../../../fits/models/fit.dart';
import '../../controllers/versus_controller.dart';
import '../../models/matchup.dart';
import '../widgets/emoji_burst.dart';
import '../widgets/matchup_board.dart';

/// Main matchup screen: two outfits battle, double-tap picks the winner.
class VersusPage extends ConsumerStatefulWidget {
  const VersusPage({super.key});

  @override
  ConsumerState<VersusPage> createState() => _VersusPageState();
}

class _VersusPageState extends ConsumerState<VersusPage> {
  static const _winnerRevealDuration = Duration(milliseconds: 900);
  static const _doubleTapWindow = Duration(milliseconds: 350);
  static const _highlightTimeout = Duration(milliseconds: 1500);
  static const _burstEmojis = ['🔥', '✨', '⚡', '💯', '👀', '👏'];
  static const _hintSeenPrefKey = 'versus_double_tap_hint_seen';

  final _boardKey = GlobalKey();
  final _random = Random();

  Timer? _advanceTimer;
  Timer? _highlightTimer;
  VersusSide? _winner;
  VersusSide? _highlighted;
  VersusSide? _lastTapSide;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  final List<EmojiBurst> _bursts = [];
  int _nextBurstId = 0;
  bool _showHint = false;

  /// The matchup whose images are already warmed, so the queue is only
  /// precached once per pair.
  String? _precachedPairKey;

  @override
  void initState() {
    super.initState();
    _loadHintSeen();
  }

  Future<void> _loadHintSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (!(prefs.getBool(_hintSeenPrefKey) ?? false)) {
      setState(() => _showHint = true);
    }
  }

  void _dismissHint() {
    if (!_showHint) return;
    setState(() => _showHint = false);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_hintSeenPrefKey, true),
    );
  }

  /// Warms the queued matchup's images while the user is still deciding, so
  /// the next pair does not fade in half-loaded.
  void _precacheUpcoming(Matchup? upcoming) {
    if (upcoming == null || upcoming.pairKey == _precachedPairKey) return;
    _precachedPairKey = upcoming.pairKey;

    final storage = ref.read(storageServiceProvider);
    for (final fit in [upcoming.left, upcoming.right]) {
      precacheImage(NetworkImage(storage.fitImageUrl(fit.imagePath)), context);
    }
  }

  void _handleTapDown(VersusSide side, Offset globalPosition) {
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
          EmojiBurst(
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

  Future<void> _pickWinner(VersusSide side) async {
    if (_winner != null) return;

    final matchup = ref.read(versusControllerProvider).value?.current;
    if (matchup == null) return;

    _dismissHint();
    _highlightTimer?.cancel();
    setState(() {
      _winner = side;
      _highlighted = null;
    });

    // The reveal animation runs while the vote is in flight; the result of a
    // 1v1 tap should never wait on the network.
    final revealDelay = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 300)
        : _winnerRevealDuration;
    _advanceTimer = Timer(revealDelay, _advance);

    final failure = await ref
        .read(versusControllerProvider.notifier)
        .submitVote(
          winnerId: matchup.fitOn(side).id,
          loserId: matchup.opponentOf(side).id,
        );

    if (!mounted || failure == null) return;
    AppToast.error(context: context, message: failure);
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      _winner = null;
      _lastTapSide = null;
    });
    ref.read(versusControllerProvider.notifier).advance();
  }

  Future<void> _reportFit(VersusSide side) async {
    final matchup = ref.read(versusControllerProvider).value?.current;
    if (matchup == null) return;

    final fit = matchup.fitOn(side);
    final handle = fit.ownerHandle;

    final reason = await AppModal.showActionSheet<FitReportReason>(
      context: context,
      title: handle == null ? 'Report this fit' : "Report $handle's fit",
      message: 'Reported fits leave the arena once enough people agree.',
      actions: [
        for (final reason in FitReportReason.values)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(reason),
            child: Text(reason.label),
          ),
      ],
    );

    if (reason == null || !mounted) return;

    final failure = await ref
        .read(versusControllerProvider.notifier)
        .reportFit(fitId: fit.id, reason: reason);

    if (!mounted) return;
    if (failure == null) {
      AppToast.success(context: context, message: 'Reported. Thanks.');
    } else {
      AppToast.error(context: context, message: failure);
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(versusControllerProvider, (previous, next) {
      _precacheUpcoming(next.value?.upcoming);
    });

    final versusState = ref.watch(versusControllerProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('VERSED', style: AppTextStyles.wordmark),
        border: null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: versusState.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, _) => AppEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: 'The arena is out of reach',
              message: describeError(error),
              actionLabel: 'Try again',
              onAction: () =>
                  ref.read(versusControllerProvider.notifier).reload(),
            ),
            data: (state) {
              final matchup = state.current;
              if (matchup == null) return const _ExhaustedArena();

              return _Arena(
                boardKey: _boardKey,
                matchup: matchup,
                winner: _winner,
                highlighted: _highlighted,
                bursts: _bursts,
                showHint: _showHint,
                onTapDown: _handleTapDown,
                onLongPress: _reportFit,
                onBurstCompleted: _removeBurst,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The board plus the emoji bursts layered over it and the first-run hint.
class _Arena extends StatelessWidget {
  const _Arena({
    required this.boardKey,
    required this.matchup,
    required this.winner,
    required this.highlighted,
    required this.bursts,
    required this.showHint,
    required this.onTapDown,
    required this.onLongPress,
    required this.onBurstCompleted,
  });

  final GlobalKey boardKey;
  final Matchup matchup;
  final VersusSide? winner;
  final VersusSide? highlighted;
  final List<EmojiBurst> bursts;
  final bool showHint;
  final void Function(VersusSide side, Offset globalPosition) onTapDown;
  final ValueChanged<VersusSide> onLongPress;
  final ValueChanged<int> onBurstCompleted;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        Expanded(
          child: Stack(
            key: boardKey,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: animationsDisabled
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: MatchupBoard(
                    key: ValueKey(matchup.pairKey),
                    matchup: matchup,
                    winner: winner,
                    highlighted: highlighted,
                    animationsDisabled: animationsDisabled,
                    onTapDown: onTapDown,
                    onLongPress: onLongPress,
                  ),
                ),
              ),
              for (final burst in bursts)
                EmojiBurstParticle(
                  key: ValueKey(burst.id),
                  burst: burst,
                  onCompleted: () => onBurstCompleted(burst.id),
                ),
            ],
          ),
        ),
        if (showHint) ...[
          const SizedBox(height: 12),
          const Text(
            'Double-tap the outfit that wins',
            style: AppTextStyles.meta,
          ),
        ],
      ],
    );
  }
}

/// Shown once every available pairing has been judged.
class _ExhaustedArena extends ConsumerWidget {
  const _ExhaustedArena();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: CupertinoIcons.checkmark_seal,
      title: 'You have judged everything',
      message:
          'New fits enter the arena all the time. Check back soon, or '
          'upload one of your own.',
      actionLabel: 'Check again',
      onAction: () => ref.read(versusControllerProvider.notifier).reload(),
    );
  }
}
