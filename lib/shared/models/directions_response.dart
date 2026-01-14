class DirectionsResponse {
  final String status;
  final List<DirectionsRoute> routes;

  DirectionsResponse({required this.status, required this.routes});

  factory DirectionsResponse.fromJson(Map<String, dynamic> json) {
    return DirectionsResponse(
      status: json['status'],
      routes: List<DirectionsRoute>.from(
          json['routes'].map((x) => DirectionsRoute.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'routes': routes.map((x) => x.toJson()).toList(),
  };
}

class DirectionsRoute {
  final Bounds bounds;
  final String copyrights;
  final List<Leg> legs;
  final OverviewPolyline overviewPolyline;
  final String summary;
  final List<String> warnings;
  final List<dynamic> waypointOrder;

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
      bounds: Bounds.fromJson(json['bounds']),
      copyrights: json['copyrights'],
      legs: List<Leg>.from(json['legs'].map((x) => Leg.fromJson(x))),
      overviewPolyline: OverviewPolyline.fromJson(json['overview_polyline']),
      summary: json['summary'],
      warnings: List<String>.from(json['warnings'].map((x) => x)),
      waypointOrder: List<dynamic>.from(json['waypoint_order'].map((x) => x)),
    );
  }

  Map<String, dynamic> toJson() => {
    'bounds': bounds.toJson(),
    'copyrights': copyrights,
    'legs': legs.map((x) => x.toJson()).toList(),
    'overview_polyline': overviewPolyline.toJson(),
    'summary': summary,
    'warnings': warnings,
    'waypoint_order': waypointOrder,
  };
}

class Bounds {
  final Coords northeast;
  final Coords southwest;

  Bounds({required this.northeast, required this.southwest});

  factory Bounds.fromJson(Map<String, dynamic> json) {
    return Bounds(
      northeast: Coords.fromJson(json['northeast']),
      southwest: Coords.fromJson(json['southwest']),
    );
  }

  Map<String, dynamic> toJson() => {
    'northeast': northeast.toJson(),
    'southwest': southwest.toJson(),
  };
}

class Coords {
  final double lat;
  final double lng;

  Coords({required this.lat, required this.lng});

  factory Coords.fromJson(Map<String, dynamic> json) {
    return Coords(
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
  };
}

class Leg {
  final TimeValue arrivalTime;
  final TimeValue departureTime;
  final Distance distance;
  final Duration duration;
  final String endAddress;
  final Coords endLocation;
  final String startAddress;
  final Coords startLocation;
  final List<Step> steps;

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
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    return Leg(
      arrivalTime: TimeValue.fromJson(json['arrival_time'] ?? {}),
      departureTime: TimeValue.fromJson(json['departure_time'] ?? {}),
      distance: Distance.fromJson(json['distance'] ?? {}),
      duration: Duration.fromJson(json['duration'] ?? {}),
      endAddress: json['end_address'] ?? '',
      endLocation: Coords.fromJson(json['end_location'] ?? {}),
      startAddress: json['start_address'] ?? '',
      startLocation: Coords.fromJson(json['start_location'] ?? {}),
      steps: List<Step>.from((json['steps'] ?? []).map((x) => Step.fromJson(x))),
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
    'steps': steps.map((x) => x.toJson()).toList(),
  };
}

class TimeValue {
  final String text;
  final String timeZone;
  final int value;

  TimeValue({required this.text, required this.timeZone, required this.value});

  factory TimeValue.fromJson(Map<String, dynamic> json) {
    return TimeValue(
      text: json['text'] ?? '',
      timeZone: json['time_zone'] ?? '',
      value: json['value'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'time_zone': timeZone,
    'value': value,
  };
}

class Distance {
  final String text;
  final int value;

  Distance({required this.text, required this.value});

  factory Distance.fromJson(Map<String, dynamic> json) {
    return Distance(
      text: json['text'] ?? '',
      value: json['value'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'value': value,
  };
}

class Duration {
  final String text;
  final int value;

  Duration({required this.text, required this.value});

  factory Duration.fromJson(Map<String, dynamic> json) {
    return Duration(
      text: json['text'] ?? '',
      value: json['value'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'value': value,
  };
}

class Step {
  final Distance distance;
  final Duration duration;
  final Coords endLocation;
  final String htmlInstructions;
  final Polyline polyline;
  final Coords startLocation;
  final String travelMode;
  final TransitDetails? transitDetails;

  Step({
    required this.distance,
    required this.duration,
    required this.endLocation,
    required this.htmlInstructions,
    required this.polyline,
    required this.startLocation,
    required this.travelMode,
    this.transitDetails,
  });

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      distance: Distance.fromJson(json['distance'] ?? {}),
      duration: Duration.fromJson(json['duration'] ?? {}),
      endLocation: Coords.fromJson(json['end_location'] ?? {}),
      htmlInstructions: json['html_instructions'] ?? '',
      polyline: Polyline.fromJson(json['polyline'] ?? {}),
      startLocation: Coords.fromJson(json['start_location'] ?? {}),
      travelMode: json['travel_mode'] ?? '',
      transitDetails: json['transit_details'] != null
          ? TransitDetails.fromJson(json['transit_details'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'distance': distance.toJson(),
    'duration': duration.toJson(),
    'end_location': endLocation.toJson(),
    'html_instructions': htmlInstructions,
    'polyline': polyline.toJson(),
    'start_location': startLocation.toJson(),
    'travel_mode': travelMode,
    'transit_details': transitDetails?.toJson(),
  };
}

class Polyline {
  final String points;

  Polyline({required this.points});

  factory Polyline.fromJson(Map<String, dynamic> json) {
    return Polyline(
      points: json['points'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'points': points,
  };
}

class TransitDetails {
  final Stop arrivalStop;
  final Stop departureStop;
  final TimeValue arrivalTime;
  final TimeValue departureTime;
  final String headsign;
  final int numStops;
  final Line line;

  TransitDetails({
    required this.arrivalStop,
    required this.departureStop,
    required this.arrivalTime,
    required this.departureTime,
    required this.headsign,
    required this.numStops,
    required this.line,
  });

  factory TransitDetails.fromJson(Map<String, dynamic> json) {
    return TransitDetails(
      arrivalStop: Stop.fromJson(json['arrival_stop'] ?? {}),
      departureStop: Stop.fromJson(json['departure_stop'] ?? {}),
      arrivalTime: TimeValue.fromJson(json['arrival_time'] ?? {}),
      departureTime: TimeValue.fromJson(json['departure_time'] ?? {}),
      headsign: json['headsign'] ?? '',
      numStops: json['num_stops'] ?? 0,
      line: Line.fromJson(json['line'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'arrival_stop': arrivalStop.toJson(),
    'departure_stop': departureStop.toJson(),
    'arrival_time': arrivalTime.toJson(),
    'departure_time': departureTime.toJson(),
    'headsign': headsign,
    'num_stops': numStops,
    'line': line.toJson(),
  };
}

class Stop {
  final String name;
  final Coords location;

  Stop({required this.name, required this.location});

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      name: json['name'] ?? '',
      location: Coords.fromJson(json['location'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': location.toJson(),
  };
}

class Line {
  final List<Vehicle> agencies;
  final String name;
  final String? shortName;
  final String color;
  final Vehicle vehicle;

  Line({
    required this.agencies,
    required this.name,
    this.shortName,
    required this.color,
    required this.vehicle,
  });

  factory Line.fromJson(Map<String, dynamic> json) {
    return Line(
      agencies:
          List<Vehicle>.from((json['agencies'] ?? []).map((x) => Vehicle.fromJson(x))),
      name: json['name'] ?? '',
      shortName: json['short_name'],
      color: json['color'] ?? '#ffffff',
      vehicle: Vehicle.fromJson(json['vehicle'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'agencies': agencies.map((x) => x.toJson()).toList(),
    'name': name,
    'short_name': shortName,
    'color': color,
    'vehicle': vehicle.toJson(),
  };
}

class Vehicle {
  final String name;
  final String type;
  final String? icon;
  final String? url;

  Vehicle({required this.name, required this.type, this.icon, this.url});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      icon: json['icon'],
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'icon': icon,
    'url': url,
  };
}

class OverviewPolyline {
  final String points;

  OverviewPolyline({required this.points});

  factory OverviewPolyline.fromJson(Map<String, dynamic> json) {
    return OverviewPolyline(points: json['points'] ?? '');
  }

  Map<String, dynamic> toJson() => {
    'points': points,
  };
}
