import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_queue.dart';

class Api {
  static String base = const String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');
  static String basicUser = const String.fromEnvironment('API_USER', defaultValue: 'demo');
  static String basicPass = const String.fromEnvironment('API_PASS', defaultValue: 'demo123');

  static String get _authHeader => 'Basic ${base64Encode(utf8.encode('$basicUser:$basicPass'))}';
  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': _authHeader,
      };

  static Future<Map<String, dynamic>> quote({
    required String pickup,
    required String drop,
    required double distanceKm,
    bool peak = false,
  }) async {
    final res = await http.post(Uri.parse('$base/quote'),
      headers: _headers(),
      body: jsonEncode({'pickup_text': pickup, 'drop_text': drop, 'distance_km': distanceKm, 'peak': peak}));
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
      'pickup_text': pickup,
      'drop_text': drop,
      'distance_km': distanceKm,
      'rider_name': riderName,
      if (driverId != null) 'driver_id': driverId,
      if (fareUsd != null) 'fare_usd': fareUsd,
      if (paymentMethod != null) 'payment_method': paymentMethod,
    });

    try {
      // Check connectivity
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || results.first == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }

      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      return jsonDecode(res.body);
    } catch (e) {
      // Queue the request for later if offline
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final queue = await OfflineQueue.getInstance();
      await queue.enqueue(QueuedRequest(
        url: url,
        headers: headers,
        body: body,
        tempId: tempId,
      ));
      
      // Return a temporary job object
      return {
        'id': tempId,
        'status': 'queued',
        'pickup_text': pickup,
        'drop_text': drop,
        'distance_km': distanceKm,
        'rider_name': riderName,
      };
    }
  }

  static Future<Map<String, dynamic>> getJob(String id) async {
    final res = await http.get(Uri.parse('$base/jobs/$id'), headers: _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> reportIssue({
    String? jobId,
    required String issueType,
  }) async {
    final res = await http.post(
      Uri.parse('$base/issues'),
      headers: _headers(),
      body: jsonEncode({'job_id': jobId, 'issue_type': issueType}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> recommend({
    required String corridor,
  }) async {
    final res = await http.post(
      Uri.parse('$base/recommend'),
      headers: _headers(),
      body: jsonEncode({'corridor': corridor}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> rateRide({
    required String jobId,
    required String driverId,
    required double rating,
    String? comment,
  }) async {
    final res = await http.post(
      Uri.parse('$base/ratings'),
      headers: _headers(),
      body: jsonEncode({
        'job_id': jobId,
        'driver_id': driverId,
        'rating': rating,
        'comment': comment,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> validatePromo({
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse('$base/promo/validate'),
      headers: _headers(),
      body: jsonEncode({'code': code}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> cancelJob({
    required String jobId,
    required String reason,
  }) async {
    final res = await http.post(
      Uri.parse('$base/jobs/$jobId/cancel'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> scheduleJob({
    required String pickup,
    required String drop,
    required double distanceKm,
    required String riderName,
    required DateTime scheduledTime,
    String? paymentMethod,
  }) async {
    final res = await http.post(
      Uri.parse('$base/jobs/schedule'),
      headers: _headers(),
      body: jsonEncode({
        'pickup_text': pickup,
        'drop_text': drop,
        'distance_km': distanceKm,
        'rider_name': riderName,
        'scheduled_time': scheduledTime.toIso8601String(),
        'payment_method': paymentMethod,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> searchLocations({
    required String query,
    int limit = 10,
  }) async {
    final res = await http.get(
      Uri.parse('$base/locations/search?q=${Uri.encodeComponent(query)}&limit=$limit'),
      headers: _headers(),
    );
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['locations'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getPopularLocations({
    int limit = 10,
  }) async {
    final res = await http.get(
      Uri.parse('$base/locations/popular?limit=$limit'),
      headers: _headers(),
    );
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['locations'] ?? []);
  }

  // Quick fare estimate
  static Future<Map<String, dynamic>> quickEstimate({
    required String pickup,
    required String drop,
    required double distanceKm,
  }) async {
    final res = await http.post(
      Uri.parse('$base/estimate'),
      headers: _headers(),
      body: jsonEncode({
        'pickup_text': pickup,
        'drop_text': drop,
        'distance_km': distanceKm,
      }),
    );
    return jsonDecode(res.body);
  }

  // Referral endpoints
  static Future<Map<String, dynamic>> createReferralCode({
    required String name,
    String? phone,
  }) async {
    final res = await http.post(
      Uri.parse('$base/referrals/create'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'phone': phone}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getReferralInfo(String code) async {
    final res = await http.get(
      Uri.parse('$base/referrals/$code'),
      headers: _headers(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> applyReferralCode({
    required String code,
    required String name,
    String? phone,
  }) async {
    final res = await http.post(
      Uri.parse('$base/referrals/apply'),
      headers: _headers(),
      body: jsonEncode({'code': code, 'name': name, 'phone': phone}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getReferralStats(String code) async {
    final res = await http.get(
      Uri.parse('$base/referrals/$code/stats'),
      headers: _headers(),
    );
    return jsonDecode(res.body);
  }

  // Driver earnings endpoints
  static Future<Map<String, dynamic>> getDriverEarnings(String driverId) async {
    final res = await http.get(
      Uri.parse('$base/drivers/$driverId/earnings'),
      headers: _headers(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getEarningsLeaderboard() async {
    final res = await http.get(
      Uri.parse('$base/drivers/earnings/leaderboard'),
      headers: _headers(),
    );
    return jsonDecode(res.body);
  }

  // Multi-stop rides
  static Future<Map<String, dynamic>> createMultiStopJob({
    required String pickup,
    required String drop,
    required List<Map<String, dynamic>> waypoints,
    required double totalDistanceKm,
    required String riderName,
    String? driverId,
    String? paymentMethod,
    double? pickupLat,
    double? pickupLng,
    double? dropLat,
    double? dropLng,
  }) async {
    final res = await http.post(
      Uri.parse('$base/jobs/multi-stop'),
      headers: _headers(),
      body: jsonEncode({
        'pickup_text': pickup,
        'drop_text': drop,
        'waypoints': waypoints,
        'total_distance_km': totalDistanceKm,
        'rider_name': riderName,
        if (driverId != null) 'driver_id': driverId,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
        if (dropLat != null) 'drop_lat': dropLat,
        if (dropLng != null) 'drop_lng': dropLng,
      }),
    );
    return jsonDecode(res.body);
  }
}
