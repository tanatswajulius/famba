import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/api.dart';
import '../core/app_state.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _specialInstructionsController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isPlacingOrder = false;
  String? _error;

  @override
  void dispose() {
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final state = context.read<AppState>();
    if (state.cartItems.isEmpty ||
        state.cartRestaurantId == null ||
        state.cartRestaurantName == null) {
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _error = null;
    });

    try {
      final res = await Api.createFoodOrder(
        restaurantId: state.cartRestaurantId!,
        items: state.cartItems.map((i) => i.toJson()).toList(),
        deliveryAddress: 'Harare, Zimbabwe',
        riderName: state.riderName,
        paymentMethod: _paymentMethod,
        specialInstructions: _specialInstructionsController.text.trim().isEmpty
            ? null
            : _specialInstructionsController.text.trim(),
      );

      final orderId = res['id'] as String?;
      if (orderId != null) {
        state.clearCart();
        state.setOrder(orderId);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/food-order-tracking');
        }
      } else {
        setState(() {
          _error = 'Failed to create order';
          _isPlacingOrder = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isPlacingOrder = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cartItems = state.cartItems;
    final cartRestaurantName = state.cartRestaurantName ?? '';
    final subtotal = state.cartSubtotal;
    const deliveryFee = 1.0;
    final total = subtotal + deliveryFee;

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: FambaColors.background,
        appBar: AppBar(title: const Text('Cart')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 24),
              Text(
                'Your cart is empty',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: FambaColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add items from a restaurant to get started',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
                child: const Text('Browse Restaurants'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    cartRestaurantName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...cartItems.map((item) => _CartItemTile(item: item)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _specialInstructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Special instructions',
                      hintText: 'e.g. No onions, extra sauce...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Payment method',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentRadio(
                          label: 'Cash',
                          value: 'cash',
                          groupValue: _paymentMethod,
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PaymentRadio(
                          label: 'Famba Wallet',
                          value: 'wallet',
                          groupValue: _paymentMethod,
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FambaColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _OrderSummaryRow(label: 'Subtotal', value: '\$${subtotal.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _OrderSummaryRow(label: 'Delivery fee', value: '\$${deliveryFee.toStringAsFixed(2)}'),
                        const Divider(height: 20),
                        _OrderSummaryRow(
                          label: 'Total',
                          value: '\$${total.toStringAsFixed(2)}',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: FambaColors.error, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isPlacingOrder ? null : _placeOrder,
                  child: _isPlacingOrder
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Place Order'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FambaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FambaColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 24),
                color: FambaColors.primary,
                onPressed: () {
                  state.updateCartItemQty(item.menuItemId, item.qty - 1);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.qty}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 24),
                color: FambaColors.primary,
                onPressed: () {
                  state.updateCartItemQty(item.menuItemId, item.qty + 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRadio extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _PaymentRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? FambaColors.primary.withValues(alpha: 0.15)
              : FambaColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? FambaColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? FambaColors.primary : FambaColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _OrderSummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: bold ? FambaColors.textPrimary : FambaColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
