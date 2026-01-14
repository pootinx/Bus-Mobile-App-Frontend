// lpackage:bus_app/core/services/route_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bus_app/shared/models/directions_response.dart';

class RouteService {
  final String apiKey;

  RouteService({required this.apiKey});

  Future<DirectionsResponse> fetchBusRoutes({
    required String origin,
    required String destination,
  }) async {
    const baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

    final params = {
      'origin': origin,
      'destination': destination,
      'mode': 'transit',
      'transit_mode': 'bus',
      'alternatives': 'true',
      'key': apiKey,
      'language': 'fr',
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    if (kDebugMode) {
      print("Requesting URL: $uri");
    }

    final response = await http.get(uri);
    final Map<String, dynamic> decodedJson = json.decode(response.body);

    final apiStatus = decodedJson['status'] as String? ?? 'UNKNOWN';
    if (response.statusCode == 200 && apiStatus == 'OK') {
      final directionsResponse = DirectionsResponse.fromJson(decodedJson);
      return directionsResponse;
    } else {
      final errorMessage = decodedJson['error_message'] as String? ?? '';
      throw Exception('Directions API Error: [$apiStatus] $errorMessage');
    }
  }
}
