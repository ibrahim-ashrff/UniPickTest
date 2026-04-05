import 'package:flutter/material.dart';
import '../models/order.dart';
import '../utils/app_colors.dart';

/// Estimated pickup time (order time + 15 min)
DateTime _estimatedPickupTime(Order order) {
  return order.createdAt.add(const Duration(minutes: 15));
}

String _formatPickupTime(DateTime dt) {
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${hour}:${dt.minute.toString().padLeft(2, '0')} $ampm';
}

/// Number of completed steps (1 = placed, 2 = preparing, 3 = ready, 4 = completed)
int _completedSteps(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return 4;
    case 'ready':
      return 3;
    case 'preparing':
      return 2;
    case 'paid':
    case 'pending':
    default:
      return 1;
  }
}

/// Order progress estimator: clock → preparing → storefront → check. Burgundy when filled.
class OrderEstimator extends StatelessWidget {
  final Order order;
  final bool compact;

  const OrderEstimator({
    super.key,
    required this.order,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _completedSteps(order.status);
    final pickupTime = _estimatedPickupTime(order);

    if (compact) {
      return _ProgressBar(steps: steps);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Order Confirmed',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pickup food at: ${_formatPickupTime(pickupTime)}',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),
        _ProgressBar(steps: steps),
        if (!compact) ...[
          const SizedBox(height: 12),
          Text(
            'Show this to the restaurant when you are ready to pickup your food.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressBar extends StatefulWidget {
  final int steps;

  const _ProgressBar({required this.steps});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

/// Curve: grow → hold at full → slowly disappear (easeOut so end is gentle) → hold at empty.
class _ProgressPulseCurve extends Curve {
  @override
  double transformInternal(double t) {
    if (t < 0.26) return Curves.easeOut.transform(t / 0.26);
    if (t < 0.46) return 1.0;
    if (t < 0.90) return 1.0 - Curves.easeOut.transform((t - 0.46) / 0.44);
    return 0.0;
  }
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: _ProgressPulseCurve()),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    const double iconSize = 26.0;
    const double lineHeight = 3.0;
    final filled = AppColors.burgundy;
    final unfilled = Colors.grey.shade300;

    return Row(
      children: [
        // Step 1: Clock (placed)
        Icon(
          Icons.schedule,
          size: iconSize,
          color: steps >= 1 ? filled : unfilled,
        ),
        Expanded(child: _Segment(
          steps: steps,
          segmentIndex: 0,
          lineHeight: lineHeight,
          filled: filled,
          unfilled: unfilled,
          animation: _animation,
        )),
        // Step 2: Preparing
        Icon(
          Icons.restaurant,
          size: iconSize,
          color: steps >= 2 ? filled : unfilled,
        ),
        Expanded(child: _Segment(
          steps: steps,
          segmentIndex: 1,
          lineHeight: lineHeight,
          filled: filled,
          unfilled: unfilled,
          animation: _animation,
        )),
        // Step 3: Ready (storefront)
        Icon(
          Icons.storefront_outlined,
          size: iconSize,
          color: steps >= 3 ? filled : unfilled,
        ),
        Expanded(child: _Segment(
          steps: steps,
          segmentIndex: 2,
          lineHeight: lineHeight,
          filled: filled,
          unfilled: unfilled,
          animation: _animation,
        )),
        // Step 4: Completed (check)
        Icon(
          Icons.check_circle,
          size: iconSize,
          color: steps >= 4 ? filled : unfilled,
        ),
      ],
    );
  }
}

/// One segment of the progress line: either filled, unfilled, or animating toward next dot.
class _Segment extends StatelessWidget {
  final int steps;
  final int segmentIndex;
  final double lineHeight;
  final Color filled;
  final Color unfilled;
  final Animation<double> animation;

  const _Segment({
    required this.steps,
    required this.segmentIndex,
    required this.lineHeight,
    required this.filled,
    required this.unfilled,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = steps >= segmentIndex + 2;
    final isAnimating = steps == segmentIndex + 1;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final fillWidth = isFilled
                ? width
                : (isAnimating ? width * animation.value : 0.0);

            return Container(
              height: lineHeight,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: unfilled,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  if (fillWidth > 0)
                    Positioned(
                      left: 0,
                      width: fillWidth,
                      height: lineHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: isAnimating
                                  ? [
                                      BoxShadow(
                                        color: filled.withOpacity(0.18),
                                        blurRadius: 3,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : null,
                              color: filled,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

