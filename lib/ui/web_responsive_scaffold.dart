import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebResponsiveScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color background;

  const WebResponsiveScaffold({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.background = const Color(0xFFF5F5F7),
  });

  @override
  Widget build(BuildContext context) {
    // On mobile, keep it normal full-screen.
    if (!kIsWeb) return child;

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: Colors.white,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

