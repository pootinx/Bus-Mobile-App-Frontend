
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GooglePlacesService {
  // Using the key name you have in your .env file
  final String _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'no-key';

  String _generateSessionToken() {
    return '${DateTime.now().millisecondsSinceEpoch}';
  }

  // The function will now return a more friendly list of maps
  Future<List<Map<String, String>>> getAutocomplete(String input) async {
    if (_apiKey == 'no-key') {
      throw Exception('API Key not found. Make sure you have GOOGLE_MAPS_API_KEY in your .env file');
    }
    final sessionToken = _generateSessionToken();
    final String url = 'https://places.googleapis.com/v1/places:autocomplete';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
      body: json.encode({
        'input': input,
        'sessionToken': sessionToken,
      }),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body['suggestions'] == null) {
        return [];
      }
      
      // Reshape the complex response from Google into a simple list
      // that the UI can easily handle.
      return (body['suggestions'] as List).map<Map<String, String>>((suggestion) {
        final prediction = suggestion['placePrediction'];
        return {
          'description': prediction['text']['text'],
          'place_id': prediction['placeId'],
        };
      }).toList();

    } else {
      throw Exception('Failed to load autocomplete suggestions: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    if (_apiKey == 'no-key') {
      throw Exception('API Key not found. Make sure you have GOOGLE_MAPS_API_KEY in your .env file');
    }
    // No changes needed here, but the placeId coming in should now be correct.
    final String url = 'https://places.googleapis.com/v1/places/$placeId?fields=location';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      if (kDebugMode) {
        print('Failed to load place details. Status code: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print('Response body: ${response.body}');
      }
      throw Exception('Failed to load place details: ${response.body}');
    }
  }
}
