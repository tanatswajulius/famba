import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_queue.dart';

class Api {
  static String base = _resolveBase();

  static String _resolveBase() {
    const env = String.fromEnvironment('API_BASE');
    if (env.isNotEmpty) return env;
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return 'http://localhost:8000';
    }
    return 'https://famba-api.onrender.com';
  }
  static String basicUser = const String.fromEnvironment('API_USER', defaultValue: 'demo');
  static String basicPass = const String.fromEnvironment('API_PASS', defaultValue: 'demo123');

  // JWT token - set after login/register
  static String? _jwtToken;
  static void setToken(String? token) => _jwtToken = token;

  static String get _basicAuth => 'Basic ${base64Encode(utf8.encode('$basicUser:$basicPass'))}';

  static Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Authorization': _jwtToken != null ? 'Bearer $_jwtToken' : _basicAuth,
  };

  // ==================== AUTH ====================

  static Future<Map<String, dynamic>> register({
    required String phone,
    required String name,
    required String password,
    String userType = 'rider',
  }) async {
    final res = await http.post(
      Uri.parse('$base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone, 'name': name,
        'password': password, 'user_type': userType,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse('$base/auth/me'), headers: _headers());
    return jsonDecode(res.body);
  }

  // ==================== RIDES ====================

  static Future<Map<String, dynamic>> quote({
    required String pickup,
    required String drop,
    required double distanceKm,
    bool peak = false,
  }) async {
    final res = await http.post(Uri.parse('$base/quote'),
      headers: _headers(),
      body: jsonEncode({
        'pickup_text': pickup, 'drop_text': drop,
        'distance_km': distanceKm, 'peak': peak,
      }));
    if (res.statusCode != 200) {
      throw Exception('Server error ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createJob({
    required String pickup,
    required String drop,
    required double distanceKm,
    required String riderName,
    String? driverId,
    double? fareUsd,
    String? paymentMethod,
  }) async {
    final url = '$base/jobs';
    final headers = _headers();
    final body = jsonEncode({
      'pickup_text': pickup, 'drop_text': drop,
      'distance_km': distanceKm, 'rider_name': riderName,
      if (driverId != null) 'driver_id': driverId,
      if (fareUsd != null) 'fare_usd': fareUsd,
      if (paymentMethod != null) 'payment_method': paymentMethod,
    });

    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || results.first == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }
      final res = await http.post(Uri.parse(url), headers: headers, body: body);
      return jsonDecode(res.body);
    } catch (e) {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final queue = await OfflineQueue.getInstance();
      await queue.enqueue(QueuedRequest(url: url, headers: headers, body: body, tempId: tempId));
      return {
        'id': tempId, 'status': 'queued',
        'pickup_text': pickup, 'drop_text': drop,
        'distance_km': distanceKm, 'rider_name': riderName,
      };
    }
  }

  static Future<Map<String, dynamic>> getJob(String id) async {
    final res = await http.get(Uri.parse('$base/jobs/$id'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> reportIssue({String? jobId, required String issueType}) async {
    final res = await http.post(Uri.parse('$base/issues'), headers: _headers(),
      body: jsonEncode({'job_id': jobId, 'issue_type': issueType}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> recommend({required String corridor}) async {
    final res = await http.post(Uri.parse('$base/recommend'), headers: _headers(),
      body: jsonEncode({'corridor': corridor}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> rateRide({
    required String jobId, required String driverId,
    required double rating, String? comment,
  }) async {
    final res = await http.post(Uri.parse('$base/ratings'), headers: _headers(),
      body: jsonEncode({'job_id': jobId, 'driver_id': driverId, 'rating': rating, 'comment': comment}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> validatePromo({required String code}) async {
    final res = await http.post(Uri.parse('$base/promo/validate'), headers: _headers(),
      body: jsonEncode({'code': code}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> cancelJob({required String jobId, required String reason}) async {
    final res = await http.post(Uri.parse('$base/jobs/$jobId/cancel'), headers: _headers(),
      body: jsonEncode({'reason': reason}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> scheduleJob({
    required String pickup, required String drop, required double distanceKm,
    required String riderName, required DateTime scheduledTime, String? paymentMethod,
  }) async {
    final res = await http.post(Uri.parse('$base/jobs/schedule'), headers: _headers(),
      body: jsonEncode({
        'pickup_text': pickup, 'drop_text': drop,
        'distance_km': distanceKm, 'rider_name': riderName,
        'scheduled_time': scheduledTime.toIso8601String(), 'payment_method': paymentMethod,
      }));
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> searchLocations({required String query, int limit = 10}) async {
    final res = await http.get(
      Uri.parse('$base/locations/search?q=${Uri.encodeComponent(query)}&limit=$limit'),
      headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['locations'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getPopularLocations({int limit = 10}) async {
    final res = await http.get(Uri.parse('$base/locations/popular?limit=$limit'), headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['locations'] ?? []);
  }

  static Future<Map<String, dynamic>> quickEstimate({
    required String pickup, required String drop, required double distanceKm,
  }) async {
    final res = await http.post(Uri.parse('$base/estimate'), headers: _headers(),
      body: jsonEncode({'pickup_text': pickup, 'drop_text': drop, 'distance_km': distanceKm}));
    return jsonDecode(res.body);
  }

  // Referrals
  static Future<Map<String, dynamic>> createReferralCode({required String name, String? phone}) async {
    final res = await http.post(Uri.parse('$base/referrals/create'), headers: _headers(),
      body: jsonEncode({'name': name, 'phone': phone}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getReferralInfo(String code) async {
    final res = await http.get(Uri.parse('$base/referrals/$code'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> applyReferralCode({required String code, required String name, String? phone}) async {
    final res = await http.post(Uri.parse('$base/referrals/apply'), headers: _headers(),
      body: jsonEncode({'code': code, 'name': name, 'phone': phone}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getReferralStats(String code) async {
    final res = await http.get(Uri.parse('$base/referrals/$code/stats'), headers: _headers());
    return jsonDecode(res.body);
  }

  // Driver earnings
  static Future<Map<String, dynamic>> getDriverEarnings(String driverId) async {
    final res = await http.get(Uri.parse('$base/drivers/$driverId/earnings'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getEarningsLeaderboard() async {
    final res = await http.get(Uri.parse('$base/drivers/earnings/leaderboard'), headers: _headers());
    return jsonDecode(res.body);
  }

  // Multi-stop
  static Future<Map<String, dynamic>> createMultiStopJob({
    required String pickup, required String drop,
    required List<Map<String, dynamic>> waypoints,
    required double totalDistanceKm, required String riderName,
    String? driverId, String? paymentMethod,
    double? pickupLat, double? pickupLng, double? dropLat, double? dropLng,
  }) async {
    final res = await http.post(Uri.parse('$base/jobs/multi-stop'), headers: _headers(),
      body: jsonEncode({
        'pickup_text': pickup, 'drop_text': drop, 'waypoints': waypoints,
        'total_distance_km': totalDistanceKm, 'rider_name': riderName,
        if (driverId != null) 'driver_id': driverId,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
        if (dropLat != null) 'drop_lat': dropLat,
        if (dropLng != null) 'drop_lng': dropLng,
      }));
    return jsonDecode(res.body);
  }

  // ==================== FOOD DELIVERY ====================

  static Future<List<Map<String, dynamic>>> getRestaurants({
    String? category, String? area, bool featured = false,
  }) async {
    var url = '$base/restaurants?limit=50';
    if (category != null) url += '&category=$category';
    if (area != null) url += '&area=$area';
    if (featured) url += '&featured=true';
    final res = await http.get(Uri.parse(url), headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['restaurants'] ?? []);
  }

  static Future<Map<String, dynamic>> getRestaurant(String id) async {
    final res = await http.get(Uri.parse('$base/restaurants/$id'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    final res = await http.get(
      Uri.parse('$base/restaurants/search?q=${Uri.encodeComponent(query)}'),
      headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['restaurants'] ?? []);
  }

  static Future<Map<String, dynamic>> createFoodOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    double? deliveryLat, double? deliveryLng,
    String paymentMethod = 'cash',
    String? riderName, String? riderPhone,
    String? specialInstructions, String? promoCode,
  }) async {
    final res = await http.post(Uri.parse('$base/food-orders'), headers: _headers(),
      body: jsonEncode({
        'restaurant_id': restaurantId, 'items': items,
        'delivery_address': deliveryAddress,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
        'payment_method': paymentMethod,
        if (riderName != null) 'rider_name': riderName,
        if (riderPhone != null) 'rider_phone': riderPhone,
        if (specialInstructions != null) 'special_instructions': specialInstructions,
        if (promoCode != null) 'promo_code': promoCode,
      }));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getFoodOrder(String orderId) async {
    final res = await http.get(Uri.parse('$base/food-orders/$orderId'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> cancelFoodOrder({required String orderId, String? reason}) async {
    final res = await http.post(Uri.parse('$base/food-orders/$orderId/cancel'), headers: _headers(),
      body: jsonEncode({'reason': reason ?? 'Customer cancelled'}));
    return jsonDecode(res.body);
  }

  // ==================== WALLET ====================

  static Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await http.get(Uri.parse('$base/wallet/balance'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> walletTopUp({required double amount, String method = 'ecocash'}) async {
    final res = await http.post(Uri.parse('$base/wallet/top-up'), headers: _headers(),
      body: jsonEncode({'amount': amount, 'method': method}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> walletPay({
    required double amount, required String referenceId,
    String type = 'ride_payment', String? description,
  }) async {
    final res = await http.post(Uri.parse('$base/wallet/pay'), headers: _headers(),
      body: jsonEncode({
        'amount': amount, 'reference_id': referenceId,
        'type': type, 'description': description,
      }));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getWalletTransactions() async {
    final res = await http.get(Uri.parse('$base/wallet/transactions'), headers: _headers());
    return jsonDecode(res.body);
  }

  // ==================== PROFILE ====================

  static Future<Map<String, dynamic>> updateProfile({String? name, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    final res = await http.put(Uri.parse('$base/users/me'), headers: _headers(),
      body: jsonEncode(body));
    return jsonDecode(res.body);
  }

  // ==================== FOOD RATINGS ====================

  static Future<Map<String, dynamic>> rateFoodOrder({
    required String orderId,
    required String restaurantId,
    required double foodRating,
    double? deliveryRating,
    String? comment,
  }) async {
    final res = await http.post(
      Uri.parse('$base/food-orders/$orderId/rate'),
      headers: _headers(),
      body: jsonEncode({
        'order_id': orderId,
        'restaurant_id': restaurantId,
        'food_rating': foodRating,
        if (deliveryRating != null) 'delivery_rating': deliveryRating,
        if (comment != null) 'comment': comment,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getRestaurantRatings(
      String restaurantId,
      {int limit = 20}) async {
    final res = await http.get(
      Uri.parse('$base/restaurants/$restaurantId/ratings?limit=$limit'),
      headers: _headers(),
    );
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['ratings'] ?? []);
  }

  // ==================== CHAT ====================

  static Future<Map<String, dynamic>> sendChatMessage({
    String? jobId,
    String? orderId,
    required String message,
    String senderType = 'rider',
  }) async {
    final res = await http.post(
      Uri.parse('$base/chat/send'),
      headers: _headers(),
      body: jsonEncode({
        if (jobId != null) 'job_id': jobId,
        if (orderId != null) 'order_id': orderId,
        'sender_type': senderType,
        'message': message,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getChatHistory({
    String? jobId,
    String? orderId,
    int limit = 50,
  }) async {
    var url = '$base/chat/history?limit=$limit';
    if (jobId != null) url += '&job_id=$jobId';
    if (orderId != null) url += '&order_id=$orderId';
    final res = await http.get(Uri.parse(url), headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['messages'] ?? []);
  }

  // ==================== UNIFIED HISTORY ====================

  static Future<List<Map<String, dynamic>>> getOrderHistory({int limit = 50}) async {
    final res = await http.get(
      Uri.parse('$base/history?limit=$limit'),
      headers: _headers(),
    );
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['history'] ?? []);
  }

  // ==================== OTP ====================

  static Future<Map<String, dynamic>> sendOtp({required String phone, String purpose = 'verify'}) async {
    final res = await http.post(Uri.parse('$base/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'purpose': purpose}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> verifyOtp({required String phone, required String code, String purpose = 'verify'}) async {
    final res = await http.post(Uri.parse('$base/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code, 'purpose': purpose}));
    return jsonDecode(res.body);
  }

  // ==================== FAVORITES ====================

  static Future<List<Map<String, dynamic>>> getFavoritePlaces() async {
    final res = await http.get(Uri.parse('$base/favorites/places'), headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['places'] ?? []);
  }

  static Future<Map<String, dynamic>> saveFavoritePlace({
    required String label, required String name,
    String? address, double? lat, double? lng,
  }) async {
    final res = await http.post(Uri.parse('$base/favorites/places'), headers: _headers(),
      body: jsonEncode({
        'label': label, 'name': name,
        if (address != null) 'address': address,
        if (lat != null) 'lat': lat, if (lng != null) 'lng': lng,
      }));
    return jsonDecode(res.body);
  }

  static Future<void> deleteFavoritePlace(int id) async {
    await http.delete(Uri.parse('$base/favorites/places/$id'), headers: _headers());
  }

  static Future<List<Map<String, dynamic>>> getFavoriteRestaurants() async {
    final res = await http.get(Uri.parse('$base/favorites/restaurants'), headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['restaurants'] ?? []);
  }

  static Future<Map<String, dynamic>> saveFavoriteRestaurant(String restaurantId) async {
    final res = await http.post(Uri.parse('$base/favorites/restaurants'), headers: _headers(),
      body: jsonEncode({'restaurant_id': restaurantId}));
    return jsonDecode(res.body);
  }

  static Future<void> removeFavoriteRestaurant(int favId) async {
    await http.delete(Uri.parse('$base/favorites/restaurants/$favId'), headers: _headers());
  }

  // ==================== GEOFENCING ====================

  static Future<Map<String, dynamic>> checkGeofence({required double lat, required double lng}) async {
    final res = await http.get(Uri.parse('$base/geofence/check?lat=$lat&lng=$lng'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> validateRideGeofence({
    required double pickupLat, required double pickupLng,
    required double dropLat, required double dropLng,
  }) async {
    final res = await http.post(Uri.parse('$base/geofence/validate-ride'), headers: _headers(),
      body: jsonEncode({
        'pickup_lat': pickupLat, 'pickup_lng': pickupLng,
        'drop_lat': dropLat, 'drop_lng': dropLng,
      }));
    return jsonDecode(res.body);
  }

  // ==================== APP VERSION ====================

  static Future<Map<String, dynamic>> checkAppVersion({
    String platform = 'rider_android', required String currentVersion,
  }) async {
    final res = await http.get(
      Uri.parse('$base/app/version?platform=$platform&current=$currentVersion'));
    return jsonDecode(res.body);
  }

  // ==================== RECEIPTS ====================

  static String rideReceiptUrl(String jobId) => '$base/receipts/ride/$jobId';
  static String foodReceiptUrl(String orderId) => '$base/receipts/food/$orderId';

  // ==================== WebSocket URLs ====================

  static String get wsBase => base.replaceFirst('http', 'ws');

  static String wsTrackJob(String jobId) =>
      '$wsBase/ws/track/$jobId?token=$basicUser:$basicPass';

  static String wsDriverLocation(String driverId) =>
      '$wsBase/ws/driver/$driverId';

  static String wsChatRoom(String roomId) =>
      '$wsBase/ws/chat/$roomId';
}
