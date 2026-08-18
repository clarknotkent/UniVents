// lib/app_config.dart
//
// Runtime configuration, read from `.env` with compiled-in fallbacks.
//
// WHAT THIS IS NOT: a secret store. Flutter bundles `.env` as an asset, so its
// contents ship inside the binary and can be extracted. Every value here is
// public by nature - the same class of thing as the API keys in
// firebase_options.dart. Secrets belong on a server, never in a client.
//
// WHAT THIS IS: one declared place for values that change between environments,
// so retargeting the app is a config edit rather than a source edit.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  // Fallbacks used when `.env` is missing or a key is absent. They keep a fresh
  // clone runnable with no setup step, which matters because `.env` is
  // gitignored and therefore never arrives with the repository.
  static const String _defaultEmailDomain = 'addu.edu.ph';
  static const String _defaultServerClientId =
      '1097036028807-e1ik2lc81l701vccr675g7f2ribh9rh8.apps.googleusercontent.com';

  static bool _loaded = false;

  /// Loads `.env`. Safe to call when the file does not exist - a missing file
  /// is a normal state (fresh clone, CI) rather than an error, so it is logged
  /// and the compiled defaults are used instead.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (_) {
      _loaded = false;
      debugPrint('AppConfig: no .env found, using compiled defaults. '
          'Copy .env.example to .env to override.');
    }
  }

  static String _read(String key, String fallback) {
    if (!_loaded) return fallback;
    final String? value = dotenv.env[key];
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  /// Email domain permitted to sign in.
  ///
  /// This is a client-side convenience only. The binding restriction is the
  /// matching check in firestore.rules - editing this value does not widen or
  /// narrow who can actually read data.
  static String get authEmailDomain =>
      _read('AUTH_EMAIL_DOMAIN', _defaultEmailDomain);

  /// OAuth 2.0 web client ID used by Google Sign-In on Android.
  static String get googleServerClientId =>
      _read('GOOGLE_SERVER_CLIENT_ID', _defaultServerClientId);
}
