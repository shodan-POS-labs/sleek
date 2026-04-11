import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Initialize Crashlytics only if supported (Crashlytics not supported on web)
      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      }
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
    }

    // Enable Firestore offline persistence
    try {
      if (kIsWeb) {
        // For Web, persistence is enabled differently or handled by SDK
        await FirebaseFirestore.instance.enablePersistence();
      } else {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      }
    } catch (e) {
      debugPrint("Firestore persistence setup failed: $e");
    }

    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ));
    }

    final authService = AuthService();
    
    String initialRoute = '/login';
    try {
      final isFirstTime = await authService.isFirstTimeOpening();
      final isPinSet = await authService.isPinSetForDevice();
      final hasBiometricsSession = await authService.hasValidSessionForBiometrics();

      if (isFirstTime) {
        initialRoute = '/shop-setup';
      } else if (isPinSet || hasBiometricsSession) {
        initialRoute = '/login';
      } else {
        initialRoute = '/login?mode=email';
      }
    } catch (e) {
      debugPrint("Initial route determination failed: $e");
    }

    runApp(SleekApp(initialRoute: initialRoute));
  }, (error, stack) {
    debugPrint("Uncaught error: $error");
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class SleekApp extends StatelessWidget {
  final String initialRoute;
  const SleekApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sleek POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.getRouter(initialRoute),
    );
  }
}
