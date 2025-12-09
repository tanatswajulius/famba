import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../models/job.dart';
import '../widgets/sos_button.dart';

const _statusSteps = [
  "driver_assigned",
  "enroute",
  "arrived",
  "riding",
  "complete",
];

const _pickupPoint = LatLng(-17.8292, 31.0522);
const _dropoffPoint = LatLng(-17.8200, 31.0490);
const _mapTileKey =
    String.fromEnvironment('MAP_TILE_KEY', defaultValue: '');

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String jobId = "";
  Job? job;
  Timer? timer;
  bool _hasRated = false;

  @override
  void didChangeDependencies() {
    // Accept either a String jobId or a Map with jobId
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      jobId = arg;
    } else if (arg is Map && arg['jobId'] is String) {
      jobId = arg['jobId'];
    }

    if (jobId.isNotEmpty) {
      _poll();
      timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    }

    super.didChangeDependencies();
  }

  Future<void> _poll() async {
    try {
      final j = Job.fromJson(await Api.getJob(jobId));
      if (!mounted) return;
      setState(() => job = j);
      if (j.status == "complete") timer?.cancel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tracking error: $e')));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (jobId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Track Ride")),
        body: const Center(child: Text("No job id provided.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Trip $jobId")),
      body: job == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
                  children: [
                Positioned.fill(child: _buildMap(theme)),
                _buildBottomSheet(theme),
              ],
            ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    final driverLat = job?.driverLat ?? _pickupPoint.latitude;
    final driverLng = job?.driverLng ?? _pickupPoint.longitude;
    final pickupLat = job?.pickupLat ?? _pickupPoint.latitude;
    final pickupLng = job?.pickupLng ?? _pickupPoint.longitude;
    final dropLat = job?.dropLat ?? _dropoffPoint.latitude;
    final dropLng = job?.dropLng ?? _dropoffPoint.longitude;
    final centerLat = (driverLat + dropLat) / 2;
    final centerLng = (driverLng + dropLng) / 2;

    final hasTileKey = _mapTileKey.isNotEmpty && _mapTileKey != 'get-your-key';

    return Stack(
                          children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: 13.3,
          ),
                                children: [
            TileLayer(
              urlTemplate: hasTileKey
                  ? 'https://api.maptiler.com/maps/streets-v2-light/{z}/{x}/{y}.png?key=$_mapTileKey'
                  : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: hasTileKey ? const [] : const ['a', 'b', 'c'],
              userAgentPackageName: 'com.famba.rider',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    LatLng(pickupLat, pickupLng),
                    LatLng(dropLat, dropLng),
                  ],
                  strokeWidth: 5,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 52,
                  height: 52,
                  point: LatLng(driverLat, driverLng),
                  child: _PulsingPin(color: theme.colorScheme.primary),
                ),
                Marker(
                  width: 36,
                  height: 36,
                  point: LatLng(pickupLat, pickupLng),
                  child: _mapBadge(
                    theme,
                    icon: Icons.radio_button_checked,
                    color: Colors.green.shade600,
                  ),
                ),
                Marker(
                  width: 36,
                  height: 36,
                  point: LatLng(dropLat, dropLng),
                  child: _mapBadge(
                    theme,
                    icon: Icons.flag,
                    color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
          ],
                            ),
                              Positioned(
                                top: 12,
                                left: 12,
          child: _glassChip(
            theme,
            icon: Icons.navigation,
            label: "Tracking",
          ),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          child: _glassChip(
            theme,
            icon: Icons.map,
            label: "Harare • Live Map",
          ),
        ),
      ],
    );
  }

  Widget _glassChip(ThemeData theme, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _mapBadge(ThemeData theme,
      {required IconData icon, required Color color}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildStatusProgress(ThemeData theme) {
    final current = job!.status;
    final currentIndex =
        _statusSteps.indexWhere((s) => s == current).clamp(0, _statusSteps.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Status: ",
                style: TextStyle(
                    fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.7))),
            Text(
              _labelForStatus(current),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_statusSteps.length, (index) {
            final isActive = index <= currentIndex;
            final isLast = index == _statusSteps.length - 1;
            return Expanded(
              child: Row(
                children: [
                  _stepDot(theme, active: isActive, label: _labelShort(_statusSteps[index])),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _stepDot(ThemeData theme, {required bool active, required String label}) {
    return Column(
                        children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
                            style: TextStyle(
              fontSize: 12,
              color: active
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            )),
      ],
    );
  }

  String _labelForStatus(String s) {
    switch (s) {
      case "driver_assigned":
        return "Driver assigned";
      case "enroute":
        return "Driver en route";
      case "arrived":
        return "Driver arrived";
      case "riding":
        return "Riding";
      case "complete":
        return "Complete";
      default:
        return s;
    }
  }

  String _labelShort(String s) {
    switch (s) {
      case "driver_assigned":
        return "Assign";
      case "enroute":
        return "Enroute";
      case "arrived":
        return "Arrived";
      case "riding":
        return "Ride";
      case "complete":
        return "Done";
      default:
        return s;
    }
  }

  Widget _buildBottomSheet(ThemeData theme) {
    final status = job!.status;
    final inRide = status == "riding";
    final isComplete = status == "complete";
    final arrived = status == "arrived";

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
                          ),
                        ],
                      ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ListView(
            controller: controller,
            children: [
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
              const SizedBox(height: 12),
              _buildStatusProgress(theme),
              const SizedBox(height: 12),
              if (job!.driver != null && !inRide && !isComplete)
                _buildDriverRow(theme),
              if (inRide && !isComplete) _buildInRideRow(theme),
              if (arrived && !isComplete) _buildArrivedActions(theme),
              if (!isComplete) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _glassChip(theme,
                          icon: Icons.timer, label: "ETA ~2 min"),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _glassChip(theme,
                          icon: Icons.safety_check, label: "Helmet check ✓"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                      SosButton(jobId: jobId),
                const SizedBox(height: 12),
                    ],
              if (isComplete)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.popUntil(
                              context, ModalRoute.withName('/home')),
                          child: const Text("Done"),
                        ),
                      ),
              if (isComplete) ...[
                const SizedBox(height: 12),
                _buildCompleteSummary(theme),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildArrivedActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.handshake),
            label: const Text("I'm here"),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.help_outline),
            label: const Text("Can't find driver"),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInRideRow(ThemeData theme) {
    final eta = _estimateEta();
    final payment = job?.paymentMethod ?? "Famba Card";
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.directions_bike, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Ride in progress",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text("Dropoff: First Street Mall",
                          style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.7))),
                    ],
                  ),
                ),
                _pillButton(theme, icon: Icons.chat, label: "Message"),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("ETA", style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text("~4 min"),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Payment",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(payment),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Status",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text("On the way"),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteSummary(ThemeData theme) {
    final fare = job?.fareUsd;
    final eta = _estimateEta();
    final driverName = job?.driver?['name'] ?? 'Your driver';
    final payment = job?.paymentMethod ?? "Famba Card";
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ride complete",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                const Text("Dropoff complete"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ETA",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(eta ?? "~"),
                  ],
                ),
                const Text("Fare", style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  fare != null ? "\$${fare.toStringAsFixed(2)}" : "\$--",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Payment",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(payment),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _hasRated ? null : () => _showRatingSheet(theme, driverName),
                icon: const Icon(Icons.star_rate_rounded),
                label: Text(_hasRated ? "Thanks for rating!" : "Rate your driver"),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _shareTrip(),
                icon: const Icon(Icons.share),
                label: const Text("Share trip"),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _estimateEta() {
    final status = job?.status;
    if (status == null) return null;
    switch (status) {
      case "driver_assigned":
      case "enroute":
        return "~4 min";
      case "arrived":
        return "~2 min";
      case "riding":
        return "~6 min";
      case "complete":
        return "0 min";
      default:
        return null;
    }
  }
  Future<void> _showRatingSheet(ThemeData theme, String driverName) async {
    double rating = 5;
    final controller = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 12),
                  Text(
                    "Rate $driverName",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < rating.round();
                      return IconButton(
                        onPressed: () => setState(() => rating = i + 1),
                        icon: Icon(
                          filled ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 32,
                          color: filled
                              ? theme.colorScheme.primary
                              : Colors.grey.shade400,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Add a comment (optional)",
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text("Submit"),
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
            content: Text(
                "Thanks! You rated $driverName ${rating.toStringAsFixed(0)}★"),
            action: SnackBarAction(
              label: "Share trip",
              onPressed: _shareTrip,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit rating: $e")),
        );
      }
    }
  }

  void _shareTrip() {
    final id = job?.id ?? "";
    final url = "https://famba.app/trip/$id";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Trip link copied: $url")),
    );
  }

  Widget _buildDriverRow(ThemeData theme) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    (job!.driver!['name'] as String).substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job!.driver!['name'],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star,
                              size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text("${job!.driver!['rating']}",
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            "• Helmet check ✓",
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        job!.status == "driver_assigned"
                            ? "~2 min"
                            : job!.status == "enroute"
                                ? "En route"
                                : job!.status == "arrived"
                                    ? "Arrived"
                                    : job!.status == "riding"
                                        ? "Riding"
                                        : "Done",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Bike",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text("Bajaj Boxer • Green",
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Plate",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text("MBK-2489",
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    _pillButton(theme, icon: Icons.call, label: "Call"),
                    const SizedBox(width: 8),
                    _pillButton(theme, icon: Icons.chat, label: "Message"),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _pillButton(ThemeData theme, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}

class _PulsingPin extends StatefulWidget {
  final Color color;
  const _PulsingPin({required this.color});

  @override
  State<_PulsingPin> createState() => _PulsingPinState();
}

class _PulsingPinState extends State<_PulsingPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

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
            final scale = 1 + (_controller.value * 0.6);
            final opacity = (1 - _controller.value).clamp(0.0, 1.0);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.25 * opacity),
                ),
              ),
            );
          },
        ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.35),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(Icons.navigation, color: widget.color, size: 18),
        ),
      ],
    );
  }
}
