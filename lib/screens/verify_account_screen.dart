import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../utils/app_navigator.dart';
import 'email_password_login_screen.dart';

/// Screen shown when user has signed up with email/password but has not verified their email.
/// Shows message, Verify button (resends email), and detects when user returns from verification link.
class VerifyAccountScreen extends StatefulWidget {
  final String email;

  const VerifyAccountScreen({super.key, required this.email});

  @override
  State<VerifyAccountScreen> createState() => _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends State<VerifyAccountScreen>
    with WidgetsBindingObserver {
  bool _sending = false;
  String? _sendMessage;
  bool _sendSuccess = false;
  int _cooldownSeconds = 0;
  static const int _cooldownDuration = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = _cooldownDuration);
    Future<void> tick() async {
      while (_cooldownSeconds > 0 && mounted) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        setState(() => _cooldownSeconds--);
      }
    }
    tick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerification();
    }
  }

  Future<void> _checkVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    try {
      await user.reload();
      final updated = FirebaseAuth.instance.currentUser;
      if (updated != null && updated.emailVerified) {
        if (!mounted) return;
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const EmailPasswordLoginScreen(),
          ),
          (route) => false,
        );
      }
    } catch (_) {}
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _sending = true;
      _sendMessage = null;
      _sendSuccess = false;
    });
    try {
      await user.sendEmailVerification();
      if (mounted) {
        setState(() {
          _sending = false;
          _sendMessage = 'Verification email sent! Check your inbox.';
          _sendSuccess = true;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _sendSuccess = false;
          if (e is FirebaseAuthException &&
              e.code == 'too-many-requests') {
            _sendMessage = 'Too many attempts. Please wait a few minutes and try again.';
          } else {
            _sendMessage = 'Couldn\'t send the email. Please try again in a moment.';
          }
        });
        _startCooldown();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.burgundy,
      appBar: AppBar(
        title: const Text('Verify your account'),
        backgroundColor: AppColors.burgundy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your account to login',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a verification link to\n${widget.email}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the link in your email, then return to this app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_sending || _cooldownSeconds > 0)
                      ? null
                      : _sendVerificationEmail,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.email_outlined),
                  label: Text(
                    _sending
                        ? 'Sending...'
                        : _cooldownSeconds > 0
                            ? 'Resend in ${_cooldownSeconds}s'
                            : 'Resend verification email',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.burgundy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_sendMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _sendMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: _sendSuccess
                          ? Colors.green.shade100
                          : Colors.orange.shade200,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: Text(
                  'Use different account',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
