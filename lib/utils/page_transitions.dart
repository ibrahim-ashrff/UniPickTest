import 'package:flutter/material.dart';

/// Custom page route with smooth slide and fade animations
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final SlideDirection direction;

  SlidePageRoute({
    required this.child,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fade animation
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
            );

            // Slide animation based on direction
            Offset beginOffset;
            switch (direction) {
              case SlideDirection.right:
                beginOffset = const Offset(1.0, 0.0);
                break;
              case SlideDirection.left:
                beginOffset = const Offset(-1.0, 0.0);
                break;
              case SlideDirection.top:
                beginOffset = const Offset(0.0, -1.0);
                break;
              case SlideDirection.bottom:
                beginOffset = const Offset(0.0, 1.0);
                break;
            }

            final slideAnimation = Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            // Scale animation for a more dynamic effect
            final scaleAnimation = Tween<double>(
              begin: 0.9,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Custom page route with fade animation only
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  FadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}

/// Custom page route with scale animation
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  ScalePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
            );

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeIn,
              ),
            );

            return ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
}

enum SlideDirection {
  right,
  left,
  top,
  bottom,
}

/// Helper extension to easily navigate with animations
extension NavigationExtension on BuildContext {
  /// Navigate with slide animation
  Future<T?> slideTo<T>(
    Widget page, {
    SlideDirection direction = SlideDirection.right,
  }) {
    return Navigator.of(this).push<T>(
      SlidePageRoute(
        child: page,
        direction: direction,
      ),
    );
  }

  /// Navigate with fade animation
  Future<T?> fadeTo<T>(Widget page) {
    return Navigator.of(this).push<T>(
      FadePageRoute(child: page),
    );
  }

  /// Navigate with scale animation
  Future<T?> scaleTo<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ScalePageRoute(child: page),
    );
  }

  /// Replace with slide animation
  Future<T?> slideReplacement<T extends Object?, TO extends Object?>(
    Widget page, {
    SlideDirection direction = SlideDirection.right,
  }) {
    return Navigator.of(this).pushReplacement<T, TO>(
      SlidePageRoute(
        child: page,
        direction: direction,
      ),
    );
  }

  /// Replace all routes with slide animation
  Future<T?> slideReplacementAll<T extends Object?>(
    Widget page, {
    SlideDirection direction = SlideDirection.right,
  }) {
    return Navigator.of(this).pushAndRemoveUntil<T>(
      SlidePageRoute(
        child: page,
        direction: direction,
      ),
      (route) => false,
    );
  }
}




