import 'package:flutter/material.dart';
import 'package:bus_app/features/bus_routes/presentation/pages/bus_line_details_page.dart';
import 'package:bus_app/core/services/google_directions_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class StopDetailsSheet extends StatefulWidget {
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
  State<StopDetailsSheet> createState() => _StopDetailsSheetState();
}

class _StopDetailsSheetState extends State<StopDetailsSheet> {
  final GoogleDirectionsService _directionsService = GoogleDirectionsService();
  final Map<String, DateTime?> _lineArrivals = {};
  final Map<String, bool> _isLoadingArrivals = {};

  @override
  void initState() {
    super.initState();
    _fetchArrivalsForAllLines();
  }

  Future<void> _fetchArrivalsForAllLines() async {
    final lines = widget.stop['lines'] as List<dynamic>;
    for (final line in lines) {
      _fetchArrivalForLine(line);
    }
  }

  Future<void> _fetchArrivalForLine(dynamic line) async {
    final lineId = line['line_id'].toString();
    if (_isLoadingArrivals[lineId] == true) return;

    setState(() {
      _isLoadingArrivals[lineId] = true;
    });

    try {
      final double lat = widget.stop['lat'];
      final double lng = widget.stop['lon'];
      
      final stops = (line['stops'] as List<dynamic>? ?? []);
      if (stops.isEmpty) return;

      final terminus = stops.last;
      final double destLat = terminus['lat']?.toDouble() ?? terminus['latitude']?.toDouble() ?? 0.0;
      final double destLng = terminus['lon']?.toDouble() ?? terminus['longitude']?.toDouble() ?? 0.0;

      final result = await _directionsService.getBusDirections(
        LatLng(lat, lng),
        LatLng(destLat, destLng),
      );

      DateTime? nextArrival;
      if (result['routes'] != null) {
        final List<DateTime> arrivalTimes = [];
        for (var route in result['routes']) {
          for (var leg in route['legs']) {
            for (var step in leg['steps']) {
              if (step['travel_mode'] == 'TRANSIT' && step['transit_details'] != null) {
                final departureTimeValue = step['transit_details']['departure_time']?['value'];
                if (departureTimeValue != null) {
                  arrivalTimes.add(DateTime.fromMillisecondsSinceEpoch(departureTimeValue * 1000));
                }
              }
            }
          }
        }
        arrivalTimes.sort();
        final now = DateTime.now();
        nextArrival = arrivalTimes.firstWhere((dt) => dt.isAfter(now), orElse: () => arrivalTimes.isNotEmpty ? arrivalTimes.first : DateTime.now());
      }

      if (mounted) {
        setState(() {
          _lineArrivals[lineId] = nextArrival;
          _isLoadingArrivals[lineId] = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching arrival for line $lineId: $e");
      if (mounted) {
        setState(() {
          _isLoadingArrivals[lineId] = false;
        });
      }
    }
  }

  String _formatRelativeTime(DateTime? arrival) {
    if (arrival == null) return "Chargement...";
    final now = DateTime.now();
    final diff = arrival.difference(now);
    final minutes = diff.inMinutes;

    if (minutes < 1) return "Imminent";
    if (minutes < 60) return "Dans $minutes min";
    final hours = diff.inHours;
    if (hours < 24) return "Dans ${hours}h ${minutes % 60}min";
    return DateFormat('HH:mm').format(arrival);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.stop['lines'] as List<dynamic>;
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
                widget.stop['name'],
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
            controller: widget.scrollController,
            itemCount: uniqueLines.length,
            itemBuilder: (context, index) {
              final line = uniqueLines[index];
              final lineId = line['line_id'].toString();
              final bool isVisible = widget.displayedLines.contains(lineId);
              final arrival = _lineArrivals[lineId];
              final isLoading = _isLoadingArrivals[lineId] ?? false;

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.getLineColor(lineId).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: widget.getLineColor(lineId),
                  ),
                ),
                title: Text(
                  line['route_name'] ?? 'Ligne $lineId',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: isLoading 
                  ? const Text('Calcul de l\'arrivée...', style: TextStyle(fontSize: 12, color: Colors.grey))
                  : Text(_formatRelativeTime(arrival), style: TextStyle(
                      color: (arrival?.difference(DateTime.now()).inMinutes ?? 99) < 10 
                        ? Colors.green 
                        : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )),
                trailing: IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                    color: isVisible ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () => widget.onToggleLine(lineId),
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
