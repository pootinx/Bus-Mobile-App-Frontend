 
class BusStop {
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  BusStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });
}
