import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../main.dart';

class LocationSearchResult {
  final String name;
  final String address;
  final String area;
  final double? lat;
  final double? lng;
  final String? category;

  LocationSearchResult({
    required this.name,
    required this.address,
    required this.area,
    this.lat,
    this.lng,
    this.category,
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      area: json['area'] ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      category: json['category'],
    );
  }

  String get fullAddress => "$name, $area";
}

class LocationSearchSheet extends StatefulWidget {
  final String title;
  final String? initialValue;
  final Function(LocationSearchResult) onSelect;

  const LocationSearchSheet({
    super.key,
    required this.title,
    this.initialValue,
    required this.onSelect,
  });

  static Future<LocationSearchResult?> show(
    BuildContext context, {
    required String title,
    String? initialValue,
  }) async {
    return showModalBottomSheet<LocationSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchSheet(
        title: title,
        initialValue: initialValue,
        onSelect: (result) => Navigator.pop(ctx, result),
      ),
    );
  }

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<LocationSearchResult> _results = [];
  List<LocationSearchResult> _popular = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialValue ?? '';
    _loadPopular();
    
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPopular() async {
    try {
      final results = await Api.getPopularLocations(limit: 8);
      if (!mounted) return;
      setState(() {
        _popular = results.map((r) => LocationSearchResult.fromJson(r)).toList();
      });
    } catch (e) {
      // Ignore errors for popular locations
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await Api.searchLocations(query: query, limit: 10);
      if (!mounted) return;
      setState(() {
        _results = results.map((r) => LocationSearchResult.fromJson(r)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'entertainment':
        return Icons.sports_esports_rounded;
      case 'government':
        return Icons.account_balance_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FambaColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: FambaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: FambaColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "Search for a location...",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: FambaColors.primary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          // Results
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: FambaColors.primary),
                  )
                : _buildResults(),
          ),
          SizedBox(height: keyboardHeight),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final showPopular = _searchController.text.length < 2;
    final items = showPopular ? _popular : _results;

    if (items.isEmpty && !showPopular) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No locations found",
              style: TextStyle(
                fontSize: 16,
                color: FambaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a different search term",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (showPopular) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Popular destinations",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FambaColors.textSecondary,
              ),
            ),
          ),
        ],
        ...items.map((location) => _buildLocationTile(location)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLocationTile(LocationSearchResult location) {
    return GestureDetector(
      onTap: () => widget.onSelect(location),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FambaColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(location.category),
                color: FambaColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: FambaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${location.address}, ${location.area}",
                    style: TextStyle(
                      fontSize: 13,
                      color: FambaColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

