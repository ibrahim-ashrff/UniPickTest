import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import '../ui/web_responsive_scaffold.dart';
import 'main_navigation.dart';

/// Signup screen for creating a new account
/// Shows form fields for name, email, password, and confirm password
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  String? signupError;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    // Validate fields
    if (nameController.text.trim().isEmpty) {
      setState(() {
        signupError = 'Please enter your name';
      });
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        signupError = 'Passwords do not match';
      });
      return;
    }

    if (passwordController.text.length < 6) {
      setState(() {
        signupError = 'Password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      loading = true;
      signupError = null;
    });

    try {
      // Create Firebase Auth account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Get the newly created user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Create user document in Firestore with name and default role
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'name': nameController.text.trim(),
          'email': user.email,
          'role': 'customer', // Default role for all new users
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // Navigate to home screen after successful signup
      context.slideReplacementAll(
        const MainNavigation(),
        direction: SlideDirection.left,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is invalid';
      }
      
      if (mounted) {
        setState(() {
          signupError = errorMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          signupError = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebResponsiveScaffold(
      child: Scaffold(
        backgroundColor: AppColors.burgundy,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.burgundy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.burgundy,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Image at the top
                Image.asset(
                  'image-removebg-preview.png',
                  height: 105,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 32),
                // Name field
                TextField(
                  controller: nameController,
                  keyboardType: TextInputType.name,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) {
                    if (signupError != null) {
                      setState(() => signupError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Email field
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) {
                    if (signupError != null) {
                      setState(() => signupError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Password field
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) {
                    if (signupError != null) {
                      setState(() => signupError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Confirm password field
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) {
                    if (signupError != null) {
                      setState(() => signupError = null);
                    }
                  },
                ),
                if (signupError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      signupError!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.burgundy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      loading ? "Creating Account..." : "Create Account",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "Already have an account? Sign in",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

