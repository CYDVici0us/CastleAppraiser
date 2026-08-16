import 'dart:async';
import 'dart:io';

import 'package:btcc/src/app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Orientation only — never gate the first frame on Firebase/assets.
  // Firebase.initializeApp can hang indefinitely on some Samsung devices;
  // AssetHelper atlas decode is heavy (~200MB+) and used to block splash.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (kReleaseMode && !kIsWeb && !Platform.isWindows) {
      // Best-effort; Firebase may still be initializing.
      unawaited(FirebaseCrashlytics.instance.recordFlutterError(details));
    }
  };

  unawaited(_initFirebaseAndCrashlytics());

  runApp(App());
}

Future<void> _initFirebaseAndCrashlytics() async {
  if (kIsWeb || Platform.isWindows) {
    return;
  }

  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 6));
  } catch (_) {
    // Timed out or failed — continue without Firebase rather than hang forever.
    return;
  }

  try {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode)
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // Ignore Crashlytics setup failures.
  }
}
