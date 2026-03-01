import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

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

  static String? _jwtToken;
  static void setToken(String? token) => _jwtToken = token;

  static String get _basicAuth => 'Basic ${base64Encode(utf8.encode('$basicUser:$basicPass'))}';

  static Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Authorization': _jwtToken != null ? 'Bearer $_jwtToken' : _basicAuth,
  };

  // Central HTTP methods with 45s timeout and retry on first failure.
  // Render free tier can take 30-60s to wake up on first request.
  static Future<http.Response> _get(String url, {Map<String, String>? headers}) async {
    headers ??= _headers();
    try {
      return await http.get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      // One retry for cold-start
      return await http.get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 45));
    }
  }

  static Future<http.Response> _post(String url, {Map<String, String>? headers, Object? body}) async {
    headers ??= _headers();
    try {
      return await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      return await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 45));
    }
  }

  static Future<http.Response> _put(String url, {Map<String, String>? headers, Object? body}) async {
    headers ??= _headers();
    try {
      return await http.put(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      return await http.put(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 45));
    }
  }

  static Future<http.Response> _delete(String url, {Map<String, String>? headers}) async {
    headers ??= _headers();
    try {
      return await http.delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      return await http.delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 45));
    }
  }

  static Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  static List<Map<String, dynamic>> _decodeList(http.Response res, String key) {
    final data = _decode(res);
    return List<Map<String, dynamic>>.from(data[key] ?? []);
  }

  // ==================== AUTH ====================

  static Future<Map<String, dynamic>> register({
    required String phone, required String name,
    required String password, String userType = 'rider',
  }) async {
    final res = await _post('$base/auth/register',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name, 'password': password, 'user_type': userType}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> login({
    required String phone, required String password,
  }) async {
    final res = await _post('$base/auth/login',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await _get('$base/auth/me');
    return _decode(res);
  }

  // ==================== RIDES ====================

  static Future<Map<String, dynamic>> quote({
    required String pickup, required String drop,
    required double distanceKm, bool peak = false,
  }) async {
    final res = await _post('$base/quote',
      body: jsonEncode({'pickup_text': pickup, 'drop_text': drop, 'distance_km': distanceKm, 'peak': peak}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> createJob({
    required String pickup, required String drop,
    required double distanceKm, required String riderName,
    String? driverId, double? fareUsd, String? paymentMethod,
  }) async {
    final res = await _post('$base/jobs',
      body: jsonEncode({
        'pickup_text': pickup, 'drop_text': drop,
        'distance_km': distanceKm, 'rider_name': riderName,
        if (driverId != null) 'driver_id': driverId,
        if (fareUsd != null) 'fare_usd': fareUsd,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      }));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getJob(String id) async {
    final res = await _get('$base/jobs/$id');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> reportIssue({String? jobId, required String issueType}) async {
    final res = await _post('$base/issues', body: jsonEncode({'job_id': jobId, 'issue_type': issueType}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> recommend({required String corridor}) async {
    final res = await _post('$base/recommend', body: jsonEncode({'corridor': corridor}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> rateRide({
    required String jobId, required String driverId,
    required double rating, String? comment,
  }) async {
    final res = await _post('$base/ratings',
      body: jsonEncode({'job_id': jobId, 'driver_id': driverId, 'rating': rating, 'comment': comment}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> validatePromo({required String code}) async {
    final res = await _post('$base/promo/validate', body: jsonEncode({'code': code}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> cancelJob({required String jobId, required String reason}) async {
    final res = await _post('$base/jobs/$jobId/cancel', body: jsonEncode({'reason': reason}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> scheduleJob({
    required String pickup, required String drop, required double distanceKm,
    required String riderName, required DateTime scheduledTime, String? paymentMethod,
  }) async {
    final res = await _post('$base/jobs/schedule',
      body: jsonEncode({
        'pickup_text': pickup, 'drop_text': drop, 'distance_km': distanceKm,
        'rider_name': riderName, 'scheduled_time': scheduledTime.toIso8601String(),
        'payment_method': paymentMethod,
      }));
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> searchLocations({required String query, int limit = 10}) async {
    final res = await _get('$base/locations/search?q=${Uri.encodeComponent(query)}&limit=$limit');
    return _decodeList(res, 'locations');
  }

  static Future<List<Map<String, dynamic>>> getPopularLocations({int limit = 10}) async {
    final res = await _get('$base/locations/popular?limit=$limit');
    return _decodeList(res, 'locations');
  }

  static Future<Map<String, dynamic>> quickEstimate({
    required String pickup, required String drop, required double distanceKm,
  }) async {
    final res = await _post('$base/estimate',
      body: jsonEncode({'pickup_text': pickup, 'drop_text': drop, 'distance_km': distanceKm}));
    return _decode(res);
  }

  // Referrals
  static Future<Map<String, dynamic>> createReferralCode({required String name, String? phone}) async {
    final res = await _post('$base/referrals/create', body: jsonEncode({'name': name, 'phone': phone}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getReferralInfo(String code) async {
    final res = await _get('$base/referrals/$code');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> applyReferralCode({required String code, required String name, String? phone}) async {
    final res = await _post('$base/referrals/apply', body: jsonEncode({'code': code, 'name': name, 'phone': phone}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getReferralStats(String code) async {
    final res = await _get('$base/referrals/$code/stats');
    return _decode(res);
  }

  // Driver earnings
  static Future<Map<String, dynamic>> getDriverEarnings(String driverId) async {
    final res = await _get('$base/drivers/$driverId/earnings');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getEarningsLeaderboard() async {
    final res = await _get('$base/drivers/earnings/leaderboard');
    return _decode(res);
  }

  // Multi-stop
  static Future<Map<String, dynamic>> createMultiStopJob({
    required String pickup, required String drop,
    required List<Map<String, dynamic>> waypoints,
    required double totalDistanceKm, required String riderName,
    String? driverId, String? paymentMethod,
    double? pickupLat, double? pickupLng, double? dropLat, double? dropLng,
  }) async {
    final res = await _post('$base/jobs/multi-stop',
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
    return _decode(res);
  }

  // ==================== FOOD DELIVERY ====================

  static Future<List<Map<String, dynamic>>> getRestaurants({
    String? category, String? area, bool featured = false,
  }) async {
    var url = '$base/restaurants?limit=50';
    if (category != null) url += '&category=$category';
    if (area != null) url += '&area=$area';
    if (featured) url += '&featured=true';
    final res = await _get(url);
    return _decodeList(res, 'restaurants');
  }

  static Future<Map<String, dynamic>> getRestaurant(String id) async {
    final res = await _get('$base/restaurants/$id');
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    final res = await _get('$base/restaurants/search?q=${Uri.encodeComponent(query)}');
    return _decodeList(res, 'restaurants');
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
    final res = await _post('$base/food-orders',
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
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getFoodOrder(String orderId) async {
    final res = await _get('$base/food-orders/$orderId');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> cancelFoodOrder({required String orderId, String? reason}) async {
    final res = await _post('$base/food-orders/$orderId/cancel',
      body: jsonEncode({'reason': reason ?? 'Customer cancelled'}));
    return _decode(res);
  }

  // ==================== WALLET ====================

  static Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await _get('$base/wallet/balance');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> walletTopUp({required double amount, String method = 'ecocash'}) async {
    final res = await _post('$base/wallet/top-up', body: jsonEncode({'amount': amount, 'method': method}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> walletPay({
    required double amount, required String referenceId,
    String type = 'ride_payment', String? description,
  }) async {
    final res = await _post('$base/wallet/pay',
      body: jsonEncode({'amount': amount, 'reference_id': referenceId, 'type': type, 'description': description}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWalletTransactions() async {
    final res = await _get('$base/wallet/transactions');
    return _decode(res);
  }

  // ==================== PROFILE ====================

  static Future<Map<String, dynamic>> updateProfile({String? name, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    final res = await _put('$base/users/me', body: jsonEncode(body));
    return _decode(res);
  }

  // ==================== FOOD RATINGS ====================

  static Future<Map<String, dynamic>> rateFoodOrder({
    required String orderId, required String restaurantId,
    required double foodRating, double? deliveryRating, String? comment,
  }) async {
    final res = await _post('$base/food-orders/$orderId/rate',
      body: jsonEncode({
        'order_id': orderId, 'restaurant_id': restaurantId, 'food_rating': foodRating,
        if (deliveryRating != null) 'delivery_rating': deliveryRating,
        if (comment != null) 'comment': comment,
      }));
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getRestaurantRatings(String restaurantId, {int limit = 20}) async {
    final res = await _get('$base/restaurants/$restaurantId/ratings?limit=$limit');
    return _decodeList(res, 'ratings');
  }

  // ==================== CHAT ====================

  static Future<Map<String, dynamic>> sendChatMessage({
    String? jobId, String? orderId,
    required String message, String senderType = 'rider',
  }) async {
    final res = await _post('$base/chat/send',
      body: jsonEncode({
        if (jobId != null) 'job_id': jobId,
        if (orderId != null) 'order_id': orderId,
        'sender_type': senderType, 'message': message,
      }));
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getChatHistory({String? jobId, String? orderId, int limit = 50}) async {
    var url = '$base/chat/history?limit=$limit';
    if (jobId != null) url += '&job_id=$jobId';
    if (orderId != null) url += '&order_id=$orderId';
    final res = await _get(url);
    return _decodeList(res, 'messages');
  }

  // ==================== UNIFIED HISTORY ====================

  static Future<List<Map<String, dynamic>>> getOrderHistory({int limit = 50}) async {
    final res = await _get('$base/history?limit=$limit');
    return _decodeList(res, 'history');
  }

  // ==================== OTP ====================

  static Future<Map<String, dynamic>> sendOtp({required String phone, String purpose = 'verify'}) async {
    final res = await _post('$base/otp/send',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'purpose': purpose}));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> verifyOtp({required String phone, required String code, String purpose = 'verify'}) async {
    final res = await _post('$base/otp/verify',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code, 'purpose': purpose}));
    return _decode(res);
  }

  // ==================== FAVORITES ====================

  static Future<List<Map<String, dynamic>>> getFavoritePlaces() async {
    final res = await _get('$base/favorites/places');
    return _decodeList(res, 'places');
  }

  static Future<Map<String, dynamic>> saveFavoritePlace({
    required String label, required String name,
    String? address, double? lat, double? lng,
  }) async {
    final res = await _post('$base/favorites/places',
      body: jsonEncode({
        'label': label, 'name': name,
        if (address != null) 'address': address,
        if (lat != null) 'lat': lat, if (lng != null) 'lng': lng,
      }));
    return _decode(res);
  }

  static Future<void> deleteFavoritePlace(int id) async {
    await _delete('$base/favorites/places/$id');
  }

  static Future<List<Map<String, dynamic>>> getFavoriteRestaurants() async {
    final res = await _get('$base/favorites/restaurants');
    return _decodeList(res, 'restaurants');
  }

  static Future<Map<String, dynamic>> saveFavoriteRestaurant(String restaurantId) async {
    final res = await _post('$base/favorites/restaurants', body: jsonEncode({'restaurant_id': restaurantId}));
    return _decode(res);
  }

  static Future<void> removeFavoriteRestaurant(int favId) async {
    await _delete('$base/favorites/restaurants/$favId');
  }

  // ==================== GEOFENCING ====================

  static Future<Map<String, dynamic>> checkGeofence({required double lat, required double lng}) async {
    final res = await _get('$base/geofence/check?lat=$lat&lng=$lng');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> validateRideGeofence({
    required double pickupLat, required double pickupLng,
    required double dropLat, required double dropLng,
  }) async {
    final res = await _post('$base/geofence/validate-ride',
      body: jsonEncode({'pickup_lat': pickupLat, 'pickup_lng': pickupLng, 'drop_lat': dropLat, 'drop_lng': dropLng}));
    return _decode(res);
  }

  // ==================== APP VERSION ====================

  static Future<Map<String, dynamic>> checkAppVersion({
    String platform = 'rider_android', required String currentVersion,
  }) async {
    final res = await _get('$base/app/version?platform=$platform&current=$currentVersion');
    return _decode(res);
  }

  // ==================== RECEIPTS ====================

  static String rideReceiptUrl(String jobId) => '$base/receipts/ride/$jobId';
  static String foodReceiptUrl(String orderId) => '$base/receipts/food/$orderId';

  // ==================== WebSocket URLs ====================

  static String get wsBase => base.replaceFirst('http', 'ws');
  static String wsTrackJob(String jobId) => '$wsBase/ws/track/$jobId?token=$basicUser:$basicPass';
  static String wsDriverLocation(String driverId) => '$wsBase/ws/driver/$driverId';
  static String wsChatRoom(String roomId) => '$wsBase/ws/chat/$roomId';
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);
  @override
  String toString() => 'API error $statusCode';
}
