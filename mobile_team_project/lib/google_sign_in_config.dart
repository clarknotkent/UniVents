// lib/google_sign_in_config.dart
//
// Single place where Google Sign-In is configured, so main.dart, login_screen
// and home_screen all talk to the same initialized instance.

// NOTE: deliberately no 'dart:io' import here. This file is reachable from a
// web build (the project has a web/ target and firebase_options.dart carries a
// web configuration), and importing dart:io breaks compilation for web outright
// - a kIsWeb guard at runtime would be too late. defaultTargetPlatform gives the
// same information and compiles everywhere.
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

import 'app_config.dart';
import 'firebase_options.dart';

class GoogleSignInConfig {
  const GoogleSignInConfig._();

  /// Only accounts on this domain may sign in.
  ///
  /// Passed to [GoogleSignIn.initialize] as `hostedDomain` so the Google
  /// account picker never even offers a personal account. This is a UX
  /// nicety - the binding check lives in firestore.rules, because anything
  /// enforced on the client can be bypassed.
  ///
  /// Sourced from `.env` via [AppConfig]; see lib/app_config.dart.
  static String get expectedDomain => AppConfig.authEmailDomain;

  /// The OAuth 2.0 *web* client ID (client_type 3) for this Firebase project.
  ///
  /// Android needs this explicitly: the `com.google.gms.google-services` Gradle
  /// plugin is not applied in android/app/build.gradle.kts, so there is no
  /// generated `default_web_client_id` string resource for the plugin to read.
  /// Like the apiKey values in firebase_options.dart this is a public client
  /// identifier, not a secret.
  static String get _serverClientId => AppConfig.googleServerClientId;

  /// iOS and macOS take the per-app client ID that FlutterFire already recorded.
  static String? get _clientId {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return DefaultFirebaseOptions.currentPlatform.iosClientId;
    }
    return null;
  }

  /// Must be awaited exactly once, before any other GoogleSignIn call.
  static Future<void> initialize() {
    return GoogleSignIn.instance.initialize(
      clientId: _clientId,
      serverClientId: _serverClientId,
      hostedDomain: expectedDomain,
    );
  }
}
