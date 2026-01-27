import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/bottom_wave.dart';
import '../services/auth_service.dart';
import 'email_password_login_screen.dart';
import 'main_navigation.dart';

/// Main login screen with logo and sign-in method selection
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final burgundyHeight = screenHeight * 0.4; // 40% burgundy
    final waveHeight = 100.0; // Height of the wave part
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Wave with gradient at the boundary (sits on top)
          Positioned(
            bottom: burgundyHeight - waveHeight,
            left: 0,
            right: 0,
            height: waveHeight,
            child: const BottomWave(color: AppColors.burgundy, height: 100),
          ),
          // Solid burgundy section at bottom (starts from bottom of wave)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: burgundyHeight - waveHeight,
            child: Container(
              color: AppColors.burgundy,
            ),
          ),

          // Foreground content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),
                // Logo, sectioner, app name, and motto
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Logo - increased size
                      Image.asset(
                        'LOGOUNI-removebg-preview.png',
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Text(
                            'LOGOUNI',
                            style: TextStyle(
                              fontSize: 67,
                              fontWeight: FontWeight.bold,
                              color: AppColors.burgundy,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Sectioner (single line)
                      Container(
                        width: 60,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // App Name
                      Text(
                        'UniPick',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Motto/Tagline
                      Text(
                        'Skip the line. Pick up smart.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Buttons area (sits on wave) - shifted upwards
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), // Added top padding to shift up
                  child: Column(
                    children: [
                      Text(
                        'Select your preferred sign-in method',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _AuthButton(
                        text: 'Continue with Google',
                        onPressed: () async {
                          try {
                            final authService = AuthService();
                            final userCredential = await authService.signInWithGoogle();
                            
                            if (userCredential != null && context.mounted) {
                              // Navigate to main navigation after successful sign-in
                              context.slideReplacementAll(
                                const MainNavigation(),
                                direction: SlideDirection.left,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              String errorMessage = 'Error signing in';
                              if (e.toString().contains('network_error') || 
                                  e.toString().contains('ApiException: 7')) {
                                errorMessage = 'Network error. Please check your internet connection and try again.';
                              } else if (e.toString().contains('sign_in_canceled')) {
                                errorMessage = 'Sign in was canceled';
                              } else {
                                errorMessage = 'Error: ${e.toString()}';
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                        _AuthButton(
                        text: 'Continue with email & password',
                        onPressed: () {
                          context.slideTo(
                            const EmailPasswordLoginScreen(),
                            direction: SlideDirection.right,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14, // Reduced from 16 to fit longer text
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ),
    );
  }
}
