import 'package:flutter/material.dart';

class TimelineStep {
  final Widget icon;
  final Widget detail;
  final String? time; // Optional time field for timeline display

  /// Walking step
  TimelineStep.walk({this.time, String? distance})
      : icon = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_walk, size: 16, color: Colors.black45),
              SizedBox(width: 4),
              Text(
                'À pied',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        detail = ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(Icons.directions_walk, color: Colors.grey.shade600),
          title: const Text('À pied'),
          subtitle: distance != null ? Text(distance) : null,
        );

  /// Bus or transit step
  TimelineStep.bus({
    required String? time, // nullable from source
    required String line,
    required String from,
    required String to,
    required int stops,
    required Color color,
  })  : time = time ?? '', // safe fallback
        icon = Chip(
          label: Text(
            line,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        detail = ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(Icons.directions_bus, color: color),
          title: Text(
            'Ligne $line',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$from → $to ($stops arrêts)'),
          trailing: Text(
            time ?? '', // avoid null error
            style: const TextStyle(color: Colors.grey),
          ),
        );
}
