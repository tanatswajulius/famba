import 'package:flutter/material.dart';
import '../core/api.dart';

class SosButton extends StatelessWidget {
  final String? jobId;

  const SosButton({super.key, this.jobId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleSOS(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_rounded, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'SOS Emergency',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSOS(BuildContext context) async {
    bool notPassenger = false;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.warning_rounded,
                          color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        "Emergency options",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _sosTile(
                    icon: Icons.phone_in_talk,
                    label: "Call safety hotline",
                    subtitle: "Connect to our 24/7 line",
                    color: Colors.red.shade700,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                  _sosTile(
                    icon: Icons.link,
                    label: "Share trip link",
                    subtitle: "Send status to trusted contact",
                    color: Colors.orange.shade700,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                  _sosTile(
                    icon: Icons.support_agent,
                    label: "Message support",
                    subtitle: "Chat with support about safety",
                    color: Colors.blue.shade700,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                  const Divider(height: 20),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: notPassenger,
                    onChanged: (v) => setState(() => notPassenger = v),
                    activeColor: Colors.red.shade700,
                    title: const Text(
                      "I'm not the passenger",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                        "Alert driver and support to verify the rider."),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text("Send emergency alert"),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await Api.reportIssue(jobId: jobId, issueType: 'emergency');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency alert sent. Help is on the way.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send alert: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _sosTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

