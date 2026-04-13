import 'package:flutter/material.dart';

/// Thank-you row with a green check that scales and fades in smoothly.
class AnimatedPaymentSuccessHeader extends StatefulWidget {
  const AnimatedPaymentSuccessHeader({
    super.key,
    this.title = 'Thank you for your order!',
    this.subtitle,
    this.iconSize = 88,
  });

  final String title;
  final String? subtitle;
  final double iconSize;

  @override
  State<AnimatedPaymentSuccessHeader> createState() =>
      _AnimatedPaymentSuccessHeaderState();
}

class _AnimatedPaymentSuccessHeaderState extends State<AnimatedPaymentSuccessHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: widget.iconSize + 20,
              height: widget.iconSize + 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                size: widget.iconSize * 0.52,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FadeTransition(
          opacity: _fade,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _fade,
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
