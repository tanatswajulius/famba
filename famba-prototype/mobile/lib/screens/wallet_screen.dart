import 'package:flutter/material.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wallet & Famba Card")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Balance: \$12.00"),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.greenAccent.withOpacity(.15)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text("QR / Card Approval", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text("Tap to approve via USSD (simulated). Works when data is off.")
            ]),
          ),
          const Spacer(),
          ElevatedButton(onPressed: ()=> ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Approved (simulated)"))),
              child: const Text("Approve"))
        ]),
      ),
    );
  }
}
