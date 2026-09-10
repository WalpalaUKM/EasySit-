import 'package:flutter/material.dart';

/// A custom page route that implements a subtle fade + slight slide transition.
///
/// Specifications:
/// - Animation: Fade + slight Slide
/// - Duration: 200–250 ms (default: 220 ms)
/// - Curve: EaseOut / easeInOut (default: Curves.easeInOut)
/// - Slide distance: ~5–10 px (default: 8.0 px)
/// - Scale: None
/// - Rotation: None
/// - Bounce: None
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    Duration duration = const Duration(milliseconds: 220),
    double slideDistance = 8.0,
    Axis axis = Axis.vertical,
    Curve curve = Curves.easeInOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeSlideTransition(
              animation: animation,
              slideDistance: slideDistance,
              axis: axis,
              curve: curve,
              child: child,
            );
          },
        );
}

typedef FadeSlidePageRoute<T> = AppPageRoute<T>;

/// A PageTransitionsBuilder that can be assigned to [ThemeData.pageTransitionsTheme]
/// so that standard routes (including MaterialPageRoute) automatically use
/// the Fade + slight Slide animation.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder({
    this.slideDistance = 8.0,
    this.axis = Axis.vertical,
    this.curve = Curves.easeInOut,
  });

  final double slideDistance;
  final Axis axis;
  final Curve curve;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeSlideTransition(
      animation: animation,
      slideDistance: slideDistance,
      axis: axis,
      curve: curve,
      child: child,
    );
  }
}

/// Reusable transition widget:
/// - Fade (opacity: 0 -> 1)
/// - Slight slide (~8 px translation along [axis])
/// - Smooth curve (easeInOut / easeOut)
/// - No scale, no rotation, no bounce
class FadeSlideTransition extends StatelessWidget {
  const FadeSlideTransition({
    super.key,
    required this.animation,
    required this.child,
    this.slideDistance = 8.0,
    this.axis = Axis.vertical,
    this.curve = Curves.easeInOut,
  });

  final Animation<double> animation;
  final Widget child;
  final double slideDistance;
  final Axis axis;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve:
          curve == Curves.easeInOut ? Curves.easeInOut : Curves.easeIn,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: AnimatedBuilder(
        animation: curvedAnimation,
        builder: (context, child) {
          if (curvedAnimation.isCompleted) {
            return child!;
          }
          final double offset = (1.0 - curvedAnimation.value) * slideDistance;
          return Transform.translate(
            offset:
                axis == Axis.vertical ? Offset(0, offset) : Offset(offset, 0),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}
