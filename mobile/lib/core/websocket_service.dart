import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _jobUpdates = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  String? _currentJobId;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get jobUpdates => _jobUpdates.stream;
  bool get isConnected => _isConnected;

  /// Connect to WebSocket for live job tracking
  void connect(String jobId) {
    if (_currentJobId == jobId && _isConnected) return;

    disconnect();
    _currentJobId = jobId;

    final wsBase = Api.base.replaceFirst('http', 'ws');
    final token = '${Api.basicUser}:${Api.basicPass}';
    final uri = Uri.parse('$wsBase/ws/track/$jobId?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _jobUpdates.add(data);
          } catch (e) {
            // Handle ping/pong
            if (message == 'pong') return;
          }
        },
        onError: (error) {
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      // Start ping/pong to keep connection alive
      _startPing();
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _startPing() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected || _channel == null) {
        timer.cancel();
        return;
      }
      try {
        _channel!.sink.add('ping');
      } catch (_) {
        timer.cancel();
      }
    });
  }

  void _scheduleReconnect() {
    if (_currentJobId == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_currentJobId != null) {
        connect(_currentJobId!);
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _currentJobId = null;
  }

  void dispose() {
    disconnect();
    _jobUpdates.close();
  }
}

// Singleton instance
final wsService = WebSocketService();

