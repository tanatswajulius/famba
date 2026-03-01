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
                        _miniStat('${(state.todayTrips * 0.45).toStringAsFixed(0)}h', 'Online'),
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
                  Expanded(child: _statCard('Total', '\$${(state.todayEarnings * 5).toStringAsFixed(2)}', Icons.attach_money)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Trips', '${state.todayTrips * 5}', Icons.motorcycle)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('Hours', '${(state.todayTrips * 2.3).toStringAsFixed(1)}h', Icons.timer)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Tips', '\$${(state.todayEarnings * 0.08).toStringAsFixed(2)}', Icons.favorite)),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Recent Trips',
                style: TextStyle(
                  color: FambaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (state.completedTrips.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No trips yet. Go online to start earning!',
                      style: TextStyle(color: FambaColors.textSecondary),
                    ),
                  ),
                )
              else
                ...state.completedTrips.reversed.take(10).map((trip) =>
                  _tripTile(
                    trip['rider'] ?? 'Rider',
                    '${trip['pickup']} → ${trip['dropoff']}',
                    '\$${(trip['fare'] as num).toStringAsFixed(2)}',
                    trip['time'] ?? '',
                  ),
                ),
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

