import 'package:flutter/cupertino.dart';

/// The route the fit viewer opens on: a see-through page that lets the grid
/// behind it stay put while the photo zooms up over it.
///
/// Transparent rather than opaque because the zoom is the transition — the
/// tile the user tapped has to remain on screen underneath for the Hero to
/// fly out of, and the darkening backdrop is the page's own first layer
/// fading in rather than a barrier the navigator paints.
class FitViewerRoute<T> extends PageRoute<T> {
  FitViewerRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  /// Long enough for the zoom to read as an opening rather than a cut, short
  /// enough that a look at a photo never feels gated behind an animation.
  @override
  Duration get transitionDuration => const Duration(milliseconds: 340);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    // Fades the page as a whole — backdrop, handle, stats and buttons. The
    // photo itself is exempt in practice: for the length of the flight the
    // Hero renders in the overlay and this subtree holds only its placeholder.
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
      child: child,
    );
  }
}
