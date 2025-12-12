import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/driver_state.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  Timer? _mockRequestTimer;

  @override
  void initState() {
    super.initState();
    // Simulate incoming ride requests when online
    _startMockRequests();
  }

  @override
  void dispose() {
    _mockRequestTimer?.cancel();
    super.dispose();
  }

  void _startMockRequests() {
    _mockRequestTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final state = context.read<DriverState>();
      if (state.isOnline && !state.isOnTrip && state.currentRequest == null) {
        // Simulate a ride request
        state.receiveRequest(RideRequest(
          id: 'J${DateTime.now().millisecondsSinceEpoch}',
          riderName: ['John', 'Mary', 'Peter', 'Jane'][DateTime.now().second % 4],
          pickup: 'UZ Campus Gate',
          dropoff: 'First Street Mall',
          fare: 2.50 + (DateTime.now().second % 3),
          distance: 3.0 + (DateTime.now().second % 5) * 0.5,
          etaMinutes: 3,
          pickupLat: -17.7830,
          pickupLng: 31.0530,
          dropLat: -17.8292,
          dropLng: 31.0522,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverState>(
      builder: (context, state, _) {
        // Show ride request popup if there's one
        if (state.currentRequest != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRideRequest(context, state);
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // Map
              Positioned.fill(child: _buildMap(state)),
              
              // Top bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: _buildTopBar(state),
              ),
              
              // Bottom sheet
              _buildBottomSheet(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(DriverState state) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(state.lat, state.lng),
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.famba.driver',
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 50,
              height: 50,
              point: LatLng(state.lat, state.lng),
              child: Container(
                decoration: BoxDecoration(
                  color: state.isOnline ? FambaColors.primary : FambaColors.offline,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (state.isOnline ? FambaColors.primary : FambaColors.offline)
                          .withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.motorcycle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBar(DriverState state) {
    return Row(
      children: [
        // Menu button
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FambaColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.menu, color: FambaColors.textPrimary),
          ),
        ),
        const Spacer(),
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: state.isOnline ? FambaColors.online : FambaColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: state.isOnline ? Colors.white : FambaColors.offline,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: state.isOnline ? Colors.white : FambaColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Earnings button
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/earnings'),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FambaColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.account_balance_wallet, color: FambaColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(DriverState state) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: FambaColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FambaColors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Today's summary
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.attach_money,
                      label: "Today's Earnings",
                      value: '\$${state.todayEarnings.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: Icons.motorcycle,
                      label: "Trips",
                      value: '${state.todayTrips}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.star,
                      label: "Rating",
                      value: state.rating.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: Icons.timer,
                      label: "Online Time",
                      value: '2h 34m',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Go Online/Offline button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => state.toggleOnline(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isOnline 
                        ? FambaColors.error 
                        : FambaColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state.isOnline ? Icons.power_off : Icons.power,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        state.isOnline ? 'Go Offline' : 'Go Online',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (state.isOnline && !state.isOnTrip) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Waiting for ride requests...',
                    style: TextStyle(
                      color: FambaColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FambaColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FambaColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: FambaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: FambaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showRideRequest(BuildContext context, DriverState state) {
    final request = state.currentRequest!;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: FambaColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer indicator
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: FambaColors.card,
              color: FambaColors.primary,
            ),
            const SizedBox(height: 20),
            
            // Rider info
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: FambaColors.primary.withOpacity(0.2),
                  child: Text(
                    request.riderName[0],
                    style: const TextStyle(
                      color: FambaColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.riderName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: FambaColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${request.distance.toStringAsFixed(1)} km • ${request.etaMinutes} min away',
                        style: TextStyle(color: FambaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${request.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: FambaColors.primary,
                      ),
                    ),
                    Text(
                      'Est. fare',
                      style: TextStyle(
                        fontSize: 12,
                        color: FambaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Route info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FambaColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _locationRow(
                    icon: Icons.radio_button_checked,
                    color: FambaColors.primary,
                    text: request.pickup,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Container(
                      width: 2,
                      height: 20,
                      color: FambaColors.textSecondary.withOpacity(0.3),
                    ),
                  ),
                  _locationRow(
                    icon: Icons.location_on,
                    color: FambaColors.error,
                    text: request.dropoff,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      state.declineRide();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: FambaColors.error),
                      foregroundColor: FambaColors.error,
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      state.acceptRide();
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/navigation');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _locationRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: FambaColors.textPrimary,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

