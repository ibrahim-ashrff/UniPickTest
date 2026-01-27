import 'package:flutter/material.dart';

class BottomWave extends StatelessWidget {
  const BottomWave({
    super.key,
    required this.color,
    this.height = 260,
  });

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Create a darker version of the color for the gradient (only in wave)
    final darkerColor = Color.fromRGBO(
      (color.red * 0.7).round().clamp(0, 255),
      (color.green * 0.7).round().clamp(0, 255),
      (color.blue * 0.7).round().clamp(0, 255),
      color.alpha / 255.0,
    );
    
    return ClipPath(
      clipper: _SmoothWaveClipper(),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.75], // Darker color extends to 75% down
            colors: [
              darkerColor, // Darker burgundy at top of wave
              color, // Original burgundy at bottom of wave
            ],
          ),
        ),
      ),
    );
  }
}

class _SmoothWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    // start from top-left
    path.moveTo(0, 0);
    path.lineTo(0, h * 0.22);

    // Smooth wave (2 bezier curves) — looks like your RN screenshot
    path.cubicTo(
      w * 0.20, h * 0.05,   // control point 1
      w * 0.35, h * 0.32,   // control point 2
      w * 0.55, h * 0.22,   // end point 1
    );

    path.cubicTo(
      w * 0.75, h * 0.12,   // control point 1
      w * 0.88, h * 0.30,   // control point 2
      w * 1.00, h * 0.22,   // end point 2
    );

    // close shape down to bottom
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

