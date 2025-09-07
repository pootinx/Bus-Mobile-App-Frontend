// import 'dart:convert';
// import 'package:http/http.dart' as http;
//
// Future<List<String>> fetchVilles(String query) async {
//   final response = await http.get(
//     Uri.parse("https://wft-geo-db.p.rapidapi.com/v1/geo/cities?namePrefix=$query&limit=10"),
//     headers: {
//       "X-RapidAPI-Key": "AIzaSyCkBWwBnO_lbyYX2Jq88l-niW1Qj0-WtgM", // ⬅️ Remplace ici par ta vraie clé RapidAPI
//       "X-RapidAPI-Host": "wft-geo-db.p.rapidapi.com"
//     },
//   );
//
//   if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//     return List<String>.from(data['data'].map((v) => v['city']));
//   } else {
//     print("Erreur : ${response.statusCode}");
//     return [];
//   }
// }
