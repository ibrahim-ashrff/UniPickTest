import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/main_navigation.dart';
import 'state/cart_provider.dart';
import 'state/orders_provider.dart';
import 'state/saved_cards_provider.dart';
import 'state/theme_provider.dart';
import 'utils/app_colors.dart';
import 'services/notification_service.dart' show NotificationService, firebaseMessagingBackgroundHandler;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service (skips on web) - must not block app startup
  // On iOS, getToken() can fail if APNS token isn't ready yet, so we run in background
  if (!kIsWeb) {
    NotificationService.navigatorKey = navigatorKey;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    unawaited(NotificationService().initialize().catchError((e, st) {
      debugPrint('NotificationService init failed (app will still run): $e');
    }));
  }
  
  runApp(const MyAppWithProviders());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'UNIPICK',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppColors.burgundy,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.burgundy,
              brightness: Brightness.light,
              primary: AppColors.burgundy,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.interTextTheme(),
            cardTheme: CardThemeData(
              elevation: 2,
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.burgundy,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            primaryColor: AppColors.burgundy,
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.burgundy,
              brightness: Brightness.dark,
              primary: AppColors.burgundy,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            cardTheme: CardThemeData(
              elevation: 2,
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.burgundy,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            dividerColor: Colors.grey[800],
          ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const MainNavigation();
              }
              
              // On web, always show owner login (no customer option)
              // On mobile, use default (customer login unless specified)
              final isOwnerMode = kIsWeb ? true : false;
              
              return LoginPage(isTruckOwner: isOwnerMode);
            },
          ),
        );
      },
    );
  }
}

class MyAppWithProviders extends StatelessWidget {
  const MyAppWithProviders({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => SavedCardsProvider()),
      ],
      child: const MyApp(),
    );
  }
}
