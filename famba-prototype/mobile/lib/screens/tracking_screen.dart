import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../models/job.dart';
import '../widgets/sos_button.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String jobId = "";
  Job? job;
  Timer? timer;

  @override
  void didChangeDependencies() {
    // Accept either a String jobId or a Map with jobId
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      jobId = arg;
    } else if (arg is Map && arg['jobId'] is String) {
      jobId = arg['jobId'];
    }

    if (jobId.isNotEmpty) {
      _poll();
      timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    }

    super.didChangeDependencies();
  }

  Future<void> _poll() async {
    try {
      final j = Job.fromJson(await Api.getJob(jobId));
      if (!mounted) return;
      setState(() => job = j);
      if (j.status == "complete") timer?.cancel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tracking error: $e')));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (jobId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Track Ride")),
        body: const Center(child: Text("No job id provided.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Trip $jobId")),
      body: job == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map,
                                      size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Map View",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (job!.driver != null)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.navigation,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      const SizedBox(width: 4),
                                      const Text("Tracking",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Status: ${job!.status}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (job!.driver != null) ...[
                      Row(
                        children: [
                          Text(
                            "Driver: ${job!.driver!['name']}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "★${job!.driver!['rating']}",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        avatar: Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 18),
                        label: const Text('Helmet check ✓'),
                        backgroundColor: Colors.green.shade50,
                        side: BorderSide(color: Colors.green.shade300),
                      ),
                    ],
                    const Spacer(),
                    if (job!.status != "complete") ...[
                      SosButton(jobId: jobId),
                      const SizedBox(height: 16),
                    ],
                    if (job!.status == "complete")
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.popUntil(
                              context, ModalRoute.withName('/home')),
                          child: const Text("Done"),
                        ),
                      ),
                  ]),
            ),
    );
  }
}
