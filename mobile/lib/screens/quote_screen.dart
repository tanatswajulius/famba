import 'package:flutter/material.dart';
import '../core/api.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../main.dart';
import '../widgets/ride_preferences.dart';
import '../widgets/multi_stop_editor.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});
  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? quote;
  Map<String, dynamic>? recommendation;
  bool loading = true;
  bool isCreatingJob = false;
  String paymentMethod = "Famba Card";
  String pickup = "UZ Campus Gate";
  String drop = "First Street Mall";
  double distanceKm = 3.0;
  
  // New: Ride preferences and multi-stop
  RidePreferences ridePrefs = RidePreferences();
  List<Waypoint> waypoints = [];

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fetched) return;
    _fetched = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      pickup = (args['pickup'] ?? pickup).toString();
      drop = (args['drop'] ?? drop).toString();
      final dk = args['distanceKm'];
      if (dk is num) distanceKm = dk.toDouble();
    }
    _fetchQuote();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuote() async {
    setState(() => loading = true);
    try {
      final q = await Api.quote(
        pickup: pickup,
        drop: drop,
        distanceKm: distanceKm,
      );
      if (!mounted) return;

      try {
        final rec = await Api.recommend(corridor: q['corridor'] ?? 'CBD');
        if (!mounted) return;
        setState(() {
          quote = q;
          recommendation = rec;
          loading = false;
        });
        _animController.forward();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          quote = q;
          loading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback: generate a local quote so the app still works
      final fallbackPrice = (distanceKm * 0.55) + 0.70;
      setState(() {
        quote = {
          'corridor': 'Harare',
          'eta_min': (distanceKm * 3).round(),
          'price_usd': fallbackPrice,
          'base_fare': 0.70,
          'distance_fare': distanceKm * 0.55,
          'total_usd': fallbackPrice,
        };
        loading = false;
      });
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final topDriver = recommendation?['drivers']?.isNotEmpty == true
        ? recommendation!['drivers'][0]
        : null;

    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        title: const Text("Your ride"),
      ),
      body: loading
          ? _buildSkeleton()
          : FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route Summary
                          _buildRouteCard(),
                          const SizedBox(height: 12),
                          // Ride Options Row (Preferences + Multi-stop)
                          _buildRideOptionsRow(),
                          const SizedBox(height: 16),
                          // Price Card
                          _buildPriceCard(),
                          const SizedBox(height: 16),
                          // Driver Card
                          if (topDriver != null) _buildDriverCard(topDriver),
                          const SizedBox(height: 20),
                          // Payment Method
                          _buildPaymentSelector(),
                        ],
                      ),
                    ),
                  ),
                  // Bottom CTA
                  _buildBottomCTA(app, topDriver),
                ],
              ),
            ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: FambaColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 32,
                color: Colors.grey.shade300,
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: FambaColors.error,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FambaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  drop,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FambaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FambaColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.route_rounded, size: 16, color: FambaColors.primaryDark),
                const SizedBox(width: 4),
                Text(
                  "${distanceKm.toStringAsFixed(1)} km",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FambaColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    if (quote == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FambaColors.primary.withOpacity(0.08),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FambaColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Estimated fare",
                    style: TextStyle(
                      fontSize: 14,
                      color: FambaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "\$",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: FambaColors.textPrimary,
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: quote!['price_usd']),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            value.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              color: FambaColors.textPrimary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 18, color: FambaColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      "${quote!['eta_min']} min",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FambaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _fareBreakdownItem("Base", "\$${quote!['base_fare']}"),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _fareBreakdownItem("Distance", "\$${quote!['distance_fare']}"),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _fareBreakdownItem("Total", "\$${quote!['total_usd']}", bold: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareBreakdownItem(String label, String value, {bool bold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: FambaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: bold ? FambaColors.primary : FambaColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Your driver",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FambaColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: FambaColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: FambaColors.success),
                    const SizedBox(width: 4),
                    Text(
                      "Top rated",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FambaColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FambaColors.primary, FambaColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    (driver['name'] ?? 'D')[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: FambaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "${driver['rating']}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_rounded, size: 14, color: FambaColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          "${driver['eta_min']} min away",
                          style: TextStyle(
                            fontSize: 13,
                            color: FambaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FambaColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.two_wheeler_rounded, size: 20, color: FambaColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${driver['vehicle_type'] ?? 'Motorcycle'} • ${driver['vehicle_color'] ?? ''} • ${driver['plate'] ?? ''}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FambaColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FambaColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded, size: 12, color: FambaColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        "Helmet ✓",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FambaColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment method",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FambaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _paymentOption("Famba Card", Icons.credit_card_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _paymentOption("Cash", Icons.payments_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _paymentOption(String label, IconData icon) {
    final isSelected = paymentMethod == label;
    return GestureDetector(
      onTap: () => setState(() => paymentMethod = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? FambaColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? FambaColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? FambaColors.primary : FambaColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? FambaColors.primary : FambaColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 20, color: FambaColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCTA(AppState app, Map<String, dynamic>? topDriver) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (quote != null && !isCreatingJob)
                ? () async {
                    setState(() => isCreatingJob = true);
                    try {
                      final j = await Api.createJob(
                        pickup: pickup,
                        drop: drop,
                        distanceKm: distanceKm,
                        riderName: app.riderName,
                        driverId: topDriver?['id'],
                        fareUsd: quote?['total_usd']?.toDouble(),
                        paymentMethod: paymentMethod,
                      );
                      app.setJob(j['id']);
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/track',
                            arguments: j['id']);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => isCreatingJob = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Booking failed: $e'),
                          backgroundColor: FambaColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: FambaColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isCreatingJob
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Confirm ride",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRideOptionsRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showPreferencesSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: FambaColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPreferencesLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FambaColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _showMultiStopSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: waypoints.isNotEmpty
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: waypoints.isNotEmpty
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_location_alt_rounded,
                    size: 18,
                    color: waypoints.isNotEmpty ? Colors.orange : FambaColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      waypoints.isEmpty
                          ? "Add stops"
                          : "${waypoints.length} stop${waypoints.length > 1 ? 's' : ''}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: waypoints.isNotEmpty
                            ? Colors.orange
                            : FambaColors.textPrimary,
                      ),
                    ),
                  ),
                  if (waypoints.isNotEmpty)
                    Text(
                      "+\$${(waypoints.length * 0.5).toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getPreferencesLabel() {
    final active = <String>[];
    if (ridePrefs.ac) active.add('AC');
    if (ridePrefs.quietRide) active.add('Quiet');
    if (ridePrefs.petFriendly) active.add('Pet');
    if (ridePrefs.helmetProvided) active.add('Helmet');
    return active.isEmpty ? 'Preferences' : active.join(', ');
  }

  void _showPreferencesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RidePreferencesSheet(
        preferences: ridePrefs,
        onChanged: (prefs) => setState(() => ridePrefs = prefs),
      ),
    );
  }

  void _showMultiStopSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiStopEditor(
        waypoints: waypoints,
        onChanged: (stops) => setState(() => waypoints = stops),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBox(height: 90),
          const SizedBox(height: 16),
          _skeletonBox(height: 180),
          const SizedBox(height: 16),
          _skeletonBox(height: 160),
          const Spacer(),
          _skeletonBox(height: 56),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.6),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade200.withOpacity(value),
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}
