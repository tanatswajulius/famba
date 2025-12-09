import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_state.dart';
import 'core/offline_queue.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/quote_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/wallet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize and flush offline queue
  final queue = await OfflineQueue.getInstance();
  queue.flush();
  
  runApp(ChangeNotifierProvider(
      create: (_) => AppState(), child: const FambaApp()));
}

class FambaApp extends StatelessWidget {
  const FambaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Famba',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8BD17C),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(fontSize: 14.5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: const Color(0xFF8BD17C)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        chipTheme: ChipThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/quote': (_) => const QuoteScreen(),
        '/track': (_) => const TrackingScreen(),
        '/wallet': (_) => const WalletScreen(),
      },
    );
  }
}
