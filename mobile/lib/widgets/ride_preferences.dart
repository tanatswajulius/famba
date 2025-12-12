import 'package:flutter/material.dart';
import '../main.dart';

class RidePreferences {
  bool ac;
  bool quietRide;
  bool petFriendly;
  bool helmetProvided;

  RidePreferences({
    this.ac = false,
    this.quietRide = false,
    this.petFriendly = false,
    this.helmetProvided = true,
  });

  Map<String, dynamic> toJson() => {
        'ac': ac,
        'quiet_ride': quietRide,
        'pet_friendly': petFriendly,
        'helmet_provided': helmetProvided,
      };

  RidePreferences copyWith({
    bool? ac,
    bool? quietRide,
    bool? petFriendly,
    bool? helmetProvided,
  }) {
    return RidePreferences(
      ac: ac ?? this.ac,
      quietRide: quietRide ?? this.quietRide,
      petFriendly: petFriendly ?? this.petFriendly,
      helmetProvided: helmetProvided ?? this.helmetProvided,
    );
  }
}

class RidePreferencesSheet extends StatefulWidget {
  final RidePreferences preferences;
  final Function(RidePreferences) onChanged;

  const RidePreferencesSheet({
    super.key,
    required this.preferences,
    required this.onChanged,
  });

  @override
  State<RidePreferencesSheet> createState() => _RidePreferencesSheetState();
}

class _RidePreferencesSheetState extends State<RidePreferencesSheet> {
  late RidePreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.preferences;
  }

  void _update(RidePreferences newPrefs) {
    setState(() => _prefs = newPrefs);
    widget.onChanged(newPrefs);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Ride Preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize your ride experience',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          _prefToggle(
            icon: Icons.ac_unit_rounded,
            title: 'Air Conditioning',
            subtitle: 'Request AC if available (car rides)',
            value: _prefs.ac,
            onChanged: (v) => _update(_prefs.copyWith(ac: v)),
          ),
          _prefToggle(
            icon: Icons.volume_off_rounded,
            title: 'Quiet Ride',
            subtitle: 'Minimal conversation preferred',
            value: _prefs.quietRide,
            onChanged: (v) => _update(_prefs.copyWith(quietRide: v)),
          ),
          _prefToggle(
            icon: Icons.pets_rounded,
            title: 'Pet Friendly',
            subtitle: 'Traveling with a pet',
            value: _prefs.petFriendly,
            onChanged: (v) => _update(_prefs.copyWith(petFriendly: v)),
          ),
          _prefToggle(
            icon: Icons.sports_motorsports_rounded,
            title: 'Helmet Provided',
            subtitle: 'Request helmet from driver',
            value: _prefs.helmetProvided,
            onChanged: (v) => _update(_prefs.copyWith(helmetProvided: v)),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prefToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value
            ? FambaColors.primary.withOpacity(0.1)
            : FambaColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? FambaColors.primary.withOpacity(0.3)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? FambaColors.primary.withOpacity(0.2)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? FambaColors.primary : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value
                        ? FambaColors.textPrimary
                        : Colors.grey.shade700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: FambaColors.primary,
          ),
        ],
      ),
    );
  }
}

// Compact preferences chips for display
class PreferencesChips extends StatelessWidget {
  final RidePreferences preferences;
  final VoidCallback? onTap;

  const PreferencesChips({
    super.key,
    required this.preferences,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = <Widget>[];

    if (preferences.ac) {
      active.add(_chip(Icons.ac_unit, 'AC'));
    }
    if (preferences.quietRide) {
      active.add(_chip(Icons.volume_off, 'Quiet'));
    }
    if (preferences.petFriendly) {
      active.add(_chip(Icons.pets, 'Pet'));
    }
    if (preferences.helmetProvided) {
      active.add(_chip(Icons.sports_motorsports, 'Helmet'));
    }

    if (active.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FambaColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Add preferences',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: active,
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FambaColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FambaColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FambaColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

