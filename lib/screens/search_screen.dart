// import 'package:flutter/material.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
//
// class SearchResultScreen extends StatefulWidget {
//   const SearchResultScreen({super.key});
//
//   @override
//   State<SearchResultScreen> createState() => _SearchResultScreenState();
// }
//
// class _SearchResultScreenState extends State<SearchResultScreen> {
//   final TextEditingController fromController = TextEditingController();
//   final TextEditingController toController = TextEditingController();
//
//   Future<List<String>> fetchVilles(String query) async {
//     final response = await http.get(
//       Uri.parse(
//           'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&types=(cities)&key=AIzaSyCkBWwBnO_lbyYX2Jq88l-niW1Qj0-WtgM'),
//     );
//
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       return List<String>.from(
//           data['predictions'].map((item) => item['description']));
//     } else {
//       throw Exception('Erreur lors du chargement des villes');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             children: [
//               // Champ DEPART dynamique
//               TypeAheadFormField<String>(
//                 textFieldConfiguration: TextFieldConfiguration(
//                   controller: fromController,
//                   decoration: InputDecoration(
//                     hintText: 'Place Bab el Had, Rabat',
//                     prefixIcon: const Icon(Icons.radio_button_unchecked),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                 ),
//                 suggestionsCallback: (pattern) async {
//                   return await fetchVilles(pattern);
//                 },
//                 itemBuilder: (context, suggestion) =>
//                     ListTile(title: Text(suggestion)),
//                 onSuggestionSelected: (suggestion) {
//                   fromController.text = suggestion;
//                 },
//               ),
//
//               const SizedBox(height: 12),
//
//               // Champ DESTINATION dynamique
//               TypeAheadFormField<String>(
//                 textFieldConfiguration: TextFieldConfiguration(
//                   controller: toController,
//                   decoration: InputDecoration(
//                     hintText: 'Témara',
//                     prefixIcon: const Icon(Icons.location_on_outlined),
//                     suffixIcon: const Icon(Icons.swap_vert),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                 ),
//                 suggestionsCallback: (pattern) async {
//                   return await fetchVilles(pattern);
//                 },
//                 itemBuilder: (context, suggestion) =>
//                     ListTile(title: Text(suggestion)),
//                 onSuggestionSelected: (suggestion) {
//                   toController.text = suggestion;
//                 },
//               ),
//
//               const SizedBox(height: 16),
//
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFFE3E3),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Row(
//                   children: [
//                     Icon(Icons.warning_amber, color: Colors.red),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         "Nous ne disposons pas des horaires les plus récents pour cette zone.",
//                         style: TextStyle(color: Colors.red),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 16),
//
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: const [
//                   Text(
//                     "📤 Envoyer l’itinéraire vers votre téléphone",
//                     style: TextStyle(color: Colors.blue),
//                   ),
//                   Text(
//                     "🗺️ Mode carte",
//                     style: TextStyle(color: Colors.blue),
//                   ),
//                 ],
//               ),
//
//               const SizedBox(height: 12),
//
//               Expanded(
//                 child: ListView(
//                   children: const [
//                     RouteCard(
//                       startTime: '13:07',
//                       endTime: '14:21',
//                       duration: '1 h 14 min',
//                       walkTime: '5 min à pied',
//                       lineInfo: 'À 13:17 de Av Hassan II Bab El Hed',
//                       busDuration: '28 min - Toutes les 15 minutes',
//                     ),
//                     RouteCard(
//                       startTime: '13:10',
//                       endTime: '14:21',
//                       duration: '1 h 11 min',
//                       walkTime: '8 min à pied',
//                       lineInfo: 'Ligne 12 • HMYA - YMSR',
//                       busDuration: '',
//                     ),
//                     RouteCard(
//                       startTime: '13:12',
//                       endTime: '14:34',
//                       duration: '1 h 22 min',
//                       walkTime: '3 min à pied',
//                       lineInfo: 'Ligne 6 • Station Centrale',
//                       busDuration: '',
//                     ),
//                     RouteCard(
//                       startTime: '13:20',
//                       endTime: '14:25',
//                       duration: '1 h 5 min',
//                       walkTime: '7 min à pied',
//                       lineInfo: 'Ligne 18 • Terminus Sud',
//                       busDuration: '',
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class RouteCard extends StatelessWidget {
//   final String startTime;
//   final String endTime;
//   final String duration;
//   final String walkTime;
//   final String lineInfo;
//   final String busDuration;
//
//   const RouteCard({
//     super.key,
//     required this.startTime,
//     required this.endTime,
//     required this.duration,
//     required this.walkTime,
//     required this.lineInfo,
//     required this.busDuration,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       child: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 const Icon(Icons.directions_bus, size: 20),
//                 const SizedBox(width: 8),
//                 Text(
//                   '$startTime – $endTime',
//                   style: const TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const Spacer(),
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     duration,
//                     style: const TextStyle(color: Colors.blue),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 6),
//             Text(walkTime),
//             Text(lineInfo),
//             if (busDuration.isNotEmpty) Text(busDuration),
//           ],
//         ),
//       ),
//     );
//   }
// }
