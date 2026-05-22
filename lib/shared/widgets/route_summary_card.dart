
import 'package:bus_app/shared/models/directions_response.dart' show DirectionsRoute, Leg, Step;
import 'package:bus_app/features/map/presentation/pages/route_details_page.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart' hide Step;

class RouteSummaryCard extends StatelessWidget {
  final DirectionsRoute route;

  const RouteSummaryCard({
    super.key,
    required this.route,
  });

  Color _colorFromHex(String hexColor) {
    final buffer = StringBuffer();
    if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
    buffer.write(hexColor.replaceFirst('#', ''));
    if (buffer.length == 8) {
      return Color(int.parse(buffer.toString(), radix: 16));
    }
    return Colors.blue;
  }

  String _getRelativeTimeString(int timestampSeconds) {
    if (timestampSeconds == 0) return '';
    final now = DateTime.now().toUtc();
    var departure = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000, isUtc: true);
    var difference = departure.difference(now);

    if (difference.isNegative) {
      // If it's negative, we assume it's for the next day at the same time
      // or we just show the countdown until that specific timestamp in the future.
      // Usually, if the API gives a past timestamp, the user wants to see the next occurrence.
      departure = departure.add(const Duration(days: 1));
      difference = departure.difference(now);
    }

    if (difference.inMinutes < 1) {
      return 'Imminent';
    }

    if (difference.inMinutes < 60) {
      return 'Dans ${difference.inMinutes} min';
    }

    final hours = difference.inHours;
    final mins = difference.inMinutes % 60;
    if (mins == 0) {
      return 'Dans $hours h';
    }
    return 'Dans $hours h $mins min';
  }

  @override
  Widget build(BuildContext context) {
    final Leg leg = route.legs.first;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RouteDetailsPage(routeData: route.toJson()),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Relative Time and Arrival Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getRelativeTimeString(leg.departureTime.value),
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      leg.arrivalTime.text,
                      style: const TextStyle(
                        color: Color(0xFFFF9800),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Timeline Visualization
              _buildTimeline(leg.steps),
              
              const SizedBox(height: 16),
              
              // Bottom Row: Distance and Details Link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_walk, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        leg.distance.text,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Tous les détails >",
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<Step> steps) {
    List<Widget> widgets = [];
    
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.travelMode == 'WALKING') {
        widgets.add(const Icon(Icons.directions_walk, size: 18, color: Colors.grey));
      } else if (step.travelMode == 'TRANSIT') {
        final color = _colorFromHex(step.transitDetails?.line.color ?? '#1E3A8A');
        final lineName = step.transitDetails?.line.shortName ?? step.transitDetails?.line.name ?? '';
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              lineName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }

      if (i < steps.length - 1) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right, size: 14, color: Colors.grey),
        ));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }
}
