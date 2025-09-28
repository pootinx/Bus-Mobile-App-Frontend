import 'package:bus_app/screens/add_bus_screen.dart';
import 'package:bus_app/screens/search_firebase/search.dart';
import 'package:bus_app/tools/upload_lines_to_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/bus_lines_screen.dart';
import 'screens/bus_line_details_screen.dart';
import 'screens/stations_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialiser Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If Firebase was already initialized, this will catch the duplicate error
    if (kDebugMode) {
      print('Firebase already initialized: $e');
    }
  }

  // 🌍 Charger les variables d’environnement depuis .env
  try {
    await dotenv.load(fileName: ".env");
    debugPrint(".env chargé avec succès");
  } catch (e) {
    debugPrint("Erreur lors du chargement de .env : $e");
  }

  // ✅ Exécute cette ligne UNE SEULE FOIS pour importer les lignes Firestore
  // await importLinesToFirestore(); // ← décommente uniquement en cas de besoin ponctuel
  // _runImport();

  runApp(const MyApp());
}

Future<void> _runImport() async {
  try {
    await importLinesToFirestore(
      assetPath: 'assets/casa.json',
      collectionName: 'casablanca',
      batchSize: 450,
    );
  } catch (e) {
    // Show a snack bar or dialog with the error
    if (kDebugMode) print('Import failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Route Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/search': (context) => const SearchRouteScreenV1(),
        // '/search': (context) => const SearchRouteScreen(),
        '/lines': (context) => const BusLinesScreen(),
        '/stations': (context) => const StationsScreen(),
         '/line_details': (context) => const BusLineDetailsScreen(),
        '/add_bus': (context) => const AddBusScreen(), 
      },
    );
  }
}
