import 'package:flutter/material.dart';
import 'package:bus_app/features/bus_routes/presentation/pages/bus_line_details_page.dart';

class StopDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> stop;
  final ScrollController scrollController;
  final Set<String> displayedLines;
  final Function(String) onToggleLine;
  final Color Function(String) getLineColor;

  const StopDetailsSheet({
    super.key,
    required this.stop,
    required this.scrollController,
    required this.displayedLines,
    required this.onToggleLine,
    required this.getLineColor,
  });

  @override
  Widget build(BuildContext context) {
    final lines = stop['lines'] as List<dynamic>;
    final ids = <String>{};
    final uniqueLines = lines.where((l) => ids.add(l['line_id'].toString())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                stop['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: uniqueLines.length,
            itemBuilder: (context, index) {
              final line = uniqueLines[index];
              final lineId = line['line_id'];
              final bool isVisible = displayedLines.contains(lineId);

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getLineColor(lineId).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: getLineColor(lineId),
                  ),
                ),
                title: Text(
                  line['route_name'] ?? 'Ligne $lineId',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('ID: $lineId'),
                trailing: IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                    color: isVisible ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () => onToggleLine(lineId),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusLineDetailsPage(
                        lineData: Map<String, dynamic>.from(line),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
