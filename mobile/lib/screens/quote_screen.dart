import 'package:flutter/material.dart';
import '../core/api.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});
  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  Map<String, dynamic>? quote;
  Map<String, dynamic>? recommendation;
  bool loading = true;
  bool isCreatingJob = false;
  String paymentMethod = "Famba Card";
  String pickup = "UZ Campus Gate";
  String drop = "First Street Mall";
  double distanceKm = 3.0;

  @override
  void didChangeDependencies() {
    // Be defensive: route args may be null after hot-reload or direct navigation
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      pickup = (args['pickup'] ?? pickup).toString();
      drop = (args['drop'] ?? drop).toString();
      final dk = args['distanceKm'];
      if (dk is num) distanceKm = dk.toDouble();
    }

    _fetchQuote();
    super.didChangeDependencies();
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
      
      // Fetch driver recommendations based on corridor
      try {
        final rec = await Api.recommend(corridor: q['corridor'] ?? 'CBD');
        if (!mounted) return;
        setState(() {
          quote = q;
          recommendation = rec;
          loading = false;
        });
      } catch (_) {
        // If recommendation fails, still show quote
        if (!mounted) return;
        setState(() {
          quote = q;
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get quote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final topDriver = recommendation?['drivers']?.isNotEmpty == true
        ? recommendation!['drivers'][0]
        : null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quote"),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: loading
            ? _buildSkeleton(theme)
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQuoteCard(theme, topDriver),
                      const SizedBox(height: 12),
                      _buildPaymentSelector(theme),
                      const SizedBox(height: 16),
                      if (topDriver != null) _buildDriverCard(theme, topDriver),
                      const Spacer(),
                      SizedBox(
                        height: 50,
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
                                      Navigator.pushReplacementNamed(
                                          context, '/track',
                                          arguments: j['id']);
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    setState(() => isCreatingJob = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Booking failed: $e'),
                                        backgroundColor: Colors.red,
                                        action: SnackBarAction(
                                          label: 'Retry',
                                          textColor: Colors.white,
                                          onPressed: () => _fetchQuote(),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isCreatingJob
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Confirm Ride",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ]),
              ),
      ),
    );
  }

  Widget _buildQuoteCard(ThemeData theme, Map<String, dynamic>? topDriver) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$pickup → $drop",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (quote != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(
                    icon: Icons.map,
                    label: quote!['corridor'],
                  ),
                  _buildInfoChip(
                    icon: Icons.timer,
                    label: "${quote!['eta_min']} min ETA",
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "Price: ",
                    style: TextStyle(fontSize: 16),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0.1, 0), end: Offset.zero)
                          .animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      "\$${quote!['price_usd']}",
                      key: ValueKey(quote!['price_usd']),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Base \$${quote!['base_fare']}",
                      style: const TextStyle(fontSize: 13)),
                  Text("Distance \$${quote!['distance_fare']}",
                      style: const TextStyle(fontSize: 13)),
                  Text("Total \$${quote!['total_usd']}",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              if (topDriver != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.delivery_dining,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      "${topDriver['name']} • ${topDriver['eta_min']} min • ${topDriver['rating']}★",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              ]
            ] else
              const Text("No quote available"),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSelector(ThemeData theme) {
    final options = ["Famba Card", "Cash"];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payment method",
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.8))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((opt) => ChoiceChip(
                    label: Text(opt),
                    selected: paymentMethod == opt,
                    onSelected: (_) => setState(() => paymentMethod = opt),
                    avatar: opt == "Famba Card"
                        ? const Icon(Icons.credit_card, size: 16)
                        : const Icon(Icons.money, size: 16),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDriverCard(ThemeData theme, Map<String, dynamic> topDriver) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Card(
        key: ValueKey(topDriver['id']),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.12),
                theme.colorScheme.primaryContainer.withOpacity(0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Top Recommended",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text("${topDriver['eta_min']} min",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      topDriver['name'][0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topDriver['name'],
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star,
                                size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text(
                              "${topDriver['rating']}",
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text("• ETA ${topDriver['eta_min']} min",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_moon,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        const Text(
                          "Helmet check ✓",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(ThemeData theme) {
    Widget bar({double height = 16, double width = double.infinity}) {
      return _shimmerBox(theme, height: height, width: width);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(height: 16, width: 180),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      bar(height: 24, width: 90),
                      bar(height: 24, width: 90),
                    ],
                  ),
                  const SizedBox(height: 12),
                  bar(height: 28, width: 120),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(height: 14, width: 140),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      bar(height: 52, width: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(height: 18, width: 120),
                            const SizedBox(height: 8),
                            bar(height: 14, width: 160),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _shimmerBox(theme, height: 50),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _shimmerBox(ThemeData theme,
      {double height = 16, double width = double.infinity}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1 + value * 2, 0),
              end: Alignment(1 + value * 2, 0),
              colors: [
                theme.colorScheme.surfaceVariant.withOpacity(0.4),
                theme.colorScheme.surface.withOpacity(0.6),
                theme.colorScheme.surfaceVariant.withOpacity(0.4),
              ],
              stops: const [0.2, 0.5, 0.8],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
