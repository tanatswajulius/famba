import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/driver_state.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverState>(
      builder: (context, state, _) {
        final ride = state.activeRide;
        if (ride == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Navigation')),
            body: const Center(child: Text('No active ride')),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              // Map
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(ride.pickupLat, ride.pickupLng),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(state.lat, state.lng),
                            LatLng(ride.pickupLat, ride.pickupLng),
                            LatLng(ride.dropLat, ride.dropLng),
                          ],
                          strokeWidth: 4,
                          color: FambaColors.primary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Driver
                        Marker(
                          point: LatLng(state.lat, state.lng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: FambaColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.motorcycle, color: Colors.white, size: 24),
                          ),
                        ),
                        // Pickup
                        Marker(
                          point: LatLng(ride.pickupLat, ride.pickupLng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: FambaColors.primary, width: 3),
                            ),
                            child: const Icon(Icons.person, color: FambaColors.primary, size: 24),
                          ),
                        ),
                        // Dropoff
                        Marker(
                          point: LatLng(ride.dropLat, ride.dropLng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: FambaColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flag, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: FambaColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.arrow_back, color: FambaColors.textPrimary),
                  ),
                ),
              ),

              // Bottom panel
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
                  decoration: BoxDecoration(
                    color: FambaColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rider info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: FambaColors.primary.withOpacity(0.2),
                            child: Text(
                              ride.riderName[0],
                              style: const TextStyle(
                                color: FambaColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ride.riderName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: FambaColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  _getStatusText(state.rideStatus),
                                  style: TextStyle(color: FambaColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          // Call button
                          IconButton(
                            onPressed: () {},
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: FambaColors.primary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call, color: FambaColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Destination
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FambaColors.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              state.rideStatus == 'riding' 
                                  ? Icons.flag 
                                  : Icons.location_on,
                              color: state.rideStatus == 'riding' 
                                  ? FambaColors.error 
                                  : FambaColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.rideStatus == 'riding' 
                                    ? ride.dropoff 
                                    : ride.pickup,
                                style: const TextStyle(
                                  color: FambaColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '\$${ride.fare.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: FambaColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _handleAction(context, state),
                          child: Text(
                            _getButtonText(state.rideStatus),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Navigating to pickup';
      case 'arrived':
        return 'Waiting for rider';
      case 'riding':
        return 'Trip in progress';
      default:
        return 'Starting trip';
    }
  }

  String _getButtonText(String status) {
    switch (status) {
      case 'accepted':
        return "I've Arrived";
      case 'arrived':
        return 'Start Trip';
      case 'riding':
        return 'Complete Trip';
      default:
        return 'Start';
    }
  }

  void _handleAction(BuildContext context, DriverState state) {
    switch (state.rideStatus) {
      case 'accepted':
        state.arrivedAtPickup();
        break;
      case 'arrived':
        state.startRide();
        break;
      case 'riding':
        state.completeRide();
        Navigator.popUntil(context, ModalRoute.withName('/home'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip completed! You earned \$${(state.activeRide?.fare ?? 0 * 0.85).toStringAsFixed(2)}'),
            backgroundColor: FambaColors.success,
          ),
        );
        break;
    }
  }
}

