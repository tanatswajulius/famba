import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class OfflineQueue {
  static const String _queueKey = 'offline_request_queue';
  static OfflineQueue? _instance;
  late SharedPreferences _prefs;
  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;

  OfflineQueue._();

  static Future<OfflineQueue> getInstance() async {
    if (_instance == null) {
      _instance = OfflineQueue._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty &&
          results.first != ConnectivityResult.none &&
          !_isProcessing) {
        _processQueue();
      }
    });
  }

  Future<void> enqueue(QueuedRequest request) async {
    final queue = await _getQueue();
    queue.add(request.toJson());
    await _prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> _getQueue() async {
    final queueJson = _prefs.getString(_queueKey);
    if (queueJson == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final queue = await _getQueue();
      final remainingQueue = <Map<String, dynamic>>[];

      for (var item in queue) {
        final request = QueuedRequest.fromJson(item);
        try {
          await http.post(
            Uri.parse(request.url),
            headers: request.headers,
            body: request.body,
          );
          // Successfully sent, don't add to remaining queue
        } catch (e) {
          // Failed to send, keep in queue
          remainingQueue.add(item);
        }
      }

      await _prefs.setString(_queueKey, jsonEncode(remainingQueue));
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> flush() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isNotEmpty && results.first != ConnectivityResult.none) {
      await _processQueue();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

class QueuedRequest {
  final String url;
  final Map<String, String> headers;
  final String body;
  final String tempId;

  QueuedRequest({
    required this.url,
    required this.headers,
    required this.body,
    required this.tempId,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'headers': headers,
        'body': body,
        'tempId': tempId,
      };

  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    return QueuedRequest(
      url: json['url'] as String,
      headers: Map<String, String>.from(json['headers'] as Map),
      body: json['body'] as String,
      tempId: json['tempId'] as String,
    );
  }
}

