import 'package:flutter/material.dart';

class RouteStepItem extends StatelessWidget {
  final Map<String, dynamic> step;
  final bool isFirst;
  final bool isLast;
  final Color color;

  const RouteStepItem({
    super.key,
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final instruction = step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), '');
    final duration = step['duration']['text'];
    final mode = step['travel_mode'];
    
    IconData iconData;
    if (mode == 'WALKING') {
      iconData = Icons.directions_walk;
    } else if (mode == 'TRANSIT') {
      iconData = Icons.directions_bus;
    } else {
      iconData = Icons.location_on;
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline indicator
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: isFirst ? Colors.transparent : Colors.grey.shade300,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(iconData, color: color, size: 20),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (mode == 'TRANSIT') ...[
                        const SizedBox(width: 12),
                        _buildLineBadge(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineBadge() {
    final transitDetails = step['transit_details'];
    if (transitDetails == null) return const SizedBox.shrink();
    final line = transitDetails['line'];
    final lineName = line['short_name'] ?? line['name'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        lineName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
