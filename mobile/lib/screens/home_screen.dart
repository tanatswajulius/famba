import 'package:flutter/material.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _pickup = TextEditingController(text: "UZ Campus Gate");
  final _drop = TextEditingController(text: "First Street Mall");
  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();
  
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  final _recents = const [
    {"name": "Avondale Shops", "address": "Avondale, Harare", "icon": Icons.shopping_bag_outlined},
    {"name": "Causeway", "address": "Central Business District", "icon": Icons.business_outlined},
    {"name": "Eastlea Shopping Centre", "address": "Eastlea, Harare", "icon": Icons.storefront_outlined},
  ];

  final _quickAccess = const [
    {"label": "Home", "icon": Icons.home_rounded},
    {"label": "Work", "icon": Icons.work_rounded},
    {"label": "Gym", "icon": Icons.fitness_center_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pickup.dispose();
    _drop.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _swap() {
    final tmp = _pickup.text;
    setState(() {
      _pickup.text = _drop.text;
      _drop.text = tmp;
    });
  }

  void _setDestination(String name) {
    setState(() => _drop.text = name);
  }

  void _goToQuote() {
    if (_pickup.text.trim().isEmpty || _drop.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Enter both pickup and dropoff locations"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FambaColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Good ${_getGreeting()}",
                            style: TextStyle(
                              fontSize: 14,
                              color: FambaColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Where to?",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: FambaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _iconButton(
                            icon: Icons.notifications_none_rounded,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/wallet'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: FambaColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 18,
                                    color: FambaColors.primaryDark,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "\$12.00",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: FambaColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Location Input Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Location dots
                              Column(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: FambaColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 2,
                                    height: 30,
                                    color: Colors.grey.shade300,
                                  ),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: FambaColors.error,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              // Input fields
                              Expanded(
                                child: Column(
                                  children: [
                                    _locationInput(
                                      controller: _pickup,
                                      focusNode: _pickupFocus,
                                      hint: "Pickup location",
                                      onTap: () {},
                                    ),
                                    Divider(
                                      height: 16,
                                      color: Colors.grey.shade100,
                                    ),
                                    _locationInput(
                                      controller: _drop,
                                      focusNode: _dropFocus,
                                      hint: "Where to?",
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Swap button
                              _iconButton(
                                icon: Icons.swap_vert_rounded,
                                onTap: _swap,
                                backgroundColor: FambaColors.background,
                              ),
                            ],
                          ),
                        ),
                        // Quick access chips
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickAccess
                                .map((item) => _quickChip(
                                      icon: item['icon'] as IconData,
                                      label: item['label'] as String,
                                      onTap: () => _setDestination(item['label'] as String),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // CTA Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _goToQuote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FambaColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 22),
                          SizedBox(width: 10),
                          Text(
                            "Find a ride",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Promo Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          FambaColors.primary,
                          FambaColors.primaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.offline_bolt_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Works Offline",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Queue rides without data. Stay connected.",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Quick Actions Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      _actionTile(
                        icon: Icons.schedule_rounded,
                        label: "Schedule",
                        onTap: () => Navigator.pushNamed(context, '/schedule', arguments: {
                          'pickup': _pickup.text,
                          'drop': _drop.text,
                        }),
                      ),
                      const SizedBox(width: 12),
                      _actionTile(
                        icon: Icons.confirmation_number_rounded,
                        label: "Promo",
                        onTap: () => Navigator.pushNamed(context, '/promo'),
                      ),
                      const SizedBox(width: 12),
                      _actionTile(
                        icon: Icons.history_rounded,
                        label: "History",
                        onTap: () => Navigator.pushNamed(context, '/history'),
                      ),
                      const SizedBox(width: 12),
                      _actionTile(
                        icon: Icons.person_rounded,
                        label: "Profile",
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Places Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent places",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/saved-places'),
                        child: Text(
                          "See all",
                          style: TextStyle(
                            color: FambaColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Places List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final place = _recents[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _recentPlaceCard(
                        icon: place['icon'] as IconData,
                        name: place['name'] as String,
                        address: place['address'] as String,
                        onTap: () => _setDestination(place['name'] as String),
                      ),
                    );
                  },
                  childCount: _recents.length,
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "morning";
    if (hour < 17) return "afternoon";
    return "evening";
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: backgroundColor == null
              ? Border.all(color: Colors.grey.shade200)
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: FambaColors.textPrimary,
        ),
      ),
    );
  }

  Widget _locationInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onTap: onTap,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: FambaColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
    );
  }

  Widget _quickChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FambaColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: FambaColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FambaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentPlaceCard({
    required IconData icon,
    required String name,
    required String address,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
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
              child: Icon(icon, size: 22, color: FambaColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: FambaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 13,
                      color: FambaColors.textSecondary,
                    ),
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

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: FambaColors.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FambaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
