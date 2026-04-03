import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../main.dart';
import '../core/driver_state.dart';
import '../core/driver_api.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  Timer? _mockRequestTimer;
  WebSocketChannel? _wsChannel;
  bool _modalShowing = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _startMockRequests();
  }

  @override
  void dispose() {
    _mockRequestTimer?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(DriverApi.wsUrl));
      _wsChannel!.stream.listen(
        (message) {
          dynamic data;
          try {
            data = jsonDecode(message);
          } catch (_) {
            return;
          }
          final state = context.read<DriverState>();
          final type = data['type'] ?? '';
          if (type == 'ride_request' && state.isOnline && !state.isBusy) {
            state.receiveRequest(RideRequest.fromJson(data['data']));
          } else if (type == 'delivery_request' && state.isOnline && !state.isBusy) {
            state.receiveDeliveryRequest(DeliveryRequest.fromJson(data['data']));
          }
        },
        onError: (_) {},
        onDone: () {
          // Retry after delay - WebSocket is optional
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _connectWebSocket();
          });
        },
      );
    } catch (_) {
      // WebSocket not available, fall back to mock requests
    }
  }

  void _startMockRequests() {
    _mockRequestTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final state = context.read<DriverState>();
      if (!state.isOnline || state.isBusy || state.currentRequest != null || state.currentDeliveryRequest != null) return;

      final second = DateTime.now().second;
      if (second % 3 == 0) {
        // Delivery request
        state.receiveDeliveryRequest(DeliveryRequest(
          orderId: 'FO-${DateTime.now().millisecondsSinceEpoch}',
          restaurantName: ['Chicken Inn CBD', 'Nandos Avondale', 'Pizza Inn Eastgate'][second % 3],
          restaurantAddress: 'Harare CBD',
          customerName: ['John M.', 'Mary K.', 'Peter T.', 'Jane S.'][second % 4],
          deliveryAddress: ['12 Fife Ave, Harare', '5 Josiah Chinamano Ave', 'UZ Main Campus'][second % 3],
          totalAmount: 8.50 + (second % 5),
          itemCount: 2 + (second % 3),
          restaurantLat: -17.8292,
          restaurantLng: 31.0522,
          deliveryLat: -17.8200 + (second % 5) * 0.002,
          deliveryLng: 31.0490 + (second % 5) * 0.002,
          items: [
            {'name': '2pc Chicken Meal', 'qty': 1, 'price': 5.50},
            {'name': 'Chips (Large)', 'qty': 1, 'price': 2.00},
          ],
        ));
      } else {
        // Ride request
        state.receiveRequest(RideRequest(
          id: 'J-${DateTime.now().millisecondsSinceEpoch}',
          riderName: ['John', 'Mary', 'Peter', 'Jane'][second % 4],
          pickup: 'UZ Campus Gate',
          dropoff: 'First Street Mall',
          fare: 2.50 + (second % 3),
          distance: 3.0 + (second % 5) * 0.5,
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
        if (state.currentRequest != null && !_modalShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.currentRequest != null && !_modalShowing) _showRideRequest(context, state);
          });
        }
        if (state.currentDeliveryRequest != null && !_modalShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.currentDeliveryRequest != null && !_modalShowing) _showDeliveryRequest(context, state);
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: _buildMap(state)),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16, right: 16,
                child: _buildTopBar(state),
              ),
              _buildBottomSheet(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(DriverState state) {
    return FlutterMap(
      options: MapOptions(initialCenter: LatLng(state.lat, state.lng), initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.famba.driver',
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 50, height: 50,
              point: LatLng(state.lat, state.lng),
              child: Container(
                decoration: BoxDecoration(
                  color: state.isOnline ? FambaColors.primary : FambaColors.offline,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: (state.isOnline ? FambaColors.primary : FambaColors.offline).withValues(alpha: 0.4),
                    blurRadius: 12, spreadRadius: 4,
                  )],
                ),
                child: const Icon(Icons.motorcycle, color: Colors.white, size: 28),
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
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: FambaColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
            ),
            child: const Icon(Icons.menu, color: FambaColors.textPrimary),
          ),
        ),
        const Spacer(),
        // Status + connection
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: state.isOnline ? FambaColors.online : FambaColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: state.isOnline ? Colors.white : FambaColors.offline, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                state.isOnline ? 'Online' : 'Offline',
                style: TextStyle(color: state.isOnline ? Colors.white : FambaColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/earnings'),
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: FambaColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
            ),
            child: const Icon(Icons.account_balance_wallet, color: FambaColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(DriverState state) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: FambaColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: FambaColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),

              // Today's stats
              Row(
                children: [
                  Expanded(child: _statCard(Icons.attach_money, "Earnings", '\$${state.todayEarnings.toStringAsFixed(2)}')),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard(Icons.motorcycle, "Rides", '${state.todayTrips}')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard(Icons.restaurant_rounded, "Deliveries", '${state.todayDeliveries}')),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard(Icons.star, "Rating", state.rating.toStringAsFixed(1))),
                ],
              ),
              const SizedBox(height: 24),

              // Go Online/Offline
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: () => state.toggleOnline(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isOnline ? FambaColors.error : FambaColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(state.isOnline ? Icons.power_off : Icons.power, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        state.isOnline ? 'Go Offline' : 'Go Online',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),

              if (state.isOnline && !state.isBusy) ...[
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: FambaColors.primary)),
                      const SizedBox(width: 10),
                      Text(
                        'Waiting for ride & delivery requests...',
                        style: TextStyle(color: FambaColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],

              // Active trip/delivery info
              if (state.isOnTrip && state.activeRide != null) ...[
                const SizedBox(height: 16),
                _activeTaskCard(
                  icon: Icons.motorcycle,
                  label: 'Active Ride',
                  detail: '${state.activeRide!.pickup} → ${state.activeRide!.dropoff}',
                  amount: '\$${state.activeRide!.fare.toStringAsFixed(2)}',
                  onTap: () => Navigator.pushNamed(context, '/navigation'),
                ),
              ],
              if (state.isOnDelivery && state.activeDelivery != null) ...[
                const SizedBox(height: 16),
                _activeTaskCard(
                  icon: Icons.restaurant_rounded,
                  label: 'Active Delivery',
                  detail: '${state.activeDelivery!.restaurantName} → ${state.activeDelivery!.deliveryAddress}',
                  amount: '\$${state.activeDelivery!.totalAmount.toStringAsFixed(2)}',
                  onTap: () => Navigator.pushNamed(context, '/delivery-navigation'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FambaColors.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FambaColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: FambaColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: FambaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _activeTaskCard({required IconData icon, required String label, required String detail, required String amount, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FambaColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FambaColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: FambaColors.primary, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: FambaColors.primary)),
                  const SizedBox(height: 2),
                  Text(detail, style: TextStyle(fontSize: 12, color: FambaColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(amount, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: FambaColors.primary)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: FambaColors.primary),
          ],
        ),
      ),
    );
  }

  // ============= REQUEST POPUPS =============

  void _showRideRequest(BuildContext context, DriverState state) {
    _modalShowing = true;
    final request = state.currentRequest!;
    showModalBottomSheet<void>(
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
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: FambaColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.motorcycle, color: FambaColors.primary, size: 16),
                  const SizedBox(width: 6),
                  const Text('Ride Request', style: TextStyle(color: FambaColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: FambaColors.primary.withValues(alpha: 0.2),
                  child: Text(request.riderName[0], style: const TextStyle(color: FambaColors.primary, fontWeight: FontWeight.bold, fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.riderName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FambaColors.textPrimary)),
                    Text('${request.distance.toStringAsFixed(1)} km • ${request.etaMinutes} min away', style: TextStyle(color: FambaColors.textSecondary)),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\$${request.fare.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: FambaColors.primary)),
                  Text('Est. fare', style: TextStyle(fontSize: 12, color: FambaColors.textSecondary)),
                ]),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: FambaColors.card, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  _locationRow(Icons.radio_button_checked, FambaColors.primary, request.pickup),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Container(width: 2, height: 20, color: FambaColors.textSecondary.withValues(alpha: 0.3)),
                  ),
                  _locationRow(Icons.location_on, FambaColors.error, request.dropoff),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  onPressed: () { _modalShowing = false; state.declineRide(); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: FambaColors.error), foregroundColor: FambaColors.error),
                  child: const Text('Decline'),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  onPressed: () { _modalShowing = false; state.acceptRide(); Navigator.pop(context); Navigator.pushNamed(context, '/navigation'); },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Accept Ride'),
                )),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showDeliveryRequest(BuildContext context, DriverState state) {
    _modalShowing = true;
    final req = state.currentDeliveryRequest!;
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
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: FambaColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant_rounded, color: FambaColors.warning, size: 16),
                  const SizedBox(width: 6),
                  const Text('Delivery Request', style: TextStyle(color: FambaColors.warning, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Restaurant info
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: FambaColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.restaurant, color: FambaColors.warning, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.restaurantName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FambaColors.textPrimary)),
                    Text('${req.itemCount} items • ${req.customerName}', style: TextStyle(color: FambaColors.textSecondary)),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\$${req.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: FambaColors.warning)),
                  Text('Order total', style: TextStyle(fontSize: 12, color: FambaColors.textSecondary)),
                ]),
              ],
            ),
            const SizedBox(height: 16),
            // Route
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: FambaColors.card, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  _locationRow(Icons.store, FambaColors.warning, req.restaurantName),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Container(width: 2, height: 20, color: FambaColors.textSecondary.withValues(alpha: 0.3)),
                  ),
                  _locationRow(Icons.location_on, FambaColors.primary, req.deliveryAddress),
                ],
              ),
            ),
            // Items preview
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: FambaColors.card, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: FambaColors.textSecondary)),
                  const SizedBox(height: 6),
                  ...req.items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text('${item['qty']}x ', style: TextStyle(color: FambaColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                        Expanded(child: Text(item['name'] ?? '', style: const TextStyle(color: FambaColors.textPrimary, fontSize: 13))),
                      ],
                    ),
                  )),
                  if (req.items.length > 3)
                    Text('+${req.items.length - 3} more items', style: TextStyle(color: FambaColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  onPressed: () { _modalShowing = false; state.declineDelivery(); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: FambaColors.error), foregroundColor: FambaColors.error),
                  child: const Text('Decline'),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  onPressed: () { _modalShowing = false; state.acceptDelivery(); Navigator.pop(context); Navigator.pushNamed(context, '/delivery-navigation'); },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: FambaColors.warning),
                  child: const Text('Accept Delivery', style: TextStyle(color: Colors.white)),
                )),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: FambaColors.textPrimary, fontSize: 15))),
      ],
    );
  }
}
