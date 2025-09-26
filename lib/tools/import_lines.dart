import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> importLinesToFirestore1() async {
  final jsonString = await rootBundle.loadString('assets/casa.json');
  final Map<String, dynamic> jsonData = json.decode(jsonString);

  final linesCollection = FirebaseFirestore.instance.collection('casablanca');

  for (var entry in jsonData.entries) {
    final lineId = entry.key;
    final lineData = entry.value;

    await linesCollection.doc(lineId).set(lineData);
  }

  if (kDebugMode) {
    print('✅ Lignes importées avec succès dans Firestore.');
  }
}
