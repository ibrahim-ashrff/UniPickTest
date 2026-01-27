import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../state/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(
                    'Notifications',
                    style: GoogleFonts.inter(),
                  ),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                    activeColor: AppColors.burgundy,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(
                    'Language',
                    style: GoogleFonts.inter(),
                  ),
                  trailing: Text(
                    'English',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    // Language selection
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(
                    'Dark Mode',
                    style: GoogleFonts.inter(),
                  ),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                    activeColor: AppColors.burgundy,
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

