import 'package:bus_app/models/directions_response.dart'
    show DirectionsRoute, Leg, Step;
import 'package:bus_app/models/route_frbase.dart';
import 'package:bus_app/screens/route_cart_screen.dart';
import 'package:bus_app/screens/route_map_screen.dart';
import 'package:flutter/material.dart' hide Step;

class RouteSummaryCard extends StatefulWidget {
  final DirectionsRoute route;

  const RouteSummaryCard({super.key, required this.route});

  @override
  State<RouteSummaryCard> createState() => _RouteSummaryCardState();
}

class _RouteSummaryCardState extends State<RouteSummaryCard> with SingleTickerProviderStateMixin {
  bool showDetails = false;

  Color _colorFromHex(String hexColor) {
    final buffer = StringBuffer();
    if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
    buffer.write(hexColor.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Widget _iconForStep(Step s) {
    if (s.travelMode == 'TRANSIT' && s.transitDetails != null) {
      final hex = s.transitDetails!.line.color;
      return Icon(Icons.directions_bus, size: 20, color: _colorFromHex(hex));
    } else if (s.travelMode == 'WALKING') {
      return const Icon(Icons.directions_walk, size: 20, color: Colors.deepPurple);
    }
    return const Icon(Icons.directions, size: 20, color: Colors.deepPurple);
  }

  Widget _infoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Leg firstLeg = widget.route.legs.first;
    final steps = firstLeg.steps;
    final screenWidth = MediaQuery.of(context).size.width;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CartScreen(route: widget.route)),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive header
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.train, size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 6),
                      Text(
                        '${firstLeg.departureTime.text} → ${firstLeg.arrivalTime.text}',
                        style: TextStyle(
                          fontSize: screenWidth < 360 ? 13 : 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  _infoPill(firstLeg.distance.text),
                  _infoPill(firstLeg.duration.text),
                ],
              ),

              const SizedBox(height: 10),

              // Step icons
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconForStep(steps[i]),
                        const SizedBox(width: 4),
                        if (steps[i].travelMode == 'TRANSIT' && steps[i].transitDetails != null)
                          Builder(builder: (context) {
                            final transit = steps[i].transitDetails!;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorFromHex(transit.line.color),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                transit.line.shortName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                    if (i != steps.length - 1)
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Details toggle
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: Colors.deepPurple,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () => setState(() => showDetails = !showDetails),
                  icon: Icon(showDetails ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text(showDetails ? 'Masquer les détails' : 'Détails'),
                ),
              ),

              // Expanded details view
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: showDetails
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: steps.map((step) {
                          final isTransit = step.travelMode == 'TRANSIT' && step.transitDetails != null;
                          final icon = isTransit
                              ? Icon(Icons.directions_bus, size: 18, color: _colorFromHex(step.transitDetails!.line.color))
                              : const Icon(Icons.directions_walk, size: 18, color: Colors.deepPurple);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8, top: 2),
                                  child: icon,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (isTransit)
                                        Builder(builder: (context) {
                                          final transit = step.transitDetails!;
                                          return Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _colorFromHex(transit.line.color),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  transit.line.shortName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Bus vers ${transit.headsign}',
                                                  style: TextStyle(
                                                    fontSize: screenWidth < 360 ? 12 : 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      if (!isTransit)
                                        Text(
                                          step.htmlInstructions.replaceAll(RegExp(r'<[^>]*>'), ''),
                                          style: TextStyle(
                                            fontSize: screenWidth < 360 ? 12 : 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






class RouteSummaryCardV1 extends StatefulWidget {
  final FirestoreRouteResultV1 result;

  const RouteSummaryCardV1({super.key, required this.result});

  @override
  State<RouteSummaryCardV1> createState() => _RouteSummaryCardV1State();
}

class _RouteSummaryCardV1State extends State<RouteSummaryCardV1> with SingleTickerProviderStateMixin {
  bool showDetails = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final screenWidth = MediaQuery.of(context).size.width;

    final startTime = result.startTime.length >= 5 ? result.startTime.substring(0, 5) : result.startTime;
    final endTime = result.endTime.length >= 5 ? result.endTime.substring(0, 5) : result.endTime;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteMapScreenV1(route: result),
          ),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Time + Distance
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_bus, size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 6),
                      Text(
                        "${startTime} → ${endTime}",
                        // "${adjustTime(startTime, -result.distanceToStart)} → ${adjustTime(endTime, result.distanceToEnd)}",
                        style: TextStyle(
                          fontSize: screenWidth < 360 ? 13 : 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  _infoPill("${((double.parse(result.busDistance)*1000 + result.walkingTimeToEnd + result.walkingTimeToStart)/1000).toStringAsFixed(2)} km"),
                ],
              ),
      
              const SizedBox(height: 10),
      
              // Route Line Info
              Row(
                children: [
                  if (result.walkingTimeToStart != 0.0) ...[
                    const Icon(Icons.directions_walk, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(result.colorValue),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.lineName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (result.walkingTimeToEnd != 0.0) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 16),
                    const SizedBox(width: 8),
                    const Icon(Icons.directions_walk, color: Colors.blue, size: 20),
                  ],
                ],
              ),
      
              // const SizedBox(height: 10),
      
              // Walking times
              if (result.walkingTimeToStart != null || result.walkingTimeToEnd != null)
                // Row(
                //   children: [
                //     if (result.walkingTimeToStart != null)
                //       _infoPill("🚶 Départ: ${result.walkingTimeToStart} min"),
                //     const SizedBox(width: 6),
                //     if (result.walkingTimeToEnd != null)
                //       _infoPill("🚶 Arrivée: ${result.walkingTimeToEnd} min"),
                //   ],
                // ),
      
              const SizedBox(height: 6),
      
              // Toggle Details
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: Colors.deepPurple,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () => setState(() => showDetails = !showDetails),
                  icon: Icon(showDetails ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text(showDetails ? 'Masquer les détails' : 'Détails'),
                ),
              ),
      
              AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: showDetails
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (result.stops.isNotEmpty && result.walkingTimeToStart!=0.0)
                          _buildDetailRow(
                            Icons.directions_walk,
                            "Marcher jusqu'à ${'${result.startAddress} ~ ${result.walkingTimeToStart} min' ?? 'départ'}",
                          ),
                        _buildDetailRow(
                          Icons.directions_bus,
                          "Bus ligne ${result.lineName} vers ${result.endAddress}",
                        ),
                        if (result.stops.length > 1 && result.walkingTimeToEnd!=0.0)
                          _buildDetailRow(
                            Icons.directions_walk,
                            "Marcher vers ${'${result.endAddress} ~ ${result.walkingTimeToEnd} min' ?? 'arrivée'}",
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
      
            ],
          ),
        ),
      ),
    );
  }

  String adjustTime(String timeStr, double offsetMinutes) {
  // Parse "HH:mm" into DateTime (with dummy date)
  final now = DateTime.now();
  final parts = timeStr.split(':');
  final time = DateTime(now.year, now.month, now.day,
      int.parse(parts[0]), int.parse(parts[1]));

  // Apply offset in minutes
  final adjusted = time.add(Duration(minutes: offsetMinutes.round()));

  // Format back to "HH:mm"
  final hour = adjusted.hour.toString().padLeft(2, '0');
  final minute = adjusted.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
  Widget _infoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.deepPurple,
        ),
      ),
    );
  }
}
