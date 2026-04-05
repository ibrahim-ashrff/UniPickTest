import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'main_navigation.dart';
import 'terms_screen.dart';
import 'apple_name_collect_screen.dart';
import '../state/guest_provider.dart';

/// After login, checks Apple name (if needed), terms, then shows the app.
class PostLoginGate extends StatefulWidget {
  const PostLoginGate({super.key});

  @override
  State<PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<PostLoginGate> {
  bool? _termsAccepted;
  String? _error;
  bool _appleNameNeeded = false;
  bool _initialCheckDone = false;

  @override
  void initState() {
    super.initState();
    Provider.of<GuestProvider>(context, listen: false).setGuest(false);
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _initialCheckDone = true;
        _termsAccepted = false;
      });
      return;
    }
    final isApple = user.providerData.any((p) => p.providerId == 'apple.com');
    if (isApple) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final name = doc.data()?['name'] as String?;
        if (name == null || name.trim().isEmpty) {
          if (mounted) setState(() {
            _appleNameNeeded = true;
            _initialCheckDone = true;
          });
          return;
        }
      } catch (_) {
        if (mounted) setState(() {
          _appleNameNeeded = true;
          _initialCheckDone = true;
        });
        return;
      }
    }
    if (mounted) _checkTerms();
    if (mounted) setState(() => _initialCheckDone = true);
  }

  Future<void> _checkTerms() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _termsAccepted = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final accepted = doc.data()?['termsAcceptance'] == true;
      if (mounted) setState(() => _termsAccepted = accepted);
    } catch (e) {
      if (mounted) setState(() {
        _termsAccepted = false;
        _error = e.toString();
      });
    }
  }

  void _onAppleNameSaved() {
    setState(() => _appleNameNeeded = false);
    _checkTerms();
  }

  void _onTermsAccepted() {
    setState(() => _termsAccepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_appleNameNeeded) {
      return AppleNameCollectScreen(onSaved: _onAppleNameSaved);
    }

    if (_termsAccepted == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_termsAccepted == true) {
      return const MainNavigation();
    }

    return TermsScreen(onAccept: _onTermsAccepted);
  }
}
