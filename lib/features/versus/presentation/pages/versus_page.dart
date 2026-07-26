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
import '../../../fits/controllers/saved_fits_controller.dart';
import '../../../fits/models/fit.dart';
import '../../../fits/models/fit_genre.dart';
import '../../../fits/presentation/widgets/fit_image.dart';
import '../../controllers/arena_filter_controller.dart';
import '../../controllers/versus_controller.dart';
import '../../models/matchup.dart';
import '../widgets/arena_genre_bar.dart';
import '../widgets/emoji_burst.dart';
import '../widgets/matchup_board.dart';
import '../widgets/matchup_board_skeleton.dart';

/// What a long press on a card offers.
enum _FitAction { toggleSave, report }

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

  /// How long the winner reveal may linger waiting on the next pair's images
  /// before the board moves on regardless. Holding forever would strand the
  /// user on a decided matchup if the network stalls.
  static const _nextPairWaitCap = Duration(seconds: 5);
  static const _burstEmojis = ['🔥', '✨', '⚡', '💯', '👀', '👏'];
  static const _hintSeenPrefKey = 'versus_double_tap_hint_seen';

  final _boardKey = GlobalKey();
  final _random = Random();

  Timer? _highlightTimer;
  VersusSide? _winner;
  VersusSide? _highlighted;
  VersusSide? _lastTapSide;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  final List<EmojiBurst> _bursts = [];
  int _nextBurstId = 0;
  bool _showHint = false;

  /// Warm-up for the queued pair, and the one behind it that is now on screen.
  /// The outgoing one is held one extra step so its images stay resident until
  /// the board's own cards have taken over listening to them.
  _PairWarmup? _warmup;
  _PairWarmup? _retiredWarmup;

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
  void _warmUpcoming(Matchup? upcoming) {
    if (upcoming?.pairKey == _warmup?.pairKey) return;

    // The outgoing warm-up covers the pair that just reached the screen. Its
    // cards now listen to those images themselves, so it can be released.
    _retiredWarmup?.dispose();
    _retiredWarmup = _warmup;

    if (upcoming == null) {
      _warmup = null;
      return;
    }

    final storage = ref.read(storageServiceProvider);
    _warmup = _PairWarmup(
      pairKey: upcoming.pairKey,
      configuration: createLocalImageConfiguration(context),
      providers: [
        for (final fit in [upcoming.left, upcoming.right])
          fitImageProvider(storage.fitImageUrl(fit.imagePath)),
      ],
    );
  }

  /// Holds the winner reveal until the queued pair can paint in one go, so the
  /// board never swaps into two loading spinners. Falls back to the plain
  /// reveal duration when nothing is queued (the arena shows its own loading
  /// state then) or when the images take too long.
  Future<void> _awaitNextPair(Duration revealDelay) async {
    final reveal = Future<void>.delayed(revealDelay);
    final images = _warmup?.ready;
    if (images == null) return reveal;

    await Future.wait([
      reveal,
      images.timeout(_nextPairWaitCap, onTimeout: () {}),
    ]);
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

    unawaited(
      ref
          .read(versusControllerProvider.notifier)
          .submitVote(
            winnerId: matchup.fitOn(side).id,
            loserId: matchup.opponentOf(side).id,
          )
          .then((failure) {
            if (!mounted || failure == null) return;
            AppToast.error(context: context, message: failure);
          }),
    );

    await _awaitNextPair(revealDelay);
    if (!mounted || _winner != side) return;
    _advance();
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      _winner = null;
      _lastTapSide = null;
    });
    ref.read(versusControllerProvider.notifier).advance();
  }

  /// The long-press menu for a card. The bookmark on the card is the quick
  /// path to saving; this is where it lives for anyone who never finds it, and
  /// the only way to reach reporting.
  Future<void> _showFitOptions(VersusSide side) async {
    final matchup = ref.read(versusControllerProvider).value?.current;
    if (matchup == null) return;

    final fit = matchup.fitOn(side);
    final handle = fit.ownerHandle;
    final isSaved = ref
        .read(savedFitsControllerProvider.notifier)
        .isSaved(fit.id);

    final action = await AppModal.showActionSheet<_FitAction>(
      context: context,
      title: handle == null ? 'This fit' : "$handle's fit",
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(_FitAction.toggleSave),
          child: Text(isSaved ? 'Remove from saved' : 'Save fit'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(_FitAction.report),
          child: const Text('Report fit'),
        ),
      ],
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _FitAction.toggleSave:
        await _toggleSave(side);
      case _FitAction.report:
        await _reportFit(side);
    }
  }

  /// Saves the fit on [side], or drops it if it was already saved. Saves are
  /// private, so the confirmation says where it went.
  Future<void> _toggleSave(VersusSide side) async {
    final matchup = ref.read(versusControllerProvider).value?.current;
    if (matchup == null) return;

    final fit = matchup.fitOn(side);
    final notifier = ref.read(savedFitsControllerProvider.notifier);
    final wasSaved = notifier.isSaved(fit.id);

    final failure = await notifier.toggleSave(fit);
    if (!mounted) return;

    if (failure != null) {
      AppToast.error(context: context, message: failure);
      return;
    }

    AppToast.show(
      context: context,
      message: wasSaved ? 'Removed from saved.' : 'Saved to your profile.',
    );
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
    _highlightTimer?.cancel();
    _warmup?.dispose();
    _retiredWarmup?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final versusState = ref.watch(versusControllerProvider);

    // Warmed from build rather than a listener: the first pair the arena loads
    // is already in place by the time this page first builds, and a listener
    // would miss it, leaving the very first swap after launch unwarmed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _warmUpcoming(versusState.value?.upcoming);
    });

    final filter = ref.watch(arenaFilterControllerProvider);

    // Switching category throws the queue away, so any reveal in progress
    // belongs to a matchup that will never come back. Clearing it keeps the
    // next pair from arriving already decided.
    ref.listen<FitGenre?>(arenaFilterControllerProvider, (_, _) {
      _highlightTimer?.cancel();
      if (_winner == null && _highlighted == null) return;
      setState(() {
        _winner = null;
        _highlighted = null;
        _lastTapSide = null;
      });
    });

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // Outside the state switch: the category strip is how you get out
            // of an empty or failed arena, so it stays put through both.
            const ArenaGenreBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: AnimatedSwitcher(
                  // The first pair arrives into the shape the skeleton was
                  // already holding, so the arena settles in rather than
                  // snapping from a spinner to a full board.
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: versusState.when(
                    loading: () => const MatchupBoardSkeleton(
                      key: ValueKey('arena-skeleton'),
                    ),
                    error: (error, _) => AppEmptyState(
                      key: const ValueKey('arena-error'),
                      icon: CupertinoIcons.exclamationmark_triangle,
                      title: 'The arena is out of reach',
                      message: describeError(error),
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(versusControllerProvider.notifier).reload(),
                    ),
                    data: (state) {
                      final matchup = state.current;
                      if (matchup == null) {
                        return _ExhaustedArena(
                          key: const ValueKey('arena-exhausted'),
                          filter: filter,
                        );
                      }

                      return _Arena(
                        key: const ValueKey('arena-board'),
                        boardKey: _boardKey,
                        matchup: matchup,
                        // The strip already names the category when one is
                        // picked; repeating it over the board says nothing.
                        showGenreLabel: filter == null,
                        winner: _winner,
                        highlighted: _highlighted,
                        bursts: _bursts,
                        showHint: _showHint,
                        onTapDown: _handleTapDown,
                        onLongPress: _showFitOptions,
                        onToggleSave: _toggleSave,
                        onBurstCompleted: _removeBurst,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Holds a matchup's two images decoded and *listened to* until the board has
/// moved on to them.
///
/// `precacheImage` is not enough on its own: it only leaves an entry in the
/// image cache, and a cache with no live listener is free to evict it before
/// the pair ever reaches the screen — which is how a warmed matchup still
/// arrives with a spinner on one card. An attached [ImageStreamListener] keeps
/// the decoded image alive, and tells us when it is genuinely ready to paint.
class _PairWarmup {
  _PairWarmup({
    required this.pairKey,
    required List<ImageProvider> providers,
    required ImageConfiguration configuration,
  }) {
    var pending = providers.length;

    for (final provider in providers) {
      final stream = provider.resolve(configuration);
      var settled = false;

      // A broken image settles too: its card shows an error placeholder, and
      // holding the reveal open for it would help nobody.
      void settle() {
        if (settled) return;
        settled = true;
        if (--pending == 0 && !_ready.isCompleted) _ready.complete();
      }

      final listener = ImageStreamListener(
        (_, _) => settle(),
        onError: (_, _) => settle(),
      );
      stream.addListener(listener);
      _listeners.add((stream, listener));
    }
  }

  final String pairKey;
  final _listeners = <(ImageStream, ImageStreamListener)>[];
  final _ready = Completer<void>();

  /// Completes once both images are decoded and resident.
  Future<void> get ready => _ready.future;

  void dispose() {
    for (final (stream, listener) in _listeners) {
      stream.removeListener(listener);
    }
    _listeners.clear();
    if (!_ready.isCompleted) _ready.complete();
  }
}

/// The board plus the emoji bursts layered over it and the first-run hint.
class _Arena extends StatelessWidget {
  const _Arena({
    required this.boardKey,
    required this.matchup,
    required this.showGenreLabel,
    required this.winner,
    required this.highlighted,
    required this.bursts,
    required this.showHint,
    required this.onTapDown,
    required this.onLongPress,
    required this.onToggleSave,
    required this.onBurstCompleted,
    super.key,
  });

  final GlobalKey boardKey;
  final Matchup matchup;
  final bool showGenreLabel;
  final VersusSide? winner;
  final VersusSide? highlighted;
  final List<EmojiBurst> bursts;
  final bool showHint;
  final void Function(VersusSide side, Offset globalPosition) onTapDown;
  final ValueChanged<VersusSide> onLongPress;
  final ValueChanged<VersusSide> onToggleSave;
  final ValueChanged<int> onBurstCompleted;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    final genre = matchup.genre;

    return Column(
      children: [
        // Which genre this battle is in: the pair is always like against like,
        // so one label covers both cards. Only worth showing while the arena
        // is drawing from every category. It peeks in and back out rather
        // than sitting there permanently, so the board gets the same amount
        // of room (and the cards render at the same size) as when a single
        // category is selected.
        if (showGenreLabel)
          _GenreRevealBanner(
            revealKey: matchup.pairKey,
            genreLabel: genre?.label,
            animationsDisabled: animationsDisabled,
          ),
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
                    onToggleSave: onToggleSave,
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

/// Slides the current genre label down from the top of the board, holds it
/// briefly, then slides it back out.
///
/// Mounted only in the "All" category, where the pair's genre changes from
/// matchup to matchup and is worth calling out. Collapsing back to zero
/// height (rather than just fading) is what lets [MatchupBoard]'s
/// [LayoutBuilder] hand the reclaimed space back to the cards, so they grow
/// to the same size they'd be in a single-category board.
class _GenreRevealBanner extends StatefulWidget {
  const _GenreRevealBanner({
    required this.revealKey,
    required this.genreLabel,
    required this.animationsDisabled,
  });

  final Object revealKey;
  final String? genreLabel;
  final bool animationsDisabled;

  @override
  State<_GenreRevealBanner> createState() => _GenreRevealBannerState();
}

class _GenreRevealBannerState extends State<_GenreRevealBanner> {
  static const _slideDuration = Duration(milliseconds: 300);
  static const _visibleDuration = Duration(seconds: 1);

  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(covariant _GenreRevealBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealKey != oldWidget.revealKey) _reveal();
  }

  void _reveal() {
    _hideTimer?.cancel();
    if (widget.genreLabel == null) {
      setState(() => _visible = false);
      return;
    }
    setState(() => _visible = true);
    _hideTimer = Timer(_visibleDuration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.animationsDisabled ? Duration.zero : _slideDuration;
    return ClipRect(
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        heightFactor: _visible ? 1 : 0,
        child: AnimatedSlide(
          duration: duration,
          curve: Curves.easeOut,
          offset: _visible ? Offset.zero : const Offset(0, -1),
          child: AnimatedOpacity(
            duration: duration,
            opacity: _visible ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                (widget.genreLabel ?? '').toUpperCase(),
                style: AppTextStyles.meta,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown once every available pairing has been judged.
///
/// A category filter makes this state easy to reach without the arena being
/// anywhere near empty, so it says which pool ran out and offers the way back.
class _ExhaustedArena extends ConsumerWidget {
  const _ExhaustedArena({required this.filter, super.key});

  final FitGenre? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filter != null) {
      return AppEmptyState(
        icon: CupertinoIcons.checkmark_seal,
        title: 'Nothing left in ${filter!.label}',
        message:
            'You have judged every ${filter!.label.toLowerCase()} pairing '
            'available to you. Try another category, or check back soon.',
        actionLabel: 'Judge every category',
        onAction: () =>
            ref.read(arenaFilterControllerProvider.notifier).select(null),
      );
    }

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
