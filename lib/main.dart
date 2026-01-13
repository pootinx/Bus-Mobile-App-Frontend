
import 'dart:async';

import 'package:bus_app/features/authentication/services/auth_service.dart';
import 'package:bus_app/features/authentication/services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import 'firebase_options.dart';

// This function is the single source of truth for service initialization.
Future<void> initServices() async {
  // Initialize Firebase first.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Set the language code to prevent Firebase locale warnings.
    await FirebaseAuth.instance.setLanguageCode('en');
  } catch (e) {
    if (kDebugMode) {
      print('Firebase already initialized: $e');
    }
  }

  // Load environment variables.
  try {
    await dotenv.load(fileName: ".env");
    debugPrint(".env chargé avec succès");
  } catch (e) {
    debugPrint("Erreur lors du chargement de .env : $e");
  }
  
  // Put the services into memory.
  Get.put(ProfileService());
  Get.put(AuthService());
}

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    // Ensure Flutter bindings are initialized.
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize all services before running the app.
    await initServices();

    // Set up Crashlytics to catch Flutter framework errors.
    if (kReleaseMode) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    }

    // Run the app.
    runApp(const MyApp());
  }, (error, stack) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(error, stack);
      }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Bus Route Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // We start with a simple, empty container. The AuthService is responsible
      // for all navigation, so it will replace this with the correct screen
      // (LoginScreen or MainScreen) as soon as it initializes.
      home: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
