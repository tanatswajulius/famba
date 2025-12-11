import 'package:flutter/material.dart';
import '../main.dart';
import '../core/api.dart';

class CancelRideSheet extends StatefulWidget {
  final String jobId;
  final VoidCallback onCancelled;

  const CancelRideSheet({
    super.key,
    required this.jobId,
    required this.onCancelled,
  });

  static Future<bool?> show(BuildContext context, String jobId, VoidCallback onCancelled) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CancelRideSheet(jobId: jobId, onCancelled: onCancelled),
    );
  }

  @override
  State<CancelRideSheet> createState() => _CancelRideSheetState();
}

class _CancelRideSheetState extends State<CancelRideSheet> {
  String? _selectedReason;
  bool _isLoading = false;

  final _reasons = [
    {"id": "wait_time", "label": "Wait time too long", "icon": Icons.timer_off_rounded},
    {"id": "changed_plans", "label": "Changed my plans", "icon": Icons.event_busy_rounded},
    {"id": "wrong_location", "label": "Wrong pickup location", "icon": Icons.wrong_location_rounded},
    {"id": "found_other", "label": "Found another ride", "icon": Icons.two_wheeler_rounded},
    {"id": "driver_asked", "label": "Driver asked to cancel", "icon": Icons.person_off_rounded},
    {"id": "other", "label": "Other reason", "icon": Icons.help_outline_rounded},
  ];

  Future<void> _cancelRide() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select a reason"),
          backgroundColor: FambaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Api.cancelJob(jobId: widget.jobId, reason: _selectedReason!);
      
      if (!mounted) return;
      
      widget.onCancelled();
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Ride cancelled"),
          backgroundColor: FambaColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to cancel: $e"),
          backgroundColor: FambaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FambaColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cancel_rounded, color: FambaColors.error, size: 24),
              ),
              const SizedBox(width: 14),
              const Text(
                "Cancel ride?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: FambaColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Please tell us why you're cancelling",
            style: TextStyle(
              fontSize: 14,
              color: FambaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Reasons list
          ...(_reasons.map((reason) => _buildReasonTile(reason))),
          
          const SizedBox(height: 20),
          
          // Warning
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FambaColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: FambaColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Frequent cancellations may affect your account status",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Keep ride"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _cancelRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FambaColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Cancel ride"),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildReasonTile(Map<String, dynamic> reason) {
    final isSelected = _selectedReason == reason['id'];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedReason = reason['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? FambaColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? FambaColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              reason['icon'] as IconData,
              color: isSelected ? FambaColors.primary : FambaColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason['label'] as String,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? FambaColors.primary : FambaColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: FambaColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

