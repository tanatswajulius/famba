import 'package:flutter/material.dart';
import '../main.dart';

class RideRequestScreen extends StatelessWidget {
  const RideRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Request')),
      body: const Center(
        child: Text('Ride Request Details', style: TextStyle(color: FambaColors.textPrimary)),
      ),
    );
  }
}

