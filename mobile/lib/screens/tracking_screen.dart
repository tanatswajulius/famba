import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../core/websocket_service.dart';
import '../core/route_service.dart';
import '../models/job.dart';
import '../widgets/sos_button.dart';
import '../widgets/cancel_ride_sheet.dart';
import '../main.dart';

const _statusSteps = [
  "driver_assigned",
  "enroute",
  "arrived",
  "riding",
  "complete",
];

const _pickupPoint = LatLng(-17.8292, 31.0522);
const _dropoffPoint = LatLng(-17.8200, 31.0490);
const _mapTileKey = String.fromEnvironment('MAP_TILE_KEY', defaultValue: '');

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  String jobId = "";
  Job? job;
  Timer? timer;
  bool _hasRated = false;
  double _sheetSize = 0.4;
  
  // WebSocket and Route
  StreamSubscription? _wsSubscription;
  List<LatLng> _routePoints = [];
  bool _useWebSocket = true;
  bool _routeLoaded = false;

  @override
  void didChangeDependencies() {
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      jobId = arg;
    } else if (arg is Map && arg['jobId'] is String) {
      jobId = arg['jobId'];
    }

    if (jobId.isNotEmpty) {
      _initTracking();
    }

    super.didChangeDependencies();
  }

  Future<void> _initTracking() async {
    await _poll();
    
    if (_useWebSocket) {
      _connectWebSocket();
    } else {
      timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    }
    
    _fetchRoute();
    _startDemoProgression();
  }

  void _startDemoProgression() {
    const demoSteps = ["enroute", "arrived", "riding", "complete"];
    const delays = [Duration(seconds: 5), Duration(seconds: 8), Duration(seconds: 6), Duration(seconds: 10)];
    var elapsed = Duration.zero;
    for (var i = 0; i < demoSteps.length; i++) {
      elapsed += delays[i];
      Future.delayed(elapsed, () {
        if (!mounted || job == null) return;
        setState(() {
          job = Job(
            id: job!.id, status: demoSteps[i],
            pickupLat: job!.pickupLat, pickupLng: job!.pickupLng,
            dropLat: job!.dropLat, dropLng: job!.dropLng,
            fareUsd: job!.fareUsd ?? 2.45,
            driver: job!.driver, driverLat: job!.driverLat, driverLng: job!.driverLng,
            paymentMethod: job!.paymentMethod,
          );
        });
        if (demoSteps[i] == "complete") timer?.cancel();
      });
    }
  }

  void _connectWebSocket() {
    wsService.connect(jobId);
    _wsSubscription = wsService.jobUpdates.listen((data) {
      if (data['type'] == 'job_update' && data['job'] != null) {
        final j = Job.fromJson(data['job']);
        if (!mounted) return;
        setState(() => job = j);
        
        if (j.status == "complete") {
          wsService.disconnect();
        }
      }
    }, onError: (e) {
      // Fall back to polling on WebSocket error
      _useWebSocket = false;
      timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    });
  }

  Future<void> _fetchRoute() async {
    if (_routeLoaded) return;
    
    final pickupLat = job?.pickupLat ?? _pickupPoint.latitude;
    final pickupLng = job?.pickupLng ?? _pickupPoint.longitude;
    final dropLat = job?.dropLat ?? _dropoffPoint.latitude;
    final dropLng = job?.dropLng ?? _dropoffPoint.longitude;
    
    try {
      final points = await RouteService.getRoute(
        start: LatLng(pickupLat, pickupLng),
        end: LatLng(dropLat, dropLng),
      );
      
      if (mounted && points.isNotEmpty) {
        setState(() {
          _routePoints = points;
          _routeLoaded = true;
        });
      }
    } catch (e) {
      // Use straight line on error
      setState(() {
        _routePoints = [
          LatLng(pickupLat, pickupLng),
          LatLng(dropLat, dropLng),
        ];
        _routeLoaded = true;
      });
    }
  }

  Future<void> _poll() async {
    try {
      final j = Job.fromJson(await Api.getJob(jobId));
      if (!mounted) return;
      setState(() => job = j);
      if (j.status == "complete") timer?.cancel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tracking error: $e'),
          backgroundColor: FambaColors.error,
        ),
      );
    }
  }

  void _openChat() {
    Navigator.pushNamed(context, '/chat', arguments: {
      'driverName': job?.driver?['name'] ?? 'Driver',
      'jobId': jobId,
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _wsSubscription?.cancel();
    wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (jobId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Track Ride")),
        body: const Center(child: Text("No job id provided.")),
      );
    }

    return Scaffold(
      body: job == null
          ? const Center(
              child: CircularProgressIndicator(color: FambaColors.primary),
            )
          : Stack(
                  children: [
                // Full-bleed map
                Positioned.fill(child: _buildMap()),
                // Status chip overlay
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: _buildTopBar(),
                ),
                // Bottom sheet
                _buildBottomSheet(),
              ],
            ),
    );
  }

  Widget _buildTopBar() {
    return Row(
                          children: [
        GestureDetector(
          onTap: () {
            if (job?.status == "complete") {
              Navigator.popUntil(context, ModalRoute.withName('/home'));
            } else {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Leave tracking?"),
                  content: const Text(
                      "Your ride will continue. You can come back anytime."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Stay"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.popUntil(context, ModalRoute.withName('/home'));
                      },
                      child: const Text("Leave"),
                    ),
                  ],
                ),
              );
            }
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
                                child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
              borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getStatusLabel(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: FambaColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _getEtaLabel(),
                                          style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FambaColors.primary,
                  ),
                ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
    );
  }

  Color _getStatusColor() {
    switch (job?.status) {
      case "driver_assigned":
        return Colors.orange;
      case "enroute":
        return Colors.blue;
      case "arrived":
        return FambaColors.success;
      case "riding":
        return FambaColors.primary;
      case "complete":
        return FambaColors.success;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel() {
    switch (job?.status) {
      case "driver_assigned":
        return "Driver matched!";
      case "enroute":
        return "Driver is on the way";
      case "arrived":
        return "Driver has arrived!";
      case "riding":
        return "Enjoy your ride";
      case "complete":
        return "Ride complete";
      default:
        return "Tracking...";
    }
  }

  String _getEtaLabel() {
    switch (job?.status) {
      case "driver_assigned":
        return "~3 min";
      case "enroute":
        return "~2 min";
      case "arrived":
        return "Now";
      case "riding":
        return "~5 min";
      case "complete":
        return "Done";
      default:
        return "";
    }
  }

  Widget _buildMap() {
    final driverLat = job?.driverLat ?? _pickupPoint.latitude;
    final driverLng = job?.driverLng ?? _pickupPoint.longitude;
    final pickupLat = job?.pickupLat ?? _pickupPoint.latitude;
    final pickupLng = job?.pickupLng ?? _pickupPoint.longitude;
    final dropLat = job?.dropLat ?? _dropoffPoint.latitude;
    final dropLng = job?.dropLng ?? _dropoffPoint.longitude;
    final centerLat = (driverLat + dropLat) / 2;
    final centerLng = (driverLng + dropLng) / 2;

    final hasTileKey = _mapTileKey.isNotEmpty && _mapTileKey != 'get-your-key';
    
    // Use OSRM route if available, otherwise straight line
    final routePolyline = _routePoints.isNotEmpty
        ? _routePoints
        : [LatLng(pickupLat, pickupLng), LatLng(dropLat, dropLng)];

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: hasTileKey
              ? 'https://api.maptiler.com/maps/streets-v2-light/{z}/{x}/{y}.png?key=$_mapTileKey'
              : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: hasTileKey ? const [] : const ['a', 'b', 'c'],
          userAgentPackageName: 'com.famba.rider',
        ),
        // Route polyline (from OSRM)
        PolylineLayer(
          polylines: [
            Polyline(
              points: routePolyline,
              strokeWidth: 5,
              color: FambaColors.primary,
              borderStrokeWidth: 2,
              borderColor: FambaColors.primaryDark.withOpacity(0.3),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Driver marker with pulse
            Marker(
              width: 60,
              height: 60,
              point: LatLng(driverLat, driverLng),
              child: _PulsingDriverMarker(),
            ),
            // Pickup marker
            Marker(
              width: 40,
              height: 40,
              point: LatLng(pickupLat, pickupLng),
              child: _buildMapPin(FambaColors.primary, Icons.radio_button_checked),
            ),
            // Dropoff marker
            Marker(
              width: 40,
              height: 40,
              point: LatLng(dropLat, dropLng),
              child: _buildMapPin(FambaColors.error, Icons.flag_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapPin(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildBottomSheet() {
    final isComplete = job?.status == "complete";

    return DraggableScrollableSheet(
      initialChildSize: isComplete ? 0.55 : 0.42,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 12),
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Status progress
              _buildStatusProgress(),
              const SizedBox(height: 20),
              // Content based on status
              if (isComplete)
                _buildCompleteSummary()
              else ...[
                if (job?.driver != null) _buildDriverCard(),
                const SizedBox(height: 16),
                _buildQuickActions(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _cancelButton(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SosButton(jobId: jobId),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusProgress() {
    final currentIndex = _statusSteps
        .indexWhere((s) => s == job?.status)
        .clamp(0, _statusSteps.length - 1);

    return Row(
      children: List.generate(_statusSteps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          final isActive = stepIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: isActive ? FambaColors.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        } else {
          // Step dot
          final stepIndex = index ~/ 2;
          final isActive = stepIndex <= currentIndex;
          final isCurrent = stepIndex == currentIndex;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isCurrent ? 28 : 20,
                height: isCurrent ? 28 : 20,
                decoration: BoxDecoration(
                  color: isActive ? FambaColors.primary : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: FambaColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isActive
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                _getStepLabel(stepIndex),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? FambaColors.textPrimary : FambaColors.textSecondary,
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  String _getStepLabel(int index) {
    switch (index) {
      case 0:
        return "Matched";
      case 1:
        return "En route";
      case 2:
        return "Arrived";
      case 3:
        return "Riding";
      case 4:
        return "Done";
      default:
        return "";
    }
  }

  Widget _buildDriverCard() {
    final driver = job!.driver!;
    final isArrived = job?.status == "arrived";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isArrived ? FambaColors.success.withOpacity(0.08) : FambaColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isArrived ? FambaColors.success.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FambaColors.primary, FambaColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    (driver['name'] as String).substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['name'],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: FambaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                      Row(
                        children: [
                        Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 4),
                          Text(
                          "${driver['rating']}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: FambaColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Helmet ✓",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FambaColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _actionButton(Icons.call_rounded, () {}),
                  const SizedBox(width: 8),
                  _actionButton(Icons.chat_rounded, () {}),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.two_wheeler_rounded, size: 20, color: FambaColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Bajaj Boxer • Green",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: FambaColors.textPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "MBK-2489",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                            ),
                          ),
                        ],
            ),
          ),
          if (isArrived) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FambaColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: FambaColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Your driver has arrived! Look for a green Bajaj.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FambaColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: FambaColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: FambaColors.primary),
      ),
    );
  }

  Widget _buildQuickActions() {
    final payment = job?.paymentMethod ?? "Famba Card";
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _infoCard(
                icon: Icons.access_time_rounded,
                label: "ETA",
                value: _getEtaLabel(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(
                icon: payment == "Cash" ? Icons.payments_rounded : Icons.credit_card_rounded,
                label: "Payment",
                value: payment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Quick action buttons (Call, Chat, Share)
        Row(
          children: [
            _quickActionBtn(
              icon: Icons.call_rounded,
              label: "Call",
              color: FambaColors.primary,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling driver (simulated)')),
                );
              },
            ),
            const SizedBox(width: 10),
            _quickActionBtn(
              icon: Icons.chat_bubble_rounded,
              label: "Chat",
              color: Colors.blue,
              onTap: _openChat,
            ),
            const SizedBox(width: 10),
            _quickActionBtn(
              icon: Icons.share_rounded,
              label: "Share",
              color: Colors.orange,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Share link: famba.app/track/$jobId')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FambaColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FambaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: FambaColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FambaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteSummary() {
    final fare = job?.fareUsd;
    final driverName = job?.driver?['name'] ?? 'Your driver';
    final payment = job?.paymentMethod ?? "Famba Card";

    return Column(
      children: [
        // Success badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: FambaColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: FambaColors.success,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Ride complete!",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: FambaColors.textPrimary,
          ),
                      ),
                      const SizedBox(height: 8),
        Text(
          "Thanks for riding with Famba",
          style: TextStyle(
            fontSize: 14,
            color: FambaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Fare card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FambaColors.background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total fare",
                    style: TextStyle(
                      fontSize: 15,
                      color: FambaColors.textSecondary,
                    ),
                  ),
                  Text(
                    fare != null ? "\$${fare.toStringAsFixed(2)}" : "\$--",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: FambaColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Paid with",
                    style: TextStyle(
                      fontSize: 14,
                      color: FambaColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        payment == "Cash" ? Icons.payments_rounded : Icons.credit_card_rounded,
                        size: 18,
                        color: FambaColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        payment,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Rate driver
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _hasRated ? null : () => _showRatingSheet(driverName),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasRated ? Colors.grey.shade200 : FambaColors.primary,
              foregroundColor: _hasRated ? FambaColors.textSecondary : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_hasRated ? Icons.check_rounded : Icons.star_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  _hasRated ? "Thanks for rating!" : "Rate $driverName",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Share trip
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: _shareTrip,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  "Share trip",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Done button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: TextButton(
            onPressed: () =>
                Navigator.popUntil(context, ModalRoute.withName('/home')),
            child: const Text(
              "Done",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showRatingSheet(String driverName) async {
    double rating = 5;
    final controller = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "How was your ride with $driverName?",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < rating.round();
                      return GestureDetector(
                        onTap: () => setState(() => rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 44,
                            color: filled ? Colors.amber.shade500 : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Add a comment (optional)",
                      filled: true,
                      fillColor: FambaColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                    height: 54,
                        child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FambaColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Submit rating",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (result == true && mounted) {
      final driverId = job?.driver?['id'] as String?;
      try {
        if (driverId != null) {
          await Api.rateRide(
            jobId: jobId,
            driverId: driverId,
            rating: rating,
            comment: controller.text.isEmpty ? null : controller.text,
          );
        }
        if (!mounted) return;
        setState(() => _hasRated = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Thanks! You rated $driverName ${rating.toStringAsFixed(0)}★"),
            backgroundColor: FambaColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit rating: $e"),
            backgroundColor: FambaColors.error,
          ),
        );
      }
    }
  }

  void _shareTrip() {
    final url = "https://famba.app/trip/$jobId";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Trip link copied: $url"),
        backgroundColor: FambaColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _cancelButton() {
    return GestureDetector(
      onTap: () {
        CancelRideSheet.show(context, jobId, () {
          Navigator.popUntil(context, ModalRoute.withName('/home'));
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.close_rounded, color: FambaColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Cancel ride',
              style: TextStyle(
                color: FambaColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDriverMarker extends StatefulWidget {
  @override
  State<_PulsingDriverMarker> createState() => _PulsingDriverMarkerState();
}

class _PulsingDriverMarkerState extends State<_PulsingDriverMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = 1 + (_controller.value * 0.5);
            final opacity = (1 - _controller.value).clamp(0.0, 1.0);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FambaColors.primary.withOpacity(0.2 * opacity),
                ),
              ),
            );
          },
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: FambaColors.primary.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: FambaColors.primary,
            size: 24,
          ),
        ),
      ],
    );
  }
}
