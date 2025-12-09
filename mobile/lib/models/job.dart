class Job {
  final String id;
  final String status;
  final Map<String, dynamic>? driver;
  final double? driverLat;
  final double? driverLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final double? fareUsd;
  final String? paymentMethod;

  Job({
    required this.id,
    required this.status,
    this.driver,
    this.driverLat,
    this.driverLng,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.fareUsd,
    this.paymentMethod,
  });

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        id: j['id'],
        status: j['status'],
        driver: j['driver'],
        driverLat: (j['driver_lat'] as num?)?.toDouble(),
        driverLng: (j['driver_lng'] as num?)?.toDouble(),
        pickupLat: (j['pickup_lat'] as num?)?.toDouble(),
        pickupLng: (j['pickup_lng'] as num?)?.toDouble(),
        dropLat: (j['drop_lat'] as num?)?.toDouble(),
        dropLng: (j['drop_lng'] as num?)?.toDouble(),
        fareUsd: (j['fare_usd'] as num?)?.toDouble(),
        paymentMethod: j['payment_method'] as String?,
      );
}
