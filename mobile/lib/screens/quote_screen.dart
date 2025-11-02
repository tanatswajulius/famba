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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quote"),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "$pickup → $drop",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (quote != null) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                  Text(
                                    "\$${quote!['price_usd']}",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              const Text("No quote available"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (topDriver != null)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Top Recommended Driver",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      topDriver['name'][0],
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          topDriver['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.star,
                                                size: 16,
                                                color: Colors.amber.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${topDriver['rating']} • ${topDriver['eta_min']} min away",
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey),
                                            ),
                                          ],
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
                                        onPressed: () => build(context),
                                      ),
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
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
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
            ),
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
