import 'package:flutter/material.dart';

/// Custom clipper for creating an asymmetrical wave divider at the bottom
class AsymmetricalWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Start from top-left
    path.lineTo(0, 0);
    
    // Go to top-right
    path.lineTo(size.width, 0);
    
    // Go to bottom-right
    path.lineTo(size.width, size.height);
    
    // Create asymmetrical wave at the bottom edge (going from right to left)
    // First wave segment (smaller dip on the right)
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.88,
      size.width * 0.7,
      size.height,
    );
    
    // Second wave segment (larger dip in center - this creates the wave effect)
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.7, // Deeper dip in center - this is the wave
      size.width * 0.3,
      size.height,
    );
    
    // Third wave segment (medium, goes up on the left)
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.92,
      0,
      size.height,
    );
    
    // Complete the path back to start
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
