import 'package:flutter/material.dart';

/// A wrapper widget that enables intuitive swipe gestures:
/// 1. Tab Swipe Navigation: Swiping left/right navigates between bottom navigation tabs
///    (Home: 0 ↔ Scan: 1 ↔ My Session: 2 ↔ Profile: 3).
/// 2. Swipe-Back Navigation: Swiping right from the left edge or across the screen
///    pops the current route and returns to the previous screen.
class SwipeNavigationWrapper extends StatefulWidget {
  final Widget child;

  /// Index of the current bottom navigation tab (0 = Home, 1 = Scan, 2 = My Session, 3 = Profile).
  final int? currentTabIndex;

  /// Callback to execute when switching tabs via swipe.
  final ValueChanged<int>? onTabSelected;

  /// If true, swiping right will navigate back (pop the route or call [onSwipeBack]).
  final bool enableSwipeBack;

  /// Custom callback for swipe back action. Defaults to `Navigator.maybePop(context)`.
  final VoidCallback? onSwipeBack;

  const SwipeNavigationWrapper({
    super.key,
    required this.child,
    this.currentTabIndex,
    this.onTabSelected,
    this.enableSwipeBack = false,
    this.onSwipeBack,
  });

  @override
  State<SwipeNavigationWrapper> createState() => _SwipeNavigationWrapperState();
}

class _SwipeNavigationWrapperState extends State<SwipeNavigationWrapper> {
  double _dragDistanceX = 0.0;
  double _dragDistanceY = 0.0;
  bool _actionTriggered = false;

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragDistanceX = 0.0;
    _dragDistanceY = 0.0;
    _actionTriggered = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_actionTriggered) return;
    _dragDistanceX += details.delta.dx;
    _dragDistanceY += details.delta.dy;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_actionTriggered || !mounted) return;

    final double velocityX = details.primaryVelocity ?? 0.0;
    final double absX = _dragDistanceX.abs();
    final double absY = _dragDistanceY.abs();

    // Ignore if drag was not sufficiently horizontal or too small
    if (absX < 35 && velocityX.abs() < 240) return;
    if (absY > absX * 1.2) return;

    final bool isSwipeRight = _dragDistanceX > 35 || velocityX > 240;
    final bool isSwipeLeft = _dragDistanceX < -35 || velocityX < -240;

    if (isSwipeRight) {
      // 1. Swipe Back Priority
      if (widget.enableSwipeBack) {
        _actionTriggered = true;
        if (widget.onSwipeBack != null) {
          widget.onSwipeBack!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        return;
      }

      // 2. Previous Tab (e.g. Profile -> Session -> Scan -> Home)
      if (widget.currentTabIndex != null && widget.onTabSelected != null) {
        if (widget.currentTabIndex! > 0) {
          _actionTriggered = true;
          widget.onTabSelected!(widget.currentTabIndex! - 1);
          return;
        }
      }
    } else if (isSwipeLeft) {
      // Next Tab (e.g. Home -> Scan -> Session -> Profile)
      if (widget.currentTabIndex != null && widget.onTabSelected != null) {
        if (widget.currentTabIndex! < 3) {
          _actionTriggered = true;
          widget.onTabSelected!(widget.currentTabIndex! + 1);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: widget.child,
    );
  }
}
