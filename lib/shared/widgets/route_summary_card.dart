
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Time and Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _getRelativeTimeString(leg.departureTime.value),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      leg.arrivalTime.text,
                      style: const TextStyle(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Middle Row: Mode Icons
              _buildFlowTimeline(leg.steps),
              const SizedBox(height: 16),
              // Bottom Row: Distance and Description
              Row(
                children: [
                  const Icon(Icons.directions_walk, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    leg.distance.text,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    "Tous les détais",
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppTheme.accentBlue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowTimeline(List<Step> steps) {
    List<Widget> children = [];
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.travelMode == 'WALKING') {
        children.add(const Icon(Icons.directions_walk, size: 20, color: Colors.grey));
      } else {
        final line = step.transitDetails?.line;
        final color = line?.color != null ? _colorFromHex(line!.color!) : AppTheme.primaryBlue;
        children.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              line?.shortName ?? line?.name ?? 'Bus',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
      if (i < steps.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}
