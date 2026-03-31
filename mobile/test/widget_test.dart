import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:famba_rider/core/app_state.dart';
import 'package:famba_rider/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('App boots', () {
    testWidgets('renders without crashing and shows famba on splash', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const FambaApp(),
        ),
      );
      await tester.pump();
      expect(find.text('famba'), findsOneWidget);
      expect(find.text('Move. Eat. Live.'), findsOneWidget);
      // Flush splash Future.delayed(2200ms) so no timer is left pending when the test ends.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('AppState', () {
    test('setAuth sets rider identity and tokens; isLoggedIn is true', () {
      final state = AppState();
      state.setAuth(
        userId: 'u1',
        name: 'Rider One',
        phone: '+263771234567',
        accessToken: 'at',
        refreshToken: 'rt',
      );
      expect(state.userId, 'u1');
      expect(state.riderName, 'Rider One');
      expect(state.phone, '+263771234567');
      expect(state.accessToken, 'at');
      expect(state.refreshToken, 'rt');
      expect(state.isLoggedIn, isTrue);
    });

    test('logout clears auth, wallet, and cart', () {
      final state = AppState()
        ..setAuth(
          userId: 'u1',
          name: 'Rider',
          phone: '123',
          accessToken: 't',
          refreshToken: 'r',
        );
      state.setWalletBalance(99.5);
      state.addToCart(
        CartItem(menuItemId: 1, name: 'Meal', price: 10),
        'r1',
        'Restaurant',
      );
      state.logout();
      expect(state.userId, isNull);
      expect(state.riderName, 'Guest');
      expect(state.phone, isNull);
      expect(state.accessToken, isNull);
      expect(state.refreshToken, isNull);
      expect(state.walletBalance, 0.0);
      expect(state.isLoggedIn, isFalse);
      expect(state.cartItems, isEmpty);
      expect(state.cartRestaurantId, isNull);
    });

    test('setJob and setOrder update active ids', () {
      final state = AppState();
      state.setJob('job-42');
      expect(state.activeJobId, 'job-42');
      state.setOrder('ord-7');
      expect(state.activeOrderId, 'ord-7');
    });

    test('setWalletBalance updates balance', () {
      final state = AppState();
      state.setWalletBalance(125.5);
      expect(state.walletBalance, 125.5);
    });

    test('toggleDarkMode flips isDarkMode', () {
      final state = AppState();
      expect(state.isDarkMode, isFalse);
      state.toggleDarkMode();
      expect(state.isDarkMode, isTrue);
      state.toggleDarkMode();
      expect(state.isDarkMode, isFalse);
    });

    test('addToCart adds item and sets restaurant', () {
      final state = AppState();
      final item = CartItem(menuItemId: 10, name: 'Burger', price: 5.5, qty: 2);
      state.addToCart(item, 'rest-1', 'Joe\'s');
      expect(state.cartRestaurantId, 'rest-1');
      expect(state.cartRestaurantName, 'Joe\'s');
      expect(state.cartItems, hasLength(1));
      expect(state.cartItems.first.menuItemId, 10);
      expect(state.cartItems.first.qty, 2);
      expect(state.cartCount, 2);
    });

    test('addToCart merges qty for same menuItemId', () {
      final state = AppState();
      state.addToCart(
        CartItem(menuItemId: 1, name: 'A', price: 1, qty: 1),
        'r',
        'R',
      );
      state.addToCart(
        CartItem(menuItemId: 1, name: 'A', price: 1, qty: 3),
        'r',
        'R',
      );
      expect(state.cartItems, hasLength(1));
      expect(state.cartItems.first.qty, 4);
      expect(state.cartCount, 4);
    });

    test('addToCart clears cart when switching restaurant', () {
      final state = AppState();
      state.addToCart(
        CartItem(menuItemId: 1, name: 'A', price: 1),
        'r1',
        'One',
      );
      state.addToCart(
        CartItem(menuItemId: 2, name: 'B', price: 2),
        'r2',
        'Two',
      );
      expect(state.cartRestaurantId, 'r2');
      expect(state.cartItems, hasLength(1));
      expect(state.cartItems.first.menuItemId, 2);
    });

    test('updateCartItemQty updates quantity', () {
      final state = AppState();
      state.addToCart(
        CartItem(menuItemId: 5, name: 'X', price: 3),
        'r',
        'R',
      );
      state.updateCartItemQty(5, 7);
      expect(state.cartItems.first.qty, 7);
    });

    test('updateCartItemQty with qty <= 0 removes item and clears restaurant when empty', () {
      final state = AppState();
      state.addToCart(
        CartItem(menuItemId: 9, name: 'Y', price: 1),
        'r',
        'R',
      );
      state.updateCartItemQty(9, 0);
      expect(state.cartItems, isEmpty);
      expect(state.cartRestaurantId, isNull);
      expect(state.cartRestaurantName, isNull);
    });

    test('clearCart empties items and restaurant', () {
      final state = AppState();
      state.addToCart(
        CartItem(menuItemId: 1, name: 'A', price: 1),
        'r',
        'R',
      );
      state.clearCart();
      expect(state.cartItems, isEmpty);
      expect(state.cartRestaurantId, isNull);
      expect(state.cartRestaurantName, isNull);
    });

    test('cartSubtotal sums price * qty', () {
      final state = AppState();
      state.addToCart(
        CartItem(menuItemId: 1, name: 'A', price: 10, qty: 2),
        'r',
        'R',
      );
      state.addToCart(
        CartItem(menuItemId: 2, name: 'B', price: 5, qty: 1),
        'r',
        'R',
      );
      expect(state.cartSubtotal, 25.0);
    });
  });

  group('CartItem', () {
    test('toJson maps fields with snake_case menu_item_id', () {
      final item = CartItem(
        menuItemId: 42,
        name: 'Sample',
        price: 9.99,
        qty: 3,
      );
      expect(
        item.toJson(),
        {
          'menu_item_id': 42,
          'name': 'Sample',
          'price': 9.99,
          'qty': 3,
        },
      );
    });
  });

  group('Navigation', () {
    testWidgets('after splash timer, navigates to login', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const FambaApp(),
        ),
      );
      await tester.pump();
      expect(find.text('famba'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      // Tab label and primary button both use "Sign In".
      expect(find.text('Sign In'), findsNWidgets(2));
      expect(find.text('Phone Number'), findsOneWidget);
    });
  });
}
