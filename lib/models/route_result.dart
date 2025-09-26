import 'bus_stop.dart';
import 'firestore_route_result.dart';

class RouteResult {
  final FirestoreRouteResult route;
  final BusStop? nearestDepartureStop;
  final BusStop? nearestArrivalStop;
  final double? walkingDistanceToStart;
  final double? walkingDistanceFromEnd;

  RouteResult({
    required this.route,
    this.nearestDepartureStop,
    this.nearestArrivalStop,
    this.walkingDistanceToStart,
    this.walkingDistanceFromEnd,
  });
}
