import 'package:flutter/material.dart';

/// Custom clipper for creating an asymmetrical wave divider at the top
/// Used for the burgundy section to create a wavy top edge
class AsymmetricalWaveClipperTop extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Start from top-left with wave
    // First wave segment (smaller on the left)
    path.moveTo(0, size.height * 0.12);
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.08,
      size.width * 0.3,
      size.height * 0.12,
    );
    
    // Second wave segment (larger dip in center - this creates the wave effect)
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3, // Deeper dip in center - this is the wave
      size.width * 0.7,
      size.height * 0.12,
    );
    
    // Third wave segment (medium on the right)
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.08,
      size.width,
      size.height * 0.12,
    );
    
    // Go to bottom-right
    path.lineTo(size.width, size.height);
    
    // Go to bottom-left
    path.lineTo(0, size.height);
    
    // Complete the path back to start
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}




