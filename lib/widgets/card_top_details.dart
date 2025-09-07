import 'package:flutter/material.dart';

class CardTopDetails extends StatelessWidget {
  final String startAddress;
  final String departureTime;
  final String endAddress;
  final String arrivalTime;
  final String duration;
  final String distance; // New: Route distance

  const CardTopDetails({
    super.key,
    required this.startAddress,
    required this.departureTime,
    required this.endAddress,
    required this.arrivalTime,
    required this.duration,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Start Address + Departure Time
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.place,
                  color: Colors.deepPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    startAddress,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  departureTime,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duration & Distance row: Clock icon + Duration text, then Distance icon + Distance text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.deepPurple,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.alt_route,
                  color: Colors.deepPurple,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  distance,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // // Divider icon: arrow down
            // Center(
            //   child: Icon(
            //     Icons.arrow_downward_rounded,
            //     color: Colors.deepPurple.shade300,
            //     size: 24,
            //   ),
            // ),
            // const SizedBox(height: 12),

            // Bottom row: End Address + Arrival Time
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.flag,
                  color: Colors.deepPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    endAddress,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  arrivalTime,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}