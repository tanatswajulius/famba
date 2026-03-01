import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  String riderName = "Guest";
  String riderEmail = "";
  String? userId;
  String? phone;
  String? accessToken;
  String? refreshToken;
  String? activeJobId;
  String? activeOrderId;
  double walletBalance = 0.0;
  bool isDarkMode = false;

  String get riderPhone => phone ?? "";

  // Cart state for food delivery
  String? cartRestaurantId;
  String? cartRestaurantName;
  List<CartItem> cartItems = [];

  bool get isLoggedIn => accessToken != null;
  int get cartCount => cartItems.fold(0, (sum, item) => sum + item.qty);
  double get cartSubtotal => cartItems.fold(0, (sum, item) => sum + (item.price * item.qty));

  void setAuth({
    required String userId,
    required String name,
    required String phone,
    required String accessToken,
    required String refreshToken,
  }) {
    this.userId = userId;
    riderName = name;
    this.phone = phone;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    _saveAuth();
    notifyListeners();
  }

  void logout() {
    userId = null;
    riderName = "Guest";
    phone = null;
    accessToken = null;
    refreshToken = null;
    walletBalance = 0.0;
    clearCart();
    _clearAuth();
    notifyListeners();
  }

  void setJob(String id) {
    activeJobId = id;
    notifyListeners();
  }

  void setOrder(String id) {
    activeOrderId = id;
    notifyListeners();
  }

  void setWalletBalance(double balance) {
    walletBalance = balance;
    notifyListeners();
  }

  void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    _saveDarkMode();
    notifyListeners();
  }

  // Cart methods
  void addToCart(CartItem item, String restaurantId, String restaurantName) {
    if (cartRestaurantId != null && cartRestaurantId != restaurantId) {
      cartItems.clear();
    }
    cartRestaurantId = restaurantId;
    cartRestaurantName = restaurantName;

    final existing = cartItems.indexWhere((i) => i.menuItemId == item.menuItemId);
    if (existing >= 0) {
      cartItems[existing].qty += item.qty;
    } else {
      cartItems.add(item);
    }
    notifyListeners();
  }

  void updateCartItemQty(int menuItemId, int qty) {
    final idx = cartItems.indexWhere((i) => i.menuItemId == menuItemId);
    if (idx >= 0) {
      if (qty <= 0) {
        cartItems.removeAt(idx);
      } else {
        cartItems[idx].qty = qty;
      }
      if (cartItems.isEmpty) {
        cartRestaurantId = null;
        cartRestaurantName = null;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    cartItems.clear();
    cartRestaurantId = null;
    cartRestaurantName = null;
    notifyListeners();
  }

  // Persistence
  Future<void> _saveAuth() async {
    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null) prefs.setString('access_token', accessToken!);
    if (refreshToken != null) prefs.setString('refresh_token', refreshToken!);
    if (userId != null) prefs.setString('user_id', userId!);
    prefs.setString('rider_name', riderName);
    if (phone != null) prefs.setString('phone', phone!);
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('access_token');
    prefs.remove('refresh_token');
    prefs.remove('user_id');
    prefs.remove('rider_name');
    prefs.remove('phone');
  }

  Future<void> _saveDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('dark_mode', isDarkMode);
  }

  Future<bool> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      accessToken = token;
      refreshToken = prefs.getString('refresh_token');
      userId = prefs.getString('user_id');
      riderName = prefs.getString('rider_name') ?? "Guest";
      phone = prefs.getString('phone');
      notifyListeners();
      return true;
    }
    // Load dark mode preference regardless of auth
    isDarkMode = prefs.getBool('dark_mode') ?? false;
    notifyListeners();
    return false;
  }
}

class CartItem {
  final int menuItemId;
  final String name;
  final double price;
  int qty;

  CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.qty = 1,
  });

  Map<String, dynamic> toJson() => {
    'menu_item_id': menuItemId,
    'name': name,
    'price': price,
    'qty': qty,
  };
}
