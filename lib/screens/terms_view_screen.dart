import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/terms_text.dart';

/// Read-only screen to view Terms & Conditions from Account tab
class TermsViewScreen extends StatelessWidget {
  const TermsViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          termsAndConditionsText,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
