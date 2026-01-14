class FirestoreTrip {
  final String tripId;
  final String startAddress;
  final String endAddress;
  final String startTime;
  final String endTime;
  final int order;
  final String lineId;

  FirestoreTrip({
    required this.tripId,
    required this.startAddress,
    required this.endAddress,
    required this.startTime,
    required this.endTime,
    required this.order,
    required this.lineId,
  });

  factory FirestoreTrip.fromMap(Map<String, dynamic> data) {
    return FirestoreTrip(
      tripId: data['trip_id'] ?? '',
      startAddress: data['startAddress'] ?? '',
      endAddress: data['endAddress'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      order: data['order'] ?? 0,
      lineId: data['line_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trip_id': tripId,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'startTime': startTime,
      'endTime': endTime,
      'order': order,
      'line_id': lineId,
    };
  }
}
