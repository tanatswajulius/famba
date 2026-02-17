import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/driver_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ride_request_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/delivery_navigation_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => DriverState(),
      child: const FambaDriverApp(),
    ),
  );
}

// Brand colors - matching rider app
class FambaColors {
  static const primary = Color(0xFF8BD17C);
  static const primaryDark = Color(0xFF5BA34D);
  static const accent = Color(0xFF2D3436);
  static const background = Color(0xFF1A1A2E);  // Dark theme for driver
  static const surface = Color(0xFF16213E);
  static const card = Color(0xFF0F3460);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B0);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const online = Color(0xFF10B981);
  static const offline = Color(0xFF6B7280);
}

class FambaDriverApp extends StatelessWidget {
  const FambaDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Famba Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: FambaColors.primary,
        scaffoldBackgroundColor: FambaColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: FambaColors.surface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: FambaColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: FambaColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FambaColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: FambaColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const DriverHomeScreen(),
        '/ride-request': (_) => const RideRequestScreen(),
        '/navigation': (_) => const NavigationScreen(),
        '/delivery-navigation': (_) => const DeliveryNavigationScreen(),
        '/earnings': (_) => const EarningsScreen(),
        '/profile': (_) => const DriverProfileScreen(),
      },
    );
  }
}

