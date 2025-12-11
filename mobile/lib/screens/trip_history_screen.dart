import 'package:flutter/material.dart';
import '../main.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  static final _trips = [
    {
      "id": "J1045",
      "date": "Today, 2:14 PM",
      "pickup": "UZ Campus Gate",
      "dropoff": "Avondale Shops",
      "fare": 3.80,
      "status": "completed",
      "driver": "Tendai",
      "rating": 5,
      "distance": "4.2 km",
      "duration": "12 min",
    },
    {
      "id": "J1038",
      "date": "Yesterday, 9:30 AM",
      "pickup": "Eastlea Shopping Centre",
      "dropoff": "UZ Campus Gate",
      "fare": 2.60,
      "status": "completed",
      "driver": "Rudo",
      "rating": 4,
      "distance": "3.1 km",
      "duration": "8 min",
    },
    {
      "id": "J1029",
      "date": "Mon, Dec 9",
      "pickup": "CBD First Street",
      "dropoff": "Borrowdale Village",
      "fare": 5.20,
      "status": "completed",
      "driver": "Kuda",
      "rating": 5,
      "distance": "7.8 km",
      "duration": "18 min",
    },
    {
      "id": "J1015",
      "date": "Sun, Dec 8",
      "pickup": "Sam Levy's Village",
      "dropoff": "Avondale Shops",
      "fare": 2.10,
      "status": "cancelled",
      "driver": null,
      "rating": null,
      "distance": "2.4 km",
      "duration": null,
    },
    {
      "id": "J1008",
      "date": "Sat, Dec 7",
      "pickup": "Westgate Shopping",
      "dropoff": "Mabelreign",
      "fare": 3.40,
      "status": "completed",
      "driver": "Nyasha",
      "rating": 5,
      "distance": "5.1 km",
      "duration": "14 min",
    },
  ];

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
        title: const Text("Trip History"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return _buildTripCard(context, trip);
        },
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Map<String, dynamic> trip) {
    final isCancelled = trip['status'] == 'cancelled';
    
    return GestureDetector(
      onTap: () {
        if (!isCancelled) {
          Navigator.pushNamed(context, '/receipt', arguments: trip);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trip['date'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: FambaColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCancelled 
                        ? FambaColors.error.withOpacity(0.1)
                        : FambaColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCancelled ? "Cancelled" : "Completed",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCancelled ? FambaColors.error : FambaColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: FambaColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 24,
                      color: Colors.grey.shade300,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: FambaColors.error,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['pickup'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: FambaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        trip['dropoff'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: FambaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "\$${(trip['fare'] as double).toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isCancelled ? FambaColors.textSecondary : FambaColors.textPrimary,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (!isCancelled && trip['rating'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < (trip['rating'] as int) 
                                ? Icons.star_rounded 
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: Colors.amber.shade500,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (!isCancelled && trip['driver'] != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FambaColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: FambaColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          (trip['driver'] as String)[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip['driver'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "${trip['distance']} • ${trip['duration']}",
                            style: TextStyle(
                              fontSize: 12,
                              color: FambaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/receipt', arguments: trip);
                      },
                      child: Text(
                        "View receipt",
                        style: TextStyle(
                          color: FambaColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isCancelled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Rebook this trip
                    Navigator.pushNamed(context, '/quote', arguments: {
                      'pickup': trip['pickup'],
                      'drop': trip['dropoff'],
                      'distanceKm': 3.0,
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Book again"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

