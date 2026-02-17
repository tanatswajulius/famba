import 'dart:convert';
import 'package:http/http.dart' as http;

class DriverApi {
  static String base = const String.fromEnvironment(
    'API_BASE', defaultValue: 'http://localhost:8000',
  );
  static String basicUser = const String.fromEnvironment('API_USER', defaultValue: 'demo');
  static String basicPass = const String.fromEnvironment('API_PASS', defaultValue: 'demo123');

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
  }) async {
    final res = await http.post(
      Uri.parse('$base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone, 'name': name,
        'password': password, 'user_type': 'driver',
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

  // ==================== JOBS ====================

  static Future<List<Map<String, dynamic>>> getAvailableJobs() async {
    final res = await http.get(Uri.parse('$base/jobs'), headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['jobs'] ?? []);
  }

  static Future<Map<String, dynamic>> getJob(String jobId) async {
    final res = await http.get(Uri.parse('$base/jobs/$jobId'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateJobStatus({
    required String jobId,
    required String status,
  }) async {
    final res = await http.put(
      Uri.parse('$base/jobs/$jobId/status'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(res.body);
  }

  // ==================== FOOD ORDERS ====================

  static Future<Map<String, dynamic>> getFoodOrder(String orderId) async {
    final res = await http.get(Uri.parse('$base/food-orders/$orderId'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateFoodOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final res = await http.post(
      Uri.parse('$base/food-orders/$orderId/status'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(res.body);
  }

  // ==================== EARNINGS ====================

  static Future<Map<String, dynamic>> getEarnings(String driverId) async {
    final res = await http.get(Uri.parse('$base/drivers/$driverId/earnings'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getLeaderboard() async {
    final res = await http.get(Uri.parse('$base/drivers/earnings/leaderboard'), headers: _headers());
    return jsonDecode(res.body);
  }

  // ==================== LOCATION ====================

  static Future<void> updateLocation({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    await http.post(
      Uri.parse('$base/drivers/$driverId/location'),
      headers: _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
  }

  // ==================== CHAT ====================

  static Future<Map<String, dynamic>> sendChatMessage({
    String? jobId,
    String? orderId,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse('$base/chat/send'),
      headers: _headers(),
      body: jsonEncode({
        if (jobId != null) 'job_id': jobId,
        if (orderId != null) 'order_id': orderId,
        'sender_type': 'driver',
        'message': message,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getChatHistory({
    String? jobId,
    String? orderId,
  }) async {
    var url = '$base/chat/history?limit=50';
    if (jobId != null) url += '&job_id=$jobId';
    if (orderId != null) url += '&order_id=$orderId';
    final res = await http.get(Uri.parse(url), headers: _headers());
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['messages'] ?? []);
  }

  // ==================== WebSocket URLs ====================

  static String get wsBase => base.replaceFirst('http', 'ws');

  static String get wsUrl => '$wsBase/ws/driver';

  static String wsChatRoom(String roomId) => '$wsBase/ws/chat/$roomId';
}
