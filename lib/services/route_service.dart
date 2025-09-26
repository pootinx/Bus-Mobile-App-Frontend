// lib/services/route_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bus_app/models/directions_response.dart';

class RouteService {
  final String apiKey;

  RouteService({required this.apiKey});

  /// Fetches all possible bus routes (transit_mode=bus) between [origin] and [destination].
  /// Returns a fully‐parsed [DirectionsResponse], which contains:
  ///  • geocodedWaypoints
  ///  • a List of Route objects
  ///  • status, etc.
  ///
  // ignore: unintended_html_in_doc_comment
  /// To extract only the List<Route>, you can do:
  ///   final directions = await fetchBusRoutes(origin: "...", destination: "...");
  ///   final allRoutes = directions.routes;
  Future<DirectionsResponse> fetchBusRoutes({
    required String origin,
    required String destination,
  }) async {
    final originEncoded = Uri.encodeComponent(origin);
    final destinationEncoded = Uri.encodeComponent(destination);

    if (kDebugMode) {
      print("$origin $destination");
      print("------ $originEncoded $destinationEncoded");
    }
    

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin'
      '&destination=$destination'
      '&mode=transit'
      '&transit_mode=bus'
      '&alternatives=true'
      '&key=$apiKey'
      '&language=fr',
    );

    // 3. Send HTTP GET request
    final response = await http.get(url);

    // 4. Decode the JSON body (regardless of statusCode, we want to inspect 'status' field)
    final Map<String, dynamic> decodedJson = json.decode(response.body) as Map<String, dynamic>;

    // 5. Check for a successful API-level status
    //    Google Directions returns 200 + "status": "OK" when everything is fine.
    final apiStatus = decodedJson['status'] as String? ?? 'UNKNOWN';
    if (response.statusCode == 200 && apiStatus == 'OK') {
      // 6. Parse entire JSON into DirectionsResponse
      final directionsResponse = DirectionsResponse.fromJson(decodedJson);
      return directionsResponse;
    } else {
      // 7. If not OK, throw an exception with details
      final errorStatus = apiStatus;
      final errorMessage = decodedJson['error_message'] as String? ?? '';
      throw Exception('Directions API Error: [$errorStatus] $errorMessage');
    }
  }
}
