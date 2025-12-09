import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pickup = TextEditingController(text: "UZ Campus Gate");
  final _drop = TextEditingController(text: "First Street Mall");
  final _recents = const [
    "Avondale Shops",
    "Causeway",
    "Eastlea Shopping Centre",
  ];
  final _favorites = const [
    "Home",
    "Work",
    "Market",
  ];

  void _applyShortcut(String label) {
    setState(() {
      _drop.text = label;
    });
  }

  void _swap() {
    setState(() {
      final tmp = _pickup.text;
      _pickup.text = _drop.text;
      _drop.text = tmp;
    });
  }

  void _goToQuote() {
    if (_pickup.text.trim().isEmpty || _drop.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Enter both pickup and dropoff"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ));
      return;
    }
    Navigator.pushNamed(
      context,
      '/quote',
      arguments: {
        "pickup": _pickup.text,
        "drop": _drop.text,
        "distanceKm": 3.0
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Famba",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroCard(theme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Where to?",
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: "Swap",
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_vert),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pickup,
              decoration: InputDecoration(
                labelText: "Pickup Location",
                prefixIcon:
                    Icon(Icons.my_location, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _drop,
              decoration: InputDecoration(
                labelText: "Dropoff Location",
                prefixIcon:
                    Icon(Icons.place, color: theme.colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _favorites
                  .map((f) => ChoiceChip(
                        label: Text(f),
                        selected: _drop.text == f,
                        onSelected: (_) => _applyShortcut(f),
                        avatar: const Icon(Icons.bolt, size: 16),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              "Recent",
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 8),
            Column(
              children: _recents
                  .map((r) => ListTile(
                        onTap: () => _applyShortcut(r),
                        leading: Icon(Icons.history,
                            color: theme.colorScheme.primary),
                        title: Text(r),
                        trailing: const Icon(Icons.chevron_right),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: Colors.white,
                        dense: true,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _goToQuote,
                child: const Text("Get Quote"),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/wallet'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            "Wallet / Famba Card",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.primary.withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.electric_scooter,
                  color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Faster rides. Even when offline.",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Queue requests offline, reconnect, and keep moving.",
                    style: TextStyle(fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
