import 'package:flutter/foundation.dart';

enum DriverStatus { offline, online, onTrip }

class RideRequest {
  final String id;
  final String riderName;
  final String pickup;
  final String dropoff;
  final double fare;
  final double distance;
  final int etaMinutes;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;

  RideRequest({
    required this.id,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.distance,
    required this.etaMinutes,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'] ?? '',
      riderName: json['rider_name'] ?? 'Rider',
      pickup: json['pickup_text'] ?? '',
      dropoff: json['drop_text'] ?? '',
      fare: (json['fare_usd'] ?? 0).toDouble(),
      distance: (json['distance_km'] ?? 0).toDouble(),
      etaMinutes: json['eta_min'] ?? 5,
      pickupLat: (json['pickup_lat'] ?? -17.8292).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 31.0522).toDouble(),
      dropLat: (json['drop_lat'] ?? -17.8200).toDouble(),
      dropLng: (json['drop_lng'] ?? 31.0490).toDouble(),
    );
  }
}

class DriverState extends ChangeNotifier {
  DriverStatus _status = DriverStatus.offline;
  String? _driverId;
  String? _driverName;
  double _todayEarnings = 0;
  int _todayTrips = 0;
  double _rating = 4.8;
  RideRequest? _currentRequest;
  RideRequest? _activeRide;
  String _rideStatus = 'idle'; // idle, accepted, arrived, riding, complete
  
  // Location
  double _lat = -17.829;
  double _lng = 31.052;

  // Getters
  DriverStatus get status => _status;
  String? get driverId => _driverId;
  String? get driverName => _driverName;
  double get todayEarnings => _todayEarnings;
  int get todayTrips => _todayTrips;
  double get rating => _rating;
  RideRequest? get currentRequest => _currentRequest;
  RideRequest? get activeRide => _activeRide;
  String get rideStatus => _rideStatus;
  double get lat => _lat;
  double get lng => _lng;
  bool get isOnline => _status != DriverStatus.offline;
  bool get isOnTrip => _status == DriverStatus.onTrip;

  // Actions
  void login(String driverId, String name) {
    _driverId = driverId;
    _driverName = name;
    notifyListeners();
  }

  void logout() {
    _driverId = null;
    _driverName = null;
    _status = DriverStatus.offline;
    _currentRequest = null;
    _activeRide = null;
    notifyListeners();
  }

  void goOnline() {
    _status = DriverStatus.online;
    notifyListeners();
  }

  void goOffline() {
    _status = DriverStatus.offline;
    notifyListeners();
  }

  void toggleOnline() {
    if (_status == DriverStatus.offline) {
      goOnline();
    } else if (_status == DriverStatus.online) {
      goOffline();
    }
  }

  void updateLocation(double lat, double lng) {
    _lat = lat;
    _lng = lng;
    notifyListeners();
  }

  void receiveRequest(RideRequest request) {
    _currentRequest = request;
    notifyListeners();
  }

  void acceptRide() {
    if (_currentRequest != null) {
      _activeRide = _currentRequest;
      _currentRequest = null;
      _status = DriverStatus.onTrip;
      _rideStatus = 'accepted';
      notifyListeners();
    }
  }

  void declineRide() {
    _currentRequest = null;
    notifyListeners();
  }

  void arrivedAtPickup() {
    _rideStatus = 'arrived';
    notifyListeners();
  }

  void startRide() {
    _rideStatus = 'riding';
    notifyListeners();
  }

  void completeRide() {
    if (_activeRide != null) {
      _todayEarnings += _activeRide!.fare * 0.85; // 85% to driver
      _todayTrips += 1;
    }
    _activeRide = null;
    _status = DriverStatus.online;
    _rideStatus = 'idle';
    notifyListeners();
  }

  void cancelRide() {
    _activeRide = null;
    _status = DriverStatus.online;
    _rideStatus = 'idle';
    notifyListeners();
  }

  void updateRating(double newRating) {
    _rating = newRating;
    notifyListeners();
  }

  void updateEarnings(double earnings, int trips) {
    _todayEarnings = earnings;
    _todayTrips = trips;
    notifyListeners();
  }
}

