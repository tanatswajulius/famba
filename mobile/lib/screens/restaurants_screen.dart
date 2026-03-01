import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/api.dart';
import '../core/app_state.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  List<Map<String, dynamic>> _restaurants = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategory = '';

  static final List<Map<String, dynamic>> _demoRestaurants = [
    {'id': 'rest_01', 'name': 'Chicken Inn CBD', 'cuisine': 'Fried Chicken, Fast Food', 'area': 'CBD', 'rating': 4.3, 'delivery_fee': 1.0, 'avg_prep_time_min': 15, 'is_open': true, 'is_featured': true, 'category': 'fast_food'},
    {'id': 'rest_02', 'name': "Nando's Avondale", 'cuisine': 'PERi-PERi, Grills', 'area': 'Avondale', 'rating': 4.5, 'delivery_fee': 1.5, 'avg_prep_time_min': 20, 'is_open': true, 'is_featured': true, 'category': 'restaurant'},
    {'id': 'rest_03', 'name': 'Galley Cafe', 'cuisine': 'Cafe, Breakfast, Sandwiches', 'area': 'Eastlea', 'rating': 4.6, 'delivery_fee': 1.0, 'avg_prep_time_min': 15, 'is_open': true, 'is_featured': false, 'category': 'cafe'},
    {'id': 'rest_04', 'name': "Mambo's Grill", 'cuisine': 'Zimbabwean, Braai, Traditional', 'area': 'CBD', 'rating': 4.6, 'delivery_fee': 1.0, 'avg_prep_time_min': 25, 'is_open': true, 'is_featured': true, 'category': 'restaurant'},
    {'id': 'rest_05', 'name': 'Spur Borrowdale', 'cuisine': 'Steaks, Burgers, Family', 'area': 'Borrowdale', 'rating': 4.4, 'delivery_fee': 2.0, 'avg_prep_time_min': 30, 'is_open': true, 'is_featured': false, 'category': 'restaurant'},
    {'id': 'rest_06', 'name': 'Pizza Inn Milton Park', 'cuisine': 'Pizza, Fast Food', 'area': 'Milton Park', 'rating': 4.2, 'delivery_fee': 1.0, 'avg_prep_time_min': 25, 'is_open': true, 'is_featured': false, 'category': 'fast_food'},
    {'id': 'rest_07', 'name': 'Freshly Squeezed', 'cuisine': 'Smoothies, Juices, Bowls', 'area': 'Avondale', 'rating': 4.7, 'delivery_fee': 0.75, 'avg_prep_time_min': 10, 'is_open': true, 'is_featured': false, 'category': 'cafe'},
    {'id': 'rest_08', 'name': "Mimi's Kitchen", 'cuisine': 'Zimbabwean, Home Cooking', 'area': 'Mbare', 'rating': 4.7, 'delivery_fee': 0.75, 'avg_prep_time_min': 20, 'is_open': true, 'is_featured': false, 'category': 'restaurant'},
  ];

  static const List<Map<String, String>> _filterChips = [
    {'label': 'All', 'value': ''},
    {'label': 'Fast Food', 'value': 'fast_food'},
    {'label': 'Restaurant', 'value': 'restaurant'},
    {'label': 'Cafe', 'value': 'cafe'},
    {'label': 'Grocery', 'value': 'grocery'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> data;
      if (_searchQuery.trim().isNotEmpty) {
        data = await Api.searchRestaurants(_searchQuery.trim());
      } else {
        data = await Api.getRestaurants(
          category: (_selectedCategory != null && _selectedCategory!.isNotEmpty) ? _selectedCategory : null,
        );
      }
      setState(() {
        _restaurants = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = null;
        _restaurants = _demoRestaurants;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _loadRestaurants();
  }

  void _onCategorySelected(String? value) {
    setState(() {
      _selectedCategory = value;
      _searchQuery = '';
    });
    _loadRestaurants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(
        title: const Text('Restaurants'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton: context.watch<AppState>().cartCount > 0
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/cart'),
              backgroundColor: FambaColors.primary,
              child: Badge(
                label: Text('${context.watch<AppState>().cartCount}'),
                backgroundColor: FambaColors.primaryDark,
                child: const Icon(Icons.shopping_cart, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search restaurants...',
          prefixIcon: const Icon(Icons.search, color: FambaColors.textSecondary),
          filled: true,
          fillColor: FambaColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FambaColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: _filterChips.map((chip) {
          final isSelected = _selectedCategory == chip['value'] &&
              _searchQuery.isEmpty;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(chip['label']!),
              selected: isSelected,
              onSelected: (_) => _onCategorySelected(chip['value']),
              backgroundColor: FambaColors.background,
              selectedColor: FambaColors.primary.withValues(alpha: 0.25),
              checkmarkColor: FambaColors.primary,
              side: BorderSide(
                color: isSelected
                    ? FambaColors.primary
                    : Colors.grey.shade200,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: FambaColors.primary),
      );
    }
    if (_error != null) {
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
                onPressed: _loadRestaurants,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_restaurants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No restaurants found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: FambaColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _restaurants.length,
      itemBuilder: (context, index) {
        return _RestaurantCard(
          restaurant: _restaurants[index],
          onTap: () => Navigator.pushNamed(
            context,
            '/restaurant-detail',
            arguments: _restaurants[index]['id'],
          ),
        );
      },
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = restaurant['name'] as String? ?? 'Restaurant';
    final cuisine = restaurant['cuisine'] as String? ?? '';
    final area = restaurant['area'] as String? ??
        restaurant['address'] as String? ??
        '';
    final rating = (restaurant['rating'] ?? 0.0) as num;
    final deliveryFee = (restaurant['delivery_fee'] ?? 0.0) as num;
    final prepTime = (restaurant['avg_prep_time_min'] ?? 25) as int;
    final isOpen = restaurant['is_open'] as bool? ?? true;
    final isFeatured = restaurant['is_featured'] as bool? ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (isFeatured)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: FambaColors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Featured',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: FambaColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? FambaColors.success.withValues(alpha: 0.15)
                                    : FambaColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOpen ? 'Open' : 'Closed',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: isOpen
                                          ? FambaColors.success
                                          : FambaColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (cuisine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            cuisine,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: FambaColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                area,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: FambaColors.warning,
                  ),
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
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: FambaColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$prepTime min',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
