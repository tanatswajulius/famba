import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/api.dart';
import '../core/app_state.dart';

class FoodOrderTrackingScreen extends StatefulWidget {
  const FoodOrderTrackingScreen({super.key});

  @override
  State<FoodOrderTrackingScreen> createState() => _FoodOrderTrackingScreenState();
}

class _FoodOrderTrackingScreenState extends State<FoodOrderTrackingScreen> {
  Map<String, dynamic>? _order;
  String? _restaurantName;
  String? _error;
  bool _isCancelling = false;
  Timer? _pollTimer;

  static const List<_StatusStep> _statusSteps = [
    _StatusStep(id: 'placed', label: 'Placed'),
    _StatusStep(id: 'confirmed', label: 'Confirmed'),
    _StatusStep(id: 'preparing', label: 'Preparing'),
    _StatusStep(id: 'ready', label: 'Ready'),
    _StatusStep(id: 'picked_up', label: 'Picked Up'),
    _StatusStep(id: 'delivering', label: 'Delivering'),
    _StatusStep(id: 'delivered', label: 'Delivered'),
  ];

  String? get _orderId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) return args;
    if (args is Map && args['orderId'] != null) return args['orderId'] as String?;
    return context.read<AppState>().activeOrderId;
  }

  @override
  void initState() {
    super.initState();
    _pollOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollOrder() async {
    final orderId = _orderId;
    if (orderId == null || orderId.isEmpty) {
      setState(() => _error = 'No order ID');
      return;
    }

    try {
      final order = await Api.getFoodOrder(orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _error = null;
        });
        if (_order?['restaurant_id'] != null && _restaurantName == null) {
          _loadRestaurantName(_order!['restaurant_id'] as String);
        }
      }
    } catch (e) {
      if (mounted && _order == null) {
        setState(() => _error = e.toString());
      }
    }

    final status = _order?['status'] as String?;
    if (status != 'delivered' && status != 'cancelled' && mounted) {
      _pollTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => _pollOrder());
    }
  }

  Future<void> _loadRestaurantName(String restaurantId) async {
    try {
      final restaurant = await Api.getRestaurant(restaurantId);
      if (mounted) {
        setState(() {
          _restaurantName = restaurant['name'] as String? ?? 'Restaurant';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _restaurantName = 'Restaurant');
      }
    }
  }

  Future<void> _cancelOrder() async {
    final orderId = _orderId;
    if (orderId == null || _isCancelling) return;

    setState(() => _isCancelling = true);
    try {
      await Api.cancelFoodOrder(orderId: orderId);
      if (mounted) {
        _pollOrder();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isCancelling = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isCancelling = false);
  }

  void _goHome() {
    context.read<AppState>().setOrder('');
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _orderId;
    if (orderId == null || orderId.isEmpty) {
      return Scaffold(
        backgroundColor: FambaColors.background,
        appBar: AppBar(title: const Text('Order Tracking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No order to track',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _goHome,
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    if (_order == null && _error == null) {
      return Scaffold(
        backgroundColor: FambaColors.background,
        appBar: AppBar(title: const Text('Order Tracking')),
        body: const Center(
          child: CircularProgressIndicator(color: FambaColors.primary),
        ),
      );
    }

    if (_error != null && _order == null) {
      return Scaffold(
        backgroundColor: FambaColors.background,
        appBar: AppBar(title: const Text('Order Tracking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: FambaColors.error),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _pollOrder,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final status = order['status'] as String? ?? 'placed';
    final isDelivered = status == 'delivered';
    final isCancelled = status == 'cancelled';
    final canCancel = !isDelivered && !isCancelled &&
        (status == 'placed' || status == 'confirmed');
    final items = order['items'] as List<dynamic>? ?? [];
    final total = (order['total'] ?? 0.0) as num;
    final driver = order['driver'] as Map<String, dynamic>?;
    final estimatedMin = order['estimated_delivery_min'] as int?;
    final restaurantName = _restaurantName ?? order['restaurant_id'] ?? 'Restaurant';

    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(title: const Text('Order Tracking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isCancelled) ...[
              _buildStatusStepper(status),
              const SizedBox(height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FambaColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurantName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) {
                    final i = item as Map<String, dynamic>;
                    final name = i['name'] as String? ?? 'Item';
                    final qty = (i['qty'] ?? 1) as int;
                    final price = (i['price'] ?? 0.0) as num;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$name x$qty - \$${(price * qty).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Text(
                    'Total: \$${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            if (driver != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FambaColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: FambaColors.primary.withValues(alpha: 0.3),
                      child: Icon(Icons.delivery_dining, color: FambaColors.primaryDark),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver['name'] as String? ?? 'Driver',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (driver['vehicle_make'] != null)
                            Text(
                              '${driver['vehicle_make']} ${driver['vehicle_model'] ?? ''}'.trim(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (estimatedMin != null && !isDelivered && !isCancelled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FambaColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FambaColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: FambaColors.primaryDark),
                    const SizedBox(width: 12),
                    Text(
                      'Estimated delivery: $estimatedMin min',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: FambaColors.primaryDark,
                          ),
                    ),
                  ],
                ),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _isCancelling ? null : _cancelOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: FambaColors.error,
                  side: const BorderSide(color: FambaColors.error),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel Order'),
              ),
            ],
            if (isDelivered) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FambaColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FambaColors.success.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 56, color: FambaColors.success),
                    const SizedBox(height: 16),
                    Text(
                      'Order delivered!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: FambaColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _goHome,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
            if (isCancelled) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FambaColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FambaColors.error.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cancel, size: 56, color: FambaColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Order cancelled',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: FambaColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _goHome,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStepper(String currentStatus) {
    final currentIndex = _statusSteps.indexWhere((s) => s.id == currentStatus);
    final activeIndex = currentIndex >= 0 ? currentIndex : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FambaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order status',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          ...List.generate(_statusSteps.length, (i) {
            final step = _statusSteps[i];
            final isCompleted = i <= activeIndex;
            final isCurrent = i == activeIndex;
            final isLast = i == _statusSteps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? FambaColors.primary
                              : Colors.grey.shade200,
                        ),
                        child: isCompleted
                            ? Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isCompleted && i < activeIndex
                                ? FambaColors.primary
                                : Colors.grey.shade200,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Text(
                        step.label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                              color: isCompleted
                                  ? FambaColors.textPrimary
                                  : FambaColors.textSecondary,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatusStep {
  final String id;
  final String label;

  const _StatusStep({required this.id, required this.label});
}
