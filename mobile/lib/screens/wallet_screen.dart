import 'package:flutter/material.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txns = [
      {"title": "Trip • CBD → Avondale", "amount": -3.80, "time": "Today, 2:14 PM"},
      {"title": "Top up • EcoCash", "amount": 10.00, "time": "Yesterday, 7:42 PM"},
      {"title": "Trip • Eastlea → UZ", "amount": -2.60, "time": "Mon, 9:30 AM"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Wallet & Famba Card")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _balanceCard(theme),
          const SizedBox(height: 12),
          _actionRow(theme),
          const SizedBox(height: 20),
          Text("Recent activity",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...txns.map((t) => _txnTile(theme, t)).toList(),
          const SizedBox(height: 16),
          _offlineNote(theme),
        ]),
      ),
    );
  }

  Widget _balanceCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.credit_card, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text("Famba Card",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Virtual",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              )
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "\$12.00",
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text("Available balance",
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9), fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("**** 2489",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text("12/27",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionRow(ThemeData theme) {
    Widget pill(IconData icon, String label, {bool secondary = false}) {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: () => {},
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: secondary
                ? theme.colorScheme.primary.withOpacity(0.12)
                : theme.colorScheme.primary,
            foregroundColor: secondary ? theme.colorScheme.primary : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(Icons.add_circle, "Add cash"),
        const SizedBox(width: 10),
        pill(Icons.credit_card, "Add card", secondary: true),
        const SizedBox(width: 10),
        pill(Icons.arrow_downward, "Withdraw", secondary: true),
      ],
    );
  }

  Widget _txnTile(ThemeData theme, Map<String, dynamic> t) {
    final amount = t['amount'] as double;
    final isDebit = amount < 0;
    final color = isDebit ? Colors.red.shade600 : Colors.green.shade700;
    final icon = isDebit ? Icons.directions_bike : Icons.account_balance_wallet;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(t['title']),
        subtitle: Text(t['time']),
        trailing: Text(
          "${isDebit ? '-' : '+'}\$${amount.abs().toStringAsFixed(2)}",
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  Widget _offlineNote(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Approve rides via offline USSD when data is off (simulated).",
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.85)),
            ),
          ),
        ],
      ),
    );
  }
}
