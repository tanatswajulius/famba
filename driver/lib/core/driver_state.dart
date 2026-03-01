import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DriverStatus { offline, online, onTrip, onDelivery }

enum RequestType { ride, delivery }

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

class DeliveryRequest {
  final String orderId;
  final String restaurantName;
  final String restaurantAddress;
  final String customerName;
  final String deliveryAddress;
  final double totalAmount;
  final int itemCount;
  final double restaurantLat;
  final double restaurantLng;
  final double deliveryLat;
  final double deliveryLng;
  final List<Map<String, dynamic>> items;

  DeliveryRequest({
    required this.orderId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.customerName,
    required this.deliveryAddress,
    required this.totalAmount,
    required this.itemCount,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.items,
  });

  factory DeliveryRequest.fromJson(Map<String, dynamic> json) {
    return DeliveryRequest(
      orderId: json['id'] ?? '',
      restaurantName: json['restaurant_name'] ?? 'Restaurant',
      restaurantAddress: json['restaurant_address'] ?? '',
      customerName: json['rider_name'] ?? json['customer_name'] ?? 'Customer',
      deliveryAddress: json['delivery_address'] ?? '',
      totalAmount: (json['total'] ?? 0).toDouble(),
      itemCount: (json['items'] as List?)?.length ?? 0,
      restaurantLat: (json['restaurant_lat'] ?? -17.8292).toDouble(),
      restaurantLng: (json['restaurant_lng'] ?? 31.0522).toDouble(),
      deliveryLat: (json['delivery_lat'] ?? -17.8200).toDouble(),
      deliveryLng: (json['delivery_lng'] ?? 31.0490).toDouble(),
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
    );
  }
}

class DriverState extends ChangeNotifier {
  DriverStatus _status = DriverStatus.offline;
  String? _driverId;
  String? _driverName;
  String? _phone;
  String? _accessToken;
  double _todayEarnings = 0;
  int _todayTrips = 0;
  int _todayDeliveries = 0;
  double _rating = 4.8;
  final List<Map<String, dynamic>> _completedTrips = [];
  List<Map<String, dynamic>> get completedTrips => _completedTrips;
  RideRequest? _currentRequest;
  RideRequest? _activeRide;
  DeliveryRequest? _currentDeliveryRequest;
  DeliveryRequest? _activeDelivery;
  String _rideStatus = 'idle'; // idle, accepted, arrived, riding, complete
  String _deliveryStatus = 'idle'; // idle, accepted, at_restaurant, picked_up, delivering, delivered

  // Location
  double _lat = -17.829;
  double _lng = 31.052;

  // Getters
  DriverStatus get status => _status;
  String? get driverId => _driverId;
  String? get driverName => _driverName;
  String? get phone => _phone;
  String? get accessToken => _accessToken;
  double get todayEarnings => _todayEarnings;
  int get todayTrips => _todayTrips;
  int get todayDeliveries => _todayDeliveries;
  double get rating => _rating;
  RideRequest? get currentRequest => _currentRequest;
  RideRequest? get activeRide => _activeRide;
  DeliveryRequest? get currentDeliveryRequest => _currentDeliveryRequest;
  DeliveryRequest? get activeDelivery => _activeDelivery;
  String get rideStatus => _rideStatus;
  String get deliveryStatus => _deliveryStatus;
  double get lat => _lat;
  double get lng => _lng;
  bool get isLoggedIn => _accessToken != null;
  bool get isOnline => _status != DriverStatus.offline;
  bool get isOnTrip => _status == DriverStatus.onTrip;
  bool get isOnDelivery => _status == DriverStatus.onDelivery;
  bool get isBusy => isOnTrip || isOnDelivery;

  // Auth actions
  void setAuth({
    required String driverId,
    required String name,
    required String phone,
    required String accessToken,
  }) {
    _driverId = driverId;
    _driverName = name;
    _phone = phone;
    _accessToken = accessToken;
    _saveAuth();
    notifyListeners();
  }

  void login(String driverId, String name) {
    _driverId = driverId;
    _driverName = name;
    notifyListeners();
  }

  void logout() {
    _driverId = null;
    _driverName = null;
    _phone = null;
    _accessToken = null;
    _status = DriverStatus.offline;
    _currentRequest = null;
    _activeRide = null;
    _currentDeliveryRequest = null;
    _activeDelivery = null;
    _rideStatus = 'idle';
    _deliveryStatus = 'idle';
    _clearAuth();
    notifyListeners();
  }

  // Online/Offline
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

  // ============= RIDE ACTIONS =============

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
      _todayEarnings += _activeRide!.fare * 0.85;
      _todayTrips += 1;
      _completedTrips.add({
        'rider': _activeRide!.riderName,
        'pickup': _activeRide!.pickup,
        'dropoff': _activeRide!.dropoff,
        'fare': _activeRide!.fare * 0.85,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      });
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

  // ============= DELIVERY ACTIONS =============

  void receiveDeliveryRequest(DeliveryRequest request) {
    _currentDeliveryRequest = request;
    notifyListeners();
  }

  void acceptDelivery() {
    if (_currentDeliveryRequest != null) {
      _activeDelivery = _currentDeliveryRequest;
      _currentDeliveryRequest = null;
      _status = DriverStatus.onDelivery;
      _deliveryStatus = 'accepted';
      notifyListeners();
    }
  }

  void declineDelivery() {
    _currentDeliveryRequest = null;
    notifyListeners();
  }

  void arrivedAtRestaurant() {
    _deliveryStatus = 'at_restaurant';
    notifyListeners();
  }

  void pickedUpOrder() {
    _deliveryStatus = 'picked_up';
    notifyListeners();
  }

  void startDelivering() {
    _deliveryStatus = 'delivering';
    notifyListeners();
  }

  void completeDelivery() {
    if (_activeDelivery != null) {
      _todayEarnings += _activeDelivery!.totalAmount * 0.15; // 15% delivery commission
      _todayDeliveries += 1;
    }
    _activeDelivery = null;
    _status = DriverStatus.online;
    _deliveryStatus = 'idle';
    notifyListeners();
  }

  void cancelDelivery() {
    _activeDelivery = null;
    _status = DriverStatus.online;
    _deliveryStatus = 'idle';
    notifyListeners();
  }

  // ============= MISC =============

  void updateRating(double newRating) {
    _rating = newRating;
    notifyListeners();
  }

  void updateEarnings(double earnings, int trips) {
    _todayEarnings = earnings;
    _todayTrips = trips;
    notifyListeners();
  }

  // ============= PERSISTENCE =============

  Future<void> _saveAuth() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) prefs.setString('driver_token', _accessToken!);
    if (_driverId != null) prefs.setString('driver_id', _driverId!);
    if (_driverName != null) prefs.setString('driver_name', _driverName!);
    if (_phone != null) prefs.setString('driver_phone', _phone!);
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('driver_token');
    prefs.remove('driver_id');
    prefs.remove('driver_name');
    prefs.remove('driver_phone');
  }

  Future<bool> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('driver_token');
    if (token != null) {
      _accessToken = token;
      _driverId = prefs.getString('driver_id');
      _driverName = prefs.getString('driver_name');
      _phone = prefs.getString('driver_phone');
      notifyListeners();
      return true;
    }
    return false;
  }
}
