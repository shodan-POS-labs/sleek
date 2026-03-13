import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final authService = AuthService();
  final isFirstTime = await authService.isFirstTimeOpening();
  final isPinSet = await authService.isPinSetForDevice();
  final hasBiometricsSession = await authService.hasValidSessionForBiometrics();

  String initialRoute;
  if (isFirstTime) {
    initialRoute = '/shop-setup';
  } else if (isPinSet || hasBiometricsSession) {
    initialRoute = '/login';
  } else {
    initialRoute = '/login?mode=email';
  }

  runApp(SleekApp(initialRoute: initialRoute));
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
