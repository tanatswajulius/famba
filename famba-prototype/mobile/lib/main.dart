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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF8BD17C)),
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
