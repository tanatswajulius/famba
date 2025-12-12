import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/driver_state.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Profile header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: FambaColors.primary,
                      child: Text(
                        (state.driverName ?? 'D')[0],
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.driverName ?? 'Driver',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: FambaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${state.rating} rating',
                          style: TextStyle(
                            color: FambaColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Stats
              Row(
                children: [
                  Expanded(child: _statBox('156', 'Total Trips')),
                  const SizedBox(width: 12),
                  Expanded(child: _statBox('\$320', 'This Month')),
                  const SizedBox(width: 12),
                  Expanded(child: _statBox('98%', 'Acceptance')),
                ],
              ),
              const SizedBox(height: 24),

              // Menu items
              _menuItem(Icons.motorcycle, 'Vehicle Details', () {}),
              _menuItem(Icons.description, 'Documents', () {}),
              _menuItem(Icons.account_balance_wallet, 'Payment Methods', () {}),
              _menuItem(Icons.bar_chart, 'Performance', () {}),
              _menuItem(Icons.help_outline, 'Help & Support', () {}),
              _menuItem(Icons.info_outline, 'About Famba', () {}),
              const SizedBox(height: 24),

              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    state.logout();
                    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                  },
                  icon: const Icon(Icons.logout, color: FambaColors.error),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FambaColors.error,
                    side: const BorderSide(color: FambaColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: FambaColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: FambaColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: FambaColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FambaColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: FambaColors.primary),
        title: Text(
          title,
          style: const TextStyle(color: FambaColors.textPrimary),
        ),
        trailing: const Icon(Icons.chevron_right, color: FambaColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

