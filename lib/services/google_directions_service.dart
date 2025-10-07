
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleDirectionsService {
  final String _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'no-key';

  Future<Map<String, dynamic>> getBusDirections(LatLng origin, LatLng destination) async {
    if (_apiKey == 'no-key') {
      throw Exception('API Key not found in .env file');
    }

    const String baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
    final Map<String, String> params = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'transit',
      'transit_mode': 'bus',
      'alternatives': 'true',
      'departure_time': 'now',
      'key': _apiKey,
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return data;
      } else {
        throw Exception('Directions API Error: ${data["error_message"] ?? data["status"]}');
      }
    } else {
      throw Exception('Failed to load bus directions: ${response.body}');
    }
  }
}
