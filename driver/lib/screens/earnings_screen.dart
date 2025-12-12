import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/driver_state.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Earnings'),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Today's earnings card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FambaColors.primary, FambaColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Today's Earnings",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${state.todayEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _miniStat('${state.todayTrips}', 'Trips'),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white30,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        _miniStat('2h 34m', 'Online'),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white30,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        _miniStat(state.rating.toStringAsFixed(1), 'Rating'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Weekly summary
              const Text(
                'This Week',
                style: TextStyle(
                  color: FambaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('Total', '\$45.50', Icons.attach_money)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Trips', '18', Icons.motorcycle)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('Hours', '12.5h', Icons.timer)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Tips', '\$3.00', Icons.favorite)),
                ],
              ),
              const SizedBox(height: 24),

              // Recent trips
              const Text(
                'Recent Trips',
                style: TextStyle(
                  color: FambaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _tripTile('John D.', 'UZ Campus → First St Mall', '\$2.50', '12:34 PM'),
              _tripTile('Mary K.', 'Avondale → CBD', '\$3.20', '11:15 AM'),
              _tripTile('Peter M.', 'Eastgate → Borrowdale', '\$4.00', '10:02 AM'),
              _tripTile('Jane S.', 'Airport → City Center', '\$8.50', 'Yesterday'),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FambaColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: FambaColors.primary, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: FambaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: FambaColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripTile(String rider, String route, String fare, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FambaColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: FambaColors.primary.withOpacity(0.2),
            child: Text(
              rider[0],
              style: const TextStyle(
                color: FambaColors.primary,
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
                  rider,
                  style: const TextStyle(
                    color: FambaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  route,
                  style: TextStyle(
                    color: FambaColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fare,
                style: const TextStyle(
                  color: FambaColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  color: FambaColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

