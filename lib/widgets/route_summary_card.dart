import 'package:bus_app/models/directions_response.dart'
    show DirectionsRoute, Leg, Step;
import 'package:bus_app/screens/route_cart_screen.dart';
import 'package:flutter/material.dart' hide Step;

class RouteSummaryCard extends StatefulWidget {
  final DirectionsRoute route;

  const RouteSummaryCard({
    super.key,
    required this.route,
  });

  @override
  State<RouteSummaryCard> createState() => _RouteSummaryCardState();
}

class _RouteSummaryCardState extends State<RouteSummaryCard> {
  bool _showDetails = false;

  Color _colorFromHex(String hexColor) {
    final buffer = StringBuffer();
    if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
    buffer.write(hexColor.replaceFirst('#', ''));
    if (buffer.length == 8) {
      return Color(int.parse(buffer.toString(), radix: 16));
    }
    return Colors.grey;
  }

  Widget _distancePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Leg firstLeg = widget.route.legs.first;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CartScreen(route: widget.route)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5), // Light purple background
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopRow(firstLeg),
            const SizedBox(height: 16),
            _buildRouteLine(firstLeg.steps),
            const SizedBox(height: 8),
            _buildDetailsToggle(),
            _buildDetailsSection(firstLeg.steps),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(Leg leg) {
    return Row(
      children: [
        const Icon(Icons.directions_bus, color: Colors.purple, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${leg.departureTime.text} - ${leg.arrivalTime.text} (${leg.duration.text})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _distancePill(leg.distance.text),
      ],
    );
  }

  Widget _buildRouteLine(List<Step> steps) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isEven) {
          final step = steps[index ~/ 2];
          return _buildStepWidget(step);
        } else {
          return const Icon(Icons.arrow_forward_ios,
              color: Colors.grey, size: 16);
        }
      }),
    );
  }

  Widget _buildStepWidget(Step step) {
    if (step.travelMode == 'TRANSIT' && step.transitDetails != null) {
      final transit = step.transitDetails!;
      final busColor = transit.line.color != null
          ? _colorFromHex(transit.line.color)
          : Colors.orange;

      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: busColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          transit.line.shortName ?? transit.line.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    } else {
      return const Icon(Icons.directions_walk, color: Colors.black54, size: 24);
    }
  }

  Widget _buildDetailsToggle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Colors.blue.shade700,
          textStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        onPressed: () => setState(() => _showDetails = !_showDetails),
        icon: Icon(
          _showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          size: 22,
        ),
        label: Text(_showDetails ? 'Masquer' : 'Détails'),
      ),
    );
  }

  Widget _buildDetailsSection(List<Step> steps) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      child: _showDetails
          ? Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      step.htmlInstructions
                          .replaceAll(RegExp(r'<[^>]*>'), ' ')
                          .trim(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
