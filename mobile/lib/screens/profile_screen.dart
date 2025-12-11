import 'package:flutter/material.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController(text: "Rider");
  final _phoneController = TextEditingController(text: "+263 77 123 4567");
  final _emailController = TextEditingController(text: "rider@example.com");
  
  bool _quietRide = false;
  bool _acPreferred = true;
  bool _helmetProvided = true;
  bool _notifications = true;
  bool _promoNotifications = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text("Profile & Settings"),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              "Save",
              style: TextStyle(
                color: FambaColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [FambaColors.primary, FambaColors.primaryDark],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        "R",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: FambaColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Personal Info Section
            _sectionHeader("Personal Information"),
            const SizedBox(height: 12),
            _inputField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _phoneController,
              label: "Phone Number",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _emailController,
              label: "Email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),

            // Ride Preferences Section
            _sectionHeader("Ride Preferences"),
            const SizedBox(height: 12),
            _preferenceToggle(
              title: "Quiet ride",
              subtitle: "Prefer minimal conversation",
              icon: Icons.volume_off_rounded,
              value: _quietRide,
              onChanged: (v) => setState(() => _quietRide = v),
            ),
            _preferenceToggle(
              title: "AC preferred",
              subtitle: "Request air conditioning when available",
              icon: Icons.ac_unit_rounded,
              value: _acPreferred,
              onChanged: (v) => setState(() => _acPreferred = v),
            ),
            _preferenceToggle(
              title: "Helmet provided",
              subtitle: "Driver provides passenger helmet",
              icon: Icons.sports_motorsports_rounded,
              value: _helmetProvided,
              onChanged: (v) => setState(() => _helmetProvided = v),
            ),
            const SizedBox(height: 24),

            // Notifications Section
            _sectionHeader("Notifications"),
            const SizedBox(height: 12),
            _preferenceToggle(
              title: "Ride updates",
              subtitle: "Get notified about ride status",
              icon: Icons.notifications_outlined,
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
            ),
            _preferenceToggle(
              title: "Promos & offers",
              subtitle: "Receive discount notifications",
              icon: Icons.local_offer_outlined,
              value: _promoNotifications,
              onChanged: (v) => setState(() => _promoNotifications = v),
            ),
            const SizedBox(height: 24),

            // Quick Links
            _sectionHeader("More"),
            const SizedBox(height: 12),
            _menuItem(
              title: "Saved places",
              icon: Icons.bookmark_outline_rounded,
              onTap: () => Navigator.pushNamed(context, '/saved-places'),
            ),
            _menuItem(
              title: "Trip history",
              icon: Icons.history_rounded,
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            _menuItem(
              title: "Payment methods",
              icon: Icons.credit_card_rounded,
              onTap: () => Navigator.pushNamed(context, '/wallet'),
            ),
            _menuItem(
              title: "Help & Support",
              icon: Icons.help_outline_rounded,
              onTap: () {},
            ),
            _menuItem(
              title: "About Famba",
              icon: Icons.info_outline_rounded,
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: FambaColors.error,
                  side: BorderSide(color: FambaColors.error.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Sign out",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: FambaColors.textPrimary,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: FambaColors.primary, size: 22),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _preferenceToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FambaColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: FambaColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FambaColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: FambaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: FambaColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FambaColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: FambaColors.textPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: FambaColors.textPrimary,
                ),
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

  void _saveProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Profile saved!"),
        backgroundColor: FambaColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

