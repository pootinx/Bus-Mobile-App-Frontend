import 'package:bus_app/models/route_frbase.dart';
import 'package:bus_app/models/route_map_firestore.dart';
import 'package:flutter/material.dart';
import 'helpers.dart';

class TripCard extends StatelessWidget {
  final FirestoreRouteResultV1 route;
  final Map<String, dynamic>? trip;

  const TripCard({super.key, required this.route, required this.trip});

  Widget _infoPill(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color ?? Colors.blue,
        ),
      ),
    );
  }

  String convertTimeToHourMins(String time) {
    final parts = time.split(':');
    if (parts.length != 3) return time;
    return '${parts[0]}:${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (trip == null) return const SizedBox.shrink();

    final duration = calculerDureeParcourue(
      trip?['startTime'] ?? '00:00:00',
      trip?['endTime'] ?? '00:00:00',
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final departure = convertTimeToHourMins(trip?['startTime']);
    final arrival = convertTimeToHourMins(trip?['endTime']);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteMapScreen.fromFirestore(route),
          ),
        );
      },
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🕑 Times and distance pills
              Row(
                children: [
                  const Icon(Icons.directions_bus, color: Colors.blue, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$departure → $arrival',
                      style: TextStyle(
                        fontSize: screenWidth < 360 ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _infoPill(route.busDistance),
                  const SizedBox(width: 6),
                  _infoPill(duration, color: Colors.teal),
                ],
              ),
              const SizedBox(height: 12),

              // 📍 Line name
              Text(
                'Ligne : ${route.lineName}',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
