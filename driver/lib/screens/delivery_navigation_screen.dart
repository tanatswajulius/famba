import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/driver_state.dart';

class DeliveryNavigationScreen extends StatelessWidget {
  const DeliveryNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverState>(
      builder: (context, state, _) {
        final delivery = state.activeDelivery;
        if (delivery == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Delivery')),
            body: const Center(child: Text('No active delivery', style: TextStyle(color: FambaColors.textPrimary))),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              // Map
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(delivery.restaurantLat, delivery.restaurantLng),
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
                            LatLng(delivery.restaurantLat, delivery.restaurantLng),
                            LatLng(delivery.deliveryLat, delivery.deliveryLng),
                          ],
                          strokeWidth: 4,
                          color: FambaColors.warning,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Driver
                        Marker(
                          point: LatLng(state.lat, state.lng), width: 40, height: 40,
                          child: Container(
                            decoration: const BoxDecoration(color: FambaColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.motorcycle, color: Colors.white, size: 24),
                          ),
                        ),
                        // Restaurant
                        Marker(
                          point: LatLng(delivery.restaurantLat, delivery.restaurantLng), width: 40, height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle,
                              border: Border.all(color: FambaColors.warning, width: 3),
                            ),
                            child: const Icon(Icons.restaurant, color: FambaColors.warning, size: 22),
                          ),
                        ),
                        // Customer
                        Marker(
                          point: LatLng(delivery.deliveryLat, delivery.deliveryLng), width: 40, height: 40,
                          child: Container(
                            decoration: const BoxDecoration(color: FambaColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.person, color: Colors.white, size: 22),
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
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: FambaColors.surface, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.arrow_back, color: FambaColors.textPrimary),
                  ),
                ),
              ),

              // Status badge
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: FambaColors.warning, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restaurant_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _getDeliveryStatusLabel(state.deliveryStatus),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom panel
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
                  decoration: BoxDecoration(
                    color: FambaColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delivery progress stepper
                      _buildProgressBar(state.deliveryStatus),
                      const SizedBox(height: 16),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: FambaColors.card, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            // Restaurant
                            Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: FambaColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.store, color: FambaColors.warning, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(delivery.restaurantName, style: const TextStyle(color: FambaColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                                    Text('${delivery.itemCount} items', style: TextStyle(color: FambaColors.textSecondary, fontSize: 12)),
                                  ],
                                )),
                                Text('\$${delivery.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: FambaColors.warning, fontWeight: FontWeight.w700, fontSize: 16)),
                              ],
                            ),
                            Divider(color: FambaColors.textSecondary.withValues(alpha: 0.15), height: 20),
                            // Customer
                            Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: FambaColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.person, color: FambaColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(delivery.customerName, style: const TextStyle(color: FambaColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                                    Text(delivery.deliveryAddress, style: TextStyle(color: FambaColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                )),
                                // Call button
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: FambaColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: const Icon(Icons.call, color: FambaColors.primary, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Order items (collapsible)
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        collapsedBackgroundColor: FambaColors.card,
                        backgroundColor: FambaColors.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text('Order Items (${delivery.itemCount})', style: const TextStyle(color: FambaColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        iconColor: FambaColors.textSecondary,
                        collapsedIconColor: FambaColors.textSecondary,
                        children: delivery.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text('${item['qty']}x ', style: const TextStyle(color: FambaColors.warning, fontWeight: FontWeight.w700, fontSize: 13)),
                              Expanded(child: Text(item['name'] ?? '', style: const TextStyle(color: FambaColors.textPrimary, fontSize: 13))),
                              Text('\$${((item['price'] ?? 0) * (item['qty'] ?? 1)).toStringAsFixed(2)}', style: TextStyle(color: FambaColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          if (state.deliveryStatus == 'accepted' || state.deliveryStatus == 'at_restaurant')
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  state.cancelDelivery();
                                  Navigator.popUntil(context, ModalRoute.withName('/home'));
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: FambaColors.error),
                                  foregroundColor: FambaColors.error,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          if (state.deliveryStatus == 'accepted' || state.deliveryStatus == 'at_restaurant')
                            const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () => _handleDeliveryAction(context, state),
                                style: ElevatedButton.styleFrom(backgroundColor: FambaColors.warning),
                                child: Text(
                                  _getActionButtonText(state.deliveryStatus),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildProgressBar(String status) {
    final steps = ['accepted', 'at_restaurant', 'picked_up', 'delivering', 'delivered'];
    final currentIdx = steps.indexOf(status).clamp(0, steps.length - 1);
    final labels = ['En Route', 'At Restaurant', 'Picked Up', 'Delivering', 'Delivered'];

    return Row(
      children: List.generate(steps.length, (i) {
        final active = i <= currentIdx;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0) Expanded(child: Container(height: 3, color: active ? FambaColors.warning : FambaColors.card)),
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: active ? FambaColors.warning : FambaColors.card,
                      shape: BoxShape.circle,
                    ),
                    child: active ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  if (i < steps.length - 1) Expanded(child: Container(height: 3, color: i < currentIdx ? FambaColors.warning : FambaColors.card)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(fontSize: 9, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? FambaColors.warning : FambaColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }

  String _getDeliveryStatusLabel(String status) {
    switch (status) {
      case 'accepted': return 'Heading to Restaurant';
      case 'at_restaurant': return 'At Restaurant';
      case 'picked_up': return 'Order Picked Up';
      case 'delivering': return 'Delivering to Customer';
      case 'delivered': return 'Delivered';
      default: return 'Starting Delivery';
    }
  }

  String _getActionButtonText(String status) {
    switch (status) {
      case 'accepted': return "Arrived at Restaurant";
      case 'at_restaurant': return "Picked Up Order";
      case 'picked_up': return "Start Delivering";
      case 'delivering': return "Confirm Delivery";
      default: return "Next";
    }
  }

  void _handleDeliveryAction(BuildContext context, DriverState state) {
    switch (state.deliveryStatus) {
      case 'accepted':
        state.arrivedAtRestaurant();
        break;
      case 'at_restaurant':
        state.pickedUpOrder();
        break;
      case 'picked_up':
        state.startDelivering();
        break;
      case 'delivering':
        final earnings = state.activeDelivery!.totalAmount * 0.15;
        state.completeDelivery();
        Navigator.popUntil(context, ModalRoute.withName('/home'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery complete! You earned \$${earnings.toStringAsFixed(2)}'),
            backgroundColor: FambaColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        break;
    }
  }
}
