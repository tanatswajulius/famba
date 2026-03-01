import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class DriverApi {
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

  static Future<http.Response> _get(String url, {Map<String, String>? headers}) async {
    headers ??= _headers();
    try {
      return await http.get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 45));
    } catch (_) {
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

  static Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception('API error ${res.statusCode}');
  }

  static List<Map<String, dynamic>> _decodeList(http.Response res, String key) {
    final data = _decode(res);
    return List<Map<String, dynamic>>.from(data[key] ?? []);
  }

  // ==================== AUTH ====================

  static Future<Map<String, dynamic>> register({
    required String phone, required String name, required String password,
  }) async {
    final res = await _post('$base/auth/register',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name, 'password': password, 'user_type': 'driver'}));
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

  // ==================== JOBS ====================

  static Future<List<Map<String, dynamic>>> getAvailableJobs() async {
    final res = await _get('$base/jobs');
    return _decodeList(res, 'jobs');
  }

  static Future<Map<String, dynamic>> getJob(String jobId) async {
    final res = await _get('$base/jobs/$jobId');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateJobStatus({
    required String jobId, required String status,
  }) async {
    final res = await _put('$base/jobs/$jobId/status', body: jsonEncode({'status': status}));
    return _decode(res);
  }

  // ==================== FOOD ORDERS ====================

  static Future<Map<String, dynamic>> getFoodOrder(String orderId) async {
    final res = await _get('$base/food-orders/$orderId');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateFoodOrderStatus({
    required String orderId, required String status,
  }) async {
    final res = await _post('$base/food-orders/$orderId/status', body: jsonEncode({'status': status}));
    return _decode(res);
  }

  // ==================== EARNINGS ====================

  static Future<Map<String, dynamic>> getEarnings(String driverId) async {
    final res = await _get('$base/drivers/$driverId/earnings');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getLeaderboard() async {
    final res = await _get('$base/drivers/earnings/leaderboard');
    return _decode(res);
  }

  // ==================== LOCATION ====================

  static Future<void> updateLocation({
    required String driverId, required double lat, required double lng,
  }) async {
    await _post('$base/drivers/$driverId/location', body: jsonEncode({'lat': lat, 'lng': lng}));
  }

  // ==================== CHAT ====================

  static Future<Map<String, dynamic>> sendChatMessage({
    String? jobId, String? orderId, required String message,
  }) async {
    final res = await _post('$base/chat/send',
      body: jsonEncode({
        if (jobId != null) 'job_id': jobId,
        if (orderId != null) 'order_id': orderId,
        'sender_type': 'driver', 'message': message,
      }));
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getChatHistory({String? jobId, String? orderId}) async {
    var url = '$base/chat/history?limit=50';
    if (jobId != null) url += '&job_id=$jobId';
    if (orderId != null) url += '&order_id=$orderId';
    final res = await _get(url);
    return _decodeList(res, 'messages');
  }

  // ==================== EARNINGS & WITHDRAWALS ====================

  static Future<Map<String, dynamic>> getBalance(String driverId) async {
    final res = await _get('$base/drivers/$driverId/balance');
    return _decode(res);
  }

  static Future<Map<String, dynamic>> requestWithdrawal({
    required String driverId, required double amount,
    required String method, required String accountNumber,
  }) async {
    final res = await _post('$base/drivers/$driverId/withdraw',
      body: jsonEncode({'amount': amount, 'method': method, 'account_number': accountNumber}));
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getWithdrawals(String driverId) async {
    final res = await _get('$base/drivers/$driverId/withdrawals');
    return _decodeList(res, 'withdrawals');
  }

  // ==================== APP VERSION ====================

  static Future<Map<String, dynamic>> checkAppVersion({required String currentVersion}) async {
    final res = await _get('$base/app/version?platform=driver_android&current=$currentVersion');
    return _decode(res);
  }

  // ==================== WebSocket URLs ====================

  static String get wsBase => base.replaceFirst('http', 'ws');
  static String get wsUrl => '$wsBase/ws/driver';
  static String wsChatRoom(String roomId) => '$wsBase/ws/chat/$roomId';
}
