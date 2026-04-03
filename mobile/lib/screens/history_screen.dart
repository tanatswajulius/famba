import 'package:flutter/material.dart';
import '../core/api.dart';
import '../main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await Api.getOrderHistory(limit: 100);
      if (mounted) setState(() { _all = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _rides =>
      _all.where((h) => h['type'] == 'ride').toList();

  List<Map<String, dynamic>> get _foodOrders =>
      _all.where((h) => h['type'] == 'food_order').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FambaColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
        ),
        title: const Text(
          'Order History',
          style: TextStyle(color: FambaColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: FambaColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: FambaColors.primary,
          tabs: [
            Tab(text: 'All (${_all.length})'),
            Tab(text: 'Rides (${_rides.length})'),
            Tab(text: 'Food (${_foodOrders.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_all),
                _buildList(_rides),
                _buildList(_foodOrders),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No orders yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _historyCard(items[index]),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final isRide = item['type'] == 'ride';
    final status = item['status'] ?? 'unknown';
    final amount = item['amount'];

    Color statusColor;
    switch (status) {
      case 'complete':
      case 'delivered':
        statusColor = FambaColors.success;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = FambaColors.primary;
    }

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/receipt', arguments: item);
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRide
                      ? FambaColors.primary.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isRide ? Icons.motorcycle_rounded : Icons.restaurant_rounded,
                  color: isRide ? FambaColors.primary : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRide ? 'Ride' : 'Food Order',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Text(
                      item['id'] ?? '',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isRide) ...[
            _infoRow(Icons.my_location_rounded, item['from'] ?? 'Unknown pickup'),
            const SizedBox(height: 4),
            _infoRow(Icons.location_on_rounded, item['to'] ?? 'Unknown drop'),
          ] else ...[
            _infoRow(Icons.store_rounded, item['restaurant'] ?? 'Unknown restaurant'),
            _infoRow(Icons.shopping_bag_rounded, '${item['items_count'] ?? 0} items'),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(item['created_at']),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              Text(
                amount != null ? '\$${(amount as num).toStringAsFixed(2)}' : '--',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
