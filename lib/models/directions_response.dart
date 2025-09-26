// lib/models/directions_response.dart

/// Top-level response
class DirectionsResponse {
  final List<GeocodedWaypoint> geocodedWaypoints;
  final List<DirectionsRoute> routes;
  final String status;

  DirectionsResponse({
    required this.geocodedWaypoints,
    required this.routes,
    required this.status,
  });

  factory DirectionsResponse.fromJson(Map<String, dynamic> json) {
    return DirectionsResponse(
      geocodedWaypoints: (json['geocoded_waypoints'] as List<dynamic>)
          .map((e) => GeocodedWaypoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      routes: (json['routes'] as List<dynamic>)
          .map((e) => DirectionsRoute.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'geocoded_waypoints':
            geocodedWaypoints.map((e) => e.toJson()).toList(),
        'routes': routes.map((e) => e.toJson()).toList(),
        'status': status,
      };
}

/// Renamed from `Route` to `DirectionsRoute` to avoid conflict with Flutter's Route class.
class DirectionsRoute {
  final Bounds bounds;
  final String copyrights;
  final List<Leg> legs;
  final OverviewPolyline overviewPolyline;
  final String summary;
  final List<String> warnings;
  final List<int> waypointOrder;

  DirectionsRoute({
    required this.bounds,
    required this.copyrights,
    required this.legs,
    required this.overviewPolyline,
    required this.summary,
    required this.warnings,
    required this.waypointOrder,
  });

  factory DirectionsRoute.fromJson(Map<String, dynamic> json) {
    return DirectionsRoute(
      bounds: Bounds.fromJson(json['bounds'] as Map<String, dynamic>),
      copyrights: json['copyrights'] as String,
      legs: (json['legs'] as List<dynamic>)
          .map((e) => Leg.fromJson(e as Map<String, dynamic>))
          .toList(),
      overviewPolyline:
          OverviewPolyline.fromJson(json['overview_polyline'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      warnings:
          (json['warnings'] as List<dynamic>).map((e) => e as String).toList(),
      waypointOrder:
          (json['waypoint_order'] as List<dynamic>).map((e) => e as int).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bounds': bounds.toJson(),
        'copyrights': copyrights,
        'legs': legs.map((e) => e.toJson()).toList(),
        'overview_polyline': overviewPolyline.toJson(),
        'summary': summary,
        'warnings': warnings,
        'waypoint_order': waypointOrder,
      };
}

/// Bounding box of a route
class Bounds {
  final LatLng northeast;
  final LatLng southwest;

  Bounds({
    required this.northeast,
    required this.southwest,
  });

  factory Bounds.fromJson(Map<String, dynamic> json) {
    return Bounds(
      northeast: LatLng.fromJson(json['northeast'] as Map<String, dynamic>),
      southwest: LatLng.fromJson(json['southwest'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'northeast': northeast.toJson(),
        'southwest': southwest.toJson(),
      };
}

/// Simple latitude/longitude pair
class LatLng {
  final double lat;
  final double lng;

  LatLng({
    required this.lat,
    required this.lng,
  });

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
      };
}

/// One “leg” within a route (e.g., a bus segment, walk segment, etc.)
class Leg {
  final TimeInfo arrivalTime;
  final TimeInfo departureTime;
  final DistanceInfo distance;
  final DurationInfo duration;
  final String endAddress;
  final LatLng endLocation;
  final String startAddress;
  final LatLng startLocation;
  final List<Step> steps;
  final List<dynamic> trafficSpeedEntry;
  final List<dynamic> viaWaypoint;

  Leg({
    required this.arrivalTime,
    required this.departureTime,
    required this.distance,
    required this.duration,
    required this.endAddress,
    required this.endLocation,
    required this.startAddress,
    required this.startLocation,
    required this.steps,
    required this.trafficSpeedEntry,
    required this.viaWaypoint,
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    return Leg(
      arrivalTime: TimeInfo.fromJson(json['arrival_time'] as Map<String, dynamic>),
      departureTime:
          TimeInfo.fromJson(json['departure_time'] as Map<String, dynamic>),
      distance: DistanceInfo.fromJson(json['distance'] as Map<String, dynamic>),
      duration: DurationInfo.fromJson(json['duration'] as Map<String, dynamic>),
      endAddress: json['end_address'] as String,
      endLocation: LatLng.fromJson(json['end_location'] as Map<String, dynamic>),
      startAddress: json['start_address'] as String,
      startLocation:
          LatLng.fromJson(json['start_location'] as Map<String, dynamic>),
      steps: (json['steps'] as List<dynamic>)
          .map((e) => Step.fromJson(e as Map<String, dynamic>))
          .toList(),
      trafficSpeedEntry: json['traffic_speed_entry'] as List<dynamic>,
      viaWaypoint: json['via_waypoint'] as List<dynamic>,
    );
  }

  Map<String, dynamic> toJson() => {
        'arrival_time': arrivalTime.toJson(),
        'departure_time': departureTime.toJson(),
        'distance': distance.toJson(),
        'duration': duration.toJson(),
        'end_address': endAddress,
        'end_location': endLocation.toJson(),
        'start_address': startAddress,
        'start_location': startLocation.toJson(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'traffic_speed_entry': trafficSpeedEntry,
        'via_waypoint': viaWaypoint,
      };
}

/// ArrivalTime or DepartureTime
class TimeInfo {
  final String text;
  final String timeZone;
  final int value;

  TimeInfo({
    required this.text,
    required this.timeZone,
    required this.value,
  });

  factory TimeInfo.fromJson(Map<String, dynamic> json) {
    return TimeInfo(
      text: json['text'] as String,
      timeZone: json['time_zone'] as String,
      value: json['value'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'time_zone': timeZone,
        'value': value,
      };
}

/// Distance object (e.g., “37.6 km”)
class DistanceInfo {
  final String text;
  final int value;

  DistanceInfo({
    required this.text,
    required this.value,
  });

  factory DistanceInfo.fromJson(Map<String, dynamic> json) {
    return DistanceInfo(
      text: json['text'] as String,
      value: json['value'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'value': value,
      };
}

/// Duration object (e.g., “1 hour 29 mins”)
class DurationInfo {
  final String text;
  final int value;

  DurationInfo({
    required this.text,
    required this.value,
  });

  factory DurationInfo.fromJson(Map<String, dynamic> json) {
    return DurationInfo(
      text: json['text'] as String,
      value: json['value'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'value': value,
      };
}

/// A single step inside a leg (could be transit or walking)
class Step {
  final DistanceInfo distance;
  final DurationInfo duration;
  final LatLng endLocation;
  final String htmlInstructions;
  final Polyline polyline;
  final LatLng startLocation;
  final TransitDetails? transitDetails;
  final String travelMode;
  final List<Step>? steps;

  Step({
    required this.distance,
    required this.duration,
    required this.endLocation,
    required this.htmlInstructions,
    required this.polyline,
    required this.startLocation,
    this.transitDetails,
    required this.travelMode,
    this.steps,
  });

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      distance: DistanceInfo.fromJson(json['distance'] as Map<String, dynamic>),
      duration: DurationInfo.fromJson(json['duration'] as Map<String, dynamic>),
      endLocation:
          LatLng.fromJson(json['end_location'] as Map<String, dynamic>),
      htmlInstructions: json['html_instructions'] ?? '',
      polyline: Polyline.fromJson(json['polyline'] as Map<String, dynamic>),
      startLocation:
          LatLng.fromJson(json['start_location'] as Map<String, dynamic>),
      transitDetails: json['transit_details'] != null
          ? TransitDetails.fromJson(json['transit_details'] as Map<String, dynamic>)
          : null,
      travelMode: json['travel_mode'] as String,
      steps: json['steps'] != null
          ? (json['steps'] as List<dynamic>)
              .map((e) => Step.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'distance': distance.toJson(),
      'duration': duration.toJson(),
      'end_location': endLocation.toJson(),
      'html_instructions': htmlInstructions,
      'polyline': polyline.toJson(),
      'start_location': startLocation.toJson(),
      'travel_mode': travelMode,
    };
    if (transitDetails != null) {
      data['transit_details'] = transitDetails!.toJson();
    }
    if (steps != null) {
      data['steps'] = steps!.map((e) => e.toJson()).toList();
    }
    return data;
  }
}

/// Encoded polyline points (for drawing on a map)
class Polyline {
  final String points;

  Polyline({
    required this.points,
  });

  factory Polyline.fromJson(Map<String, dynamic> json) {
    return Polyline(
      points: json['points'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points,
      };
}

/// Transit-specific details (present when travel_mode = "TRANSIT")
class TransitDetails {
  final Stop arrivalStop;
  final TimeInfo arrivalTime;
  final Stop departureStop;
  final TimeInfo departureTime;
  final String headsign;
  final Line line;
  final int numStops;

  TransitDetails({
    required this.arrivalStop,
    required this.arrivalTime,
    required this.departureStop,
    required this.departureTime,
    required this.headsign,
    required this.line,
    required this.numStops,
  });

  factory TransitDetails.fromJson(Map<String, dynamic> json) {
    return TransitDetails(
      arrivalStop: Stop.fromJson(json['arrival_stop'] as Map<String, dynamic>),
      arrivalTime:
          TimeInfo.fromJson(json['arrival_time'] as Map<String, dynamic>),
      departureStop:
          Stop.fromJson(json['departure_stop'] as Map<String, dynamic>),
      departureTime:
          TimeInfo.fromJson(json['departure_time'] as Map<String, dynamic>),
      headsign: json['headsign'] as String,
      line: Line.fromJson(json['line'] as Map<String, dynamic>),
      numStops: json['num_stops'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'arrival_stop': arrivalStop.toJson(),
        'arrival_time': arrivalTime.toJson(),
        'departure_stop': departureStop.toJson(),
        'departure_time': departureTime.toJson(),
        'headsign': headsign,
        'line': line.toJson(),
        'num_stops': numStops,
      };
}

/// A bus/train stop (with name and coordinates)
class Stop {
  final LatLng location;
  final String name;

  Stop({
    required this.location,
    required this.name,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      location: LatLng.fromJson(json['location'] as Map<String, dynamic>),
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'name': name,
      };
}

/// Transit line details (e.g., bus line color, name, vehicle type)
class Line {
  final List<Agency> agencies;
  final String color;
  final String name;
  final String shortName;
  final String textColor;
  final Vehicle vehicle;

  Line({
    required this.agencies,
    required this.color,
    required this.name,
    required this.shortName,
    required this.textColor,
    required this.vehicle,
  });

  factory Line.fromJson(Map<String, dynamic> json) {
    return Line(
      agencies: (json['agencies'] as List<dynamic>)
          .map((e) => Agency.fromJson(e as Map<String, dynamic>))
          .toList(),
      color: json['color'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String,
      textColor: json['text_color'] as String,
      vehicle: Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'agencies': agencies.map((e) => e.toJson()).toList(),
        'color': color,
        'name': name,
        'short_name': shortName,
        'text_color': textColor,
        'vehicle': vehicle.toJson(),
      };
}

/// Agency operating the transit line (e.g., bus operator)
class Agency {
  final String name;
  final String phone;
  final String url;

  Agency({
    required this.name,
    required this.phone,
    required this.url,
  });

  factory Agency.fromJson(Map<String, dynamic> json) {
    return Agency(
      name: json['name'] as String,
      phone: json['phone'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'url': url,
      };
}

/// Vehicle icon and type (e.g., BUS)
class Vehicle {
  final String icon;
  final String name;
  final String type;

  Vehicle({
    required this.icon,
    required this.name,
    required this.type,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      icon: json['icon'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'icon': icon,
        'name': name,
        'type': type,
      };
}

/// “overview_polyline” at the route level
class OverviewPolyline {
  final String points;

  OverviewPolyline({
    required this.points,
  });

  factory OverviewPolyline.fromJson(Map<String, dynamic> json) {
    return OverviewPolyline(
      points: json['points'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points,
      };
}

/// Geocoded waypoint entry (at the top of the JSON)
class GeocodedWaypoint {
  final String geocoderStatus;
  final String placeId;
  final List<String> types;

  GeocodedWaypoint({
    required this.geocoderStatus,
    required this.placeId,
    required this.types,
  });

  factory GeocodedWaypoint.fromJson(Map<String, dynamic> json) {
    return GeocodedWaypoint(
      geocoderStatus: json['geocoder_status'] as String,
      placeId: json['place_id'] as String,
      types:
          (json['types'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'geocoder_status': geocoderStatus,
        'place_id': placeId,
        'types': types,
      };
}
