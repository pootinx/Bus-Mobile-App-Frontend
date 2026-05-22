import 'dart:async';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:bus_app/core/services/app_init_service.dart';
import 'package:bus_app/core/services/localization_service.dart';
import 'package:bus_app/core/controllers/theme_controller.dart';
import 'package:bus_app/core/widgets/first_launch_gate.dart';
import 'package:bus_app/core/widgets/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bus_app/l10n/app_localizations.dart';
import 'package:bus_app/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    final data = message.data;
    final type = data['type'] as String?;
    if (type == 'survey') {
      final surveyId = data['surveyId'] as String?;
      if (surveyId != null && surveyId.isNotEmpty) {
        debugPrint('Background FCM: survey notification for surveyId=$surveyId');
      }
    }
  } catch (e) {
    debugPrint('Background FCM handler error: $e');
  }
}

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (kReleaseMode) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    }

    runApp(const MyApp());
  }, (error, stack) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(error, stack);
      }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _initService = AppInitService();
  late final LocalizationService _locService;
  late final ThemeController _themeController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _initService.init();
    Get.put(_initService);
    _locService = Get.find<LocalizationService>();
    _themeController = Get.find<ThemeController>();
    ever(_locService.currentLocaleObs, (_) => setState(() {}));
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const GetMaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    final isArabic = _locService.currentLocale.languageCode == 'ar';

    return GetMaterialApp(
      title: 'Bus Route Finder',
      debugShowCheckedModeBanner: false,

      theme: isArabic
          ? AppTheme.lightTheme.copyWith(
              textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
                AppTheme.lightTheme.textTheme,
              ),
            )
          : AppTheme.lightTheme,

      darkTheme: isArabic
          ? AppTheme.darkTheme.copyWith(
              textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
                AppTheme.darkTheme.textTheme,
              ),
            )
          : AppTheme.darkTheme,

      themeMode: _themeController.themeMode,

      locale: _locService.currentLocale,
      fallbackLocale: LocalizationService.fallbackLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.locales,

      home: const FirstLaunchGate(),
    );
  }
}
