import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/api.dart';
import '../core/app_state.dart';

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({super.key});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  Map<String, dynamic>? _restaurant;
  bool _loading = true;
  String? _error;

  static const List<String> _categoryOrder = [
    'main',
    'side',
    'drink',
    'dessert',
    'combo',
  ];

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    String? restaurantId;
    if (args is String) {
      restaurantId = args;
    } else if (args is int) {
      restaurantId = args.toString();
    } else if (args is Map) {
      restaurantId = args['restaurantId']?.toString();
    }

    if (restaurantId == null || restaurantId.isEmpty) {
      setState(() {
        _error = 'Restaurant not found';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await Api.getRestaurant(restaurantId);
      if (mounted) {
        setState(() {
          _restaurant = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Provide a fallback demo restaurant with menu
        setState(() {
          _restaurant = _demoRestaurantDetail(restaurantId!);
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _demoRestaurantDetail(String id) {
    final names = {
      'rest_01': 'Chicken Inn CBD', 'rest_02': "Nando's Avondale",
      'rest_03': 'Galley Cafe', 'rest_04': "Mambo's Grill",
      'rest_05': 'Spur Borrowdale', 'rest_06': 'Pizza Inn Milton Park',
      'rest_07': 'Freshly Squeezed', 'rest_08': "Mimi's Kitchen",
    };
    return {
      'id': id,
      'name': names[id] ?? 'Restaurant',
      'cuisine': 'Local, African',
      'rating': 4.5,
      'delivery_fee': 1.0,
      'avg_prep_time_min': 20,
      'is_open': true,
      'menu': [
        {'id': 1, 'name': 'Chicken & Chips', 'price': 3.50, 'category': 'mains', 'description': 'Crispy fried chicken with fries'},
        {'id': 2, 'name': 'Beef Burger', 'price': 4.00, 'category': 'mains', 'description': 'Grilled beef patty with fresh toppings'},
        {'id': 3, 'name': 'Sadza & Stew', 'price': 2.50, 'category': 'mains', 'description': 'Traditional sadza with beef or chicken stew'},
        {'id': 4, 'name': 'Veggie Wrap', 'price': 3.00, 'category': 'mains', 'description': 'Fresh vegetables in a toasted wrap'},
        {'id': 5, 'name': 'Coke 500ml', 'price': 1.00, 'category': 'drinks', 'description': 'Coca-Cola 500ml bottle'},
        {'id': 6, 'name': 'Fanta Orange', 'price': 1.00, 'category': 'drinks', 'description': 'Fanta Orange 500ml bottle'},
        {'id': 7, 'name': 'Water 500ml', 'price': 0.50, 'category': 'drinks', 'description': 'Still water'},
        {'id': 8, 'name': 'Ice Cream', 'price': 1.50, 'category': 'desserts', 'description': 'Vanilla ice cream cup'},
      ],
    };
  }

  Map<String, List<Map<String, dynamic>>> _groupMenuByCategory() {
    if (_restaurant == null) return {};
    final menu = _restaurant!['menu'] as List<dynamic>? ?? [];
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final raw in menu) {
      final item = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
      final category = (item['category'] as String?) ?? 'main';
      grouped.putIfAbsent(category, () => []).add(item);
    }

    // Sort categories by predefined order, then alphabetically for extras
    final ordered = <String, List<Map<String, dynamic>>>{};
    for (final cat in _categoryOrder) {
      if (grouped.containsKey(cat)) {
        ordered[cat] = grouped[cat]!;
      }
    }
    for (final entry in grouped.entries) {
      if (!ordered.containsKey(entry.key)) {
        ordered[entry.key] = entry.value;
      }
    }
    return ordered;
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'main':
        return 'Mains';
      case 'side':
        return 'Sides';
      case 'drink':
        return 'Drinks';
      case 'dessert':
        return 'Desserts';
      case 'combo':
        return 'Combos';
      default:
        return category[0].toUpperCase() + category.substring(1);
    }
  }

  void _addToCart(Map<String, dynamic> item) {
    final restaurantId = _restaurant?['id'] as String?;
    final restaurantName = _restaurant?['name'] as String? ?? 'Restaurant';

    if (restaurantId == null) return;

    final menuItemId = (item['id'] as num).toInt();
    final name = item['name'] as String? ?? 'Item';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;

    final cartItem = CartItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
    );

    context.read<AppState>().addToCart(cartItem, restaurantId, restaurantName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $name to cart'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FambaColors.primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(
        title: Text(_restaurant?['name'] as String? ?? 'Restaurant'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FambaColors.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
      bottomNavigationBar: context.watch<AppState>().cartCount > 0
          ? _buildCartBar()
          : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: FambaColors.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadRestaurant,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final restaurant = _restaurant!;
    final name = restaurant['name'] as String? ?? 'Restaurant';
    final cuisine = restaurant['cuisine'] as String? ?? '';
    final rating = (restaurant['rating'] ?? 0.0) as num;
    final deliveryFee = (restaurant['delivery_fee'] ?? 0.0) as num;
    final prepTime = (restaurant['avg_prep_time_min'] ?? 25) as int;
    final isOpen = restaurant['is_open'] as bool? ?? true;
    final grouped = _groupMenuByCategory();

    return CustomScrollView(
      slivers: [
        // Restaurant header
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FambaColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (cuisine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    cuisine,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: FambaColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '\$${deliveryFee.toStringAsFixed(2)} delivery',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule_outlined, size: 14, color: FambaColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$prepTime min prep',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? FambaColors.success.withValues(alpha: 0.15)
                        : FambaColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOpen ? 'Open' : 'Closed',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isOpen ? FambaColors.success : FambaColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Menu sections
        ...grouped.entries.map((entry) {
          final category = entry.key;
          final items = entry.value;
          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    _categoryLabel(category),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: FambaColors.textPrimary,
                        ),
                  ),
                ),
                ...items.map((item) => _MenuItemCard(
                      item: item,
                      onAdd: () => _addToCart(item),
                    )),
              ],
            ),
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildCartBar() {
    final count = context.watch<AppState>().cartCount;
    final subtotal = context.watch<AppState>().cartSubtotal;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: FambaColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FambaColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart, size: 22),
                const SizedBox(width: 10),
                Text(
                  'View Cart ($count ${count == 1 ? 'item' : 'items'}) - \$${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAdd;

  const _MenuItemCard({
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Item';
    final description = item['description'] as String? ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final isPopular = item['is_popular'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FambaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: FambaColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Popular',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: FambaColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: FambaColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: FambaColors.primary,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
