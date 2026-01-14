
class BusStop {
  final String name;
  final double latitude;
  final double longitude;
  final String? arrivalTime;
  final String? departureTime;

  const BusStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.arrivalTime,
    this.departureTime,
  });

  factory BusStop.fromMap(Map<String, dynamic> map) {
    return BusStop(
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      arrivalTime: map['arrivalTime'],
      departureTime: map['departureTime'],
    );
  }
}
