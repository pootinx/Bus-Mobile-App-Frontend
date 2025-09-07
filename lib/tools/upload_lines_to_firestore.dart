import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Call this once before importing to reduce memory pressure during big writes.
void configureFirestoreForBulkImport() {
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
}

/// Public API
Future<void> importLinesToFirestore({
  required String assetPath,                 // e.g. 'assets/casa.json'
  String collectionName = 'casablanca',     // Firestore collection
  int batchSize = 450,                       // <= 500 Firestore limit
  void Function(int done, int total)? onProgress,
  bool merge = true,                         // safe re-runs
}) async {
  try {
    // 1) Load JSON string from assets
    final jsonString = await rootBundle.loadString(assetPath);

    // 2) Parse on a background isolate
    final parsed = await compute<String, Map<String, dynamic>>(
      _parseJson,
      jsonString,
    );

    // 3) Extract lines from the known structure
    final linesMap = (parsed['lines']?['city'] as Map?)?.cast<String, dynamic>();
    if (linesMap == null || linesMap.isEmpty) {
      throw StateError('JSON does not contain lines.city');
    }

    final entries = linesMap.entries.toList(growable: false);
    final total = entries.length;
    int done = 0;

    final db = FirebaseFirestore.instance;
    final col = db.collection(collectionName);

    // 4) Chunk into batches and write
    for (var i = 0; i < entries.length; i += batchSize) {
      final chunk = entries.sublist(i, min(i + batchSize, entries.length));

      await _commitWithRetries(() async {
        final batch = db.batch();
        for (final e in chunk) {
          final docId = _safeId(e.key); // deterministic ID from the JSON key
          final ref = col.doc(docId);

          // Ensure value is a Map<String, dynamic>
          final data = (e.value is Map) ? Map<String, dynamic>.from(e.value) : {'value': e.value};

          // Optional: stamp server time if missing
          data.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());

          if (merge) {
            batch.set(ref, data, SetOptions(merge: true));
          } else {
            batch.set(ref, data);
          }
        }
        await batch.commit();
      });

      done += chunk.length;
      onProgress?.call(done, total);
      if (kDebugMode) {
        print('Batch committed: $done / $total');
      }
    }

    if (kDebugMode) {
      print('✅ Import finished: $total documents written to "$collectionName".');
    }
  } catch (e, st) {
    if (kDebugMode) {
      print('❌ Import error: $e');
      print(st);
    }
    rethrow;
  }
}

/// Parse JSON in a background isolate
Map<String, dynamic> _parseJson(String jsonString) => json.decode(jsonString) as Map<String, dynamic>;

/// Deterministic, Firestore-safe doc ID from a key
String _safeId(String s) {
  // Remove spaces, slashes, and control chars, keep it readable
  final cleaned = s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return cleaned.isEmpty ? 'doc_${DateTime.now().millisecondsSinceEpoch}' : cleaned;
}

/// Commit wrapper with retries and backoff for transient Firestore errors
Future<T> _commitWithRetries<T>(Future<T> Function() op,
    {int maxRetries = 5, Duration initialDelay = const Duration(milliseconds: 400)}) async {
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    try {
      return await op();
    } on FirebaseException catch (e) {
      final retryable = {
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'resource-exhausted',
        'unavailable',
        'internal'
      }.contains(e.code);
      if (!retryable || attempt >= maxRetries) rethrow;

      if (kDebugMode) {
        print('⚠️ Retryable Firestore error (${e.code}). Retrying in ${delay.inMilliseconds} ms...');
      }
      await Future.delayed(delay);
      delay *= 2; // exponential backoff
      attempt++;
    }
  }
}
