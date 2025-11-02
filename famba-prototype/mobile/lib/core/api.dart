import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_queue.dart';

class Api {
  static String base = const String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');

  static Future<Map<String, dynamic>> quote({
    required String pickup,
    required String drop,
    required double distanceKm,
    bool peak = false,
  }) async {
    final res = await http.post(Uri.parse('$base/quote'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({'pickup_text': pickup, 'drop_text': drop, 'distance_km': distanceKm, 'peak': peak}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createJob({
    required String pickup,
    required String drop,
    required double distanceKm,
    required String riderName,
  }) async {
    final url = '$base/jobs';
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'pickup_text': pickup,
      'drop_text': drop,
      'distance_km': distanceKm,
      'rider_name': riderName
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
    final res = await http.get(Uri.parse('$base/jobs/$id'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> reportIssue({
    String? jobId,
    required String issueType,
  }) async {
    final res = await http.post(
      Uri.parse('$base/issues'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'job_id': jobId, 'issue_type': issueType}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> recommend({
    required String corridor,
  }) async {
    final res = await http.post(
      Uri.parse('$base/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'corridor': corridor}),
    );
    return jsonDecode(res.body);
  }
}
