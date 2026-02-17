import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_state.dart';
import 'core/offline_queue.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/quote_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/saved_places_screen.dart';
import 'screens/promo_screen.dart';
import 'screens/schedule_ride_screen.dart';
import 'screens/referrals_screen.dart';
import 'screens/driver_earnings_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/restaurants_screen.dart';
import 'screens/restaurant_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/food_order_tracking_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  // Initialize and flush offline queue
  final queue = await OfflineQueue.getInstance();
  queue.flush();
  
  runApp(ChangeNotifierProvider(
      create: (_) => AppState(), child: const FambaApp()));
}

// Brand colors
class FambaColors {
  static const primary = Color(0xFF8BD17C);
  static const primaryDark = Color(0xFF5BA34D);
  static const accent = Color(0xFF2D3436);
  static const background = Color(0xFFF8FAF7);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
}

class FambaApp extends StatelessWidget {
  const FambaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Famba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: FambaColors.primary,
        scaffoldBackgroundColor: FambaColors.background,
        fontFamily: 'SF Pro Display',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: FambaColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: FambaColors.textPrimary),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: FambaColors.textPrimary,
          ),
          displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: FambaColors.textPrimary,
          ),
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: FambaColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: FambaColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: FambaColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: FambaColors.textPrimary,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FambaColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: FambaColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: FambaColors.textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: FambaColors.textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FambaColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: FambaColors.textPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FambaColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(
            color: FambaColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w400,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          color: Colors.white,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: FambaColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade100,
          thickness: 1,
          space: 1,
        ),
      ),
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/quote': (_) => const QuoteScreen(),
        '/track': (_) => const TrackingScreen(),
        '/wallet': (_) => const WalletScreen(),
        '/history': (_) => const HistoryScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/receipt': (_) => const ReceiptScreen(),
        '/saved-places': (_) => const SavedPlacesScreen(),
        '/promo': (_) => const PromoScreen(),
        '/schedule': (_) => const ScheduleRideScreen(),
        '/referrals': (_) => const ReferralsScreen(),
        '/driver-earnings': (_) => const DriverEarningsScreen(),
        '/chat': (_) => const ChatScreen(),
        '/restaurants': (_) => const RestaurantsScreen(),
        '/restaurant-detail': (_) => const RestaurantDetailScreen(),
        '/cart': (_) => const CartScreen(),
        '/food-order-tracking': (_) => const FoodOrderTrackingScreen(),
        '/order-history': (_) => const HistoryScreen(),
      },
    );
  }
}
