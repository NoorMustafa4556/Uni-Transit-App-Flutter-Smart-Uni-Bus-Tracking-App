import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'view_models/theme_provider.dart';
import 'core/routes/app_routes.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // ⚡ SPEED OPT 1: Force portrait mode to avoid unnecessary rebuilds
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // ⚡ SPEED OPT 2: Set system UI overlay style for consistent rendering
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // ⚡ SPEED OPT 3: Run Firebase + SharedPrefs in parallel (not sequential)
    debugPrint("Initializing Firebase + SharedPreferences + Notifications in parallel...");
    final results = await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      SharedPreferences.getInstance(),
      NotificationService.init(),
    ]);
    final sharedPreferences = results[1] as SharedPreferences;
    debugPrint("All initializations complete");

    // ⚡ SPEED OPT 4: Enable Firebase RTDB disk persistence & keep 'buses' synced
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.ref('buses').keepSynced(true);

    // 🧠 MEMORY OPT: Limit Firebase RTDB cache to 10MB (default is 10MB anyway but explicit is safe)
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);

    // 🧠 MEMORY OPT: Limit image cache to prevent OOM on low-end devices
    PaintingBinding.instance.imageCache.maximumSize = 50; // max 50 images
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB max

    // ⚡ SPEED OPT 5: Pre-cache the Poppins font to avoid first-frame jank
    GoogleFonts.config.allowRuntimeFetching = true;

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint("CRITICAL ERROR during initialization: $e");
    debugPrint("Stack trace: $stack");
    // Run a minimal app to show the error on screen if possible
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "App failed to start:\n\n$e",
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚡ SPEED OPT 6: Precache asset images on first build
    _precacheImages(context);

    return MaterialApp(
      title: 'UniTransit',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.getRoutes(),
      // ⚡ SPEED OPT 7: Smooth page transitions
      builder: (context, child) {
        // Prevent text scaling from breaking layouts
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }

  void _precacheImages(BuildContext context) {
    // Precache all asset images so they load instantly when needed
    precacheImage(const AssetImage('assets/images/IUBLogo.png'), context);
    precacheImage(const AssetImage('assets/images/tracking.png'), context);
    precacheImage(const AssetImage('assets/images/schedule.png'), context);
    precacheImage(const AssetImage('assets/images/safety.png'), context);
  }
}
