// lib/splash_screen.dart
import 'dart:async'; // Still needed for async operations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemUiOverlayStyle
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

import 'google_sign_in_config.dart';

// Note: We don't need to import LoginScreen directly anymore
// as we are using named routes defined in main.dart

/// Mirrors the two conditions enforced in firestore.rules: the address must be
/// on the university domain, and it must be verified. Verification matters
/// because Firebase's REST sign-up endpoint lets anyone create an account for
/// an address they do not own; only a verified account proves ownership.
bool _isEligible(User user) {
  final String email = user.email?.toLowerCase() ?? '';
  return user.emailVerified &&
      email.endsWith('@${GoogleSignInConfig.expectedDomain}');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    // Set status bar style for a transparent look
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Make status bar transparent
        statusBarIconBrightness: Brightness.light, // Use light icons on status bar (assuming dark background)
      ),
    );
    // Start the process to check authentication and navigate after a delay
    _checkAuthAndNavigate();
  }

  // Checks Firebase Auth state and navigates accordingly after a delay
  void _checkAuthAndNavigate() async {
    // Wait for a short duration to show the splash screen
    // and ensure Firebase initialization (in main.dart) is likely complete.
    await Future.delayed(const Duration(seconds: 3)); // Adjust duration as needed (e.g., 2 or 3 seconds)

    // Check if the widget is still mounted before attempting navigation
    // This prevents errors if the user navigates away quickly or the widget is disposed.
    if (mounted) {
      // Get the current authentication state from Firebase
      User? user = FirebaseAuth.instance.currentUser;

      // A restored session must clear the same bar as a fresh login. Checking
      // only `user != null` would let any account that ever authenticated back
      // in on every subsequent launch, since the @addu.edu.ph gate lives on the
      // login screen and never runs on this path.
      //
      // This is defence in depth, not the enforcement point - firestore.rules
      // is what actually denies such a session any data.
      if (user != null && !_isEligible(user)) {
        debugPrint("Splash: session failed the domain/verification check. Signing out.");
        await FirebaseAuth.instance.signOut();
        user = null;
        // signOut() is an async gap, so the widget may have been disposed while
        // it ran; re-check before touching context below.
        if (!mounted) return;
      }

      // Determine the target route based on whether a user is logged in
      if (user != null) {
        // User is signed in, navigate to the home screen
        debugPrint("Splash: User logged in. Navigating to /home.");
        // Use pushReplacementNamed to replace the splash screen with the home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // User is not signed in, navigate to the login screen
        debugPrint("Splash: No user logged in. Navigating to /login.");
        // Use pushReplacementNamed to replace the splash screen with the login screen
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    // It's good practice to restore default system UI overlay if you changed it,
    // though not strictly necessary if subsequent screens set their own styles.
    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light); // Or .dark depending on default
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define colors and opacity for consistency and readability
    final filterColor = Color(0xFF0B4EA8); // AdDU blue color
    const filterOpacity = 0.5; // Opacity for the color filter overlay

    return Scaffold(
      // Use a Stack to layer the background image, filter, and content
      body: Stack(
        fit: StackFit.expand, // Make stack children fill the entire screen
        children: <Widget>[
          // Background Image
          Image.asset(
            'assets/images/splash_background.jpg', // Ensure this asset path is correct in pubspec.yaml
            fit: BoxFit.cover, // Make the image cover the screen bounds
            // Provide a fallback widget in case the image fails to load
            errorBuilder: (context, error, stackTrace) {
              debugPrint("Error loading splash background: $error");
              // Display a simple colored container as fallback
              return Container(color: Colors.grey[800]);
            },
          ),

          // Transparent Blue Filter Overlay
          // This adds a colored tint over the background image
          Container(
            color: filterColor.withValues(alpha: filterOpacity),
          ),

          // Centered Content (Logo and Text)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center the column vertically
              children: <Widget>[
                // AdDU Logo
                Image.asset(
                  'assets/images/addu_logo.jpg', // Ensure this asset path is correct
                  width: 130, // Specify logo width
                  // Provide a fallback icon if the logo image fails to load
                  errorBuilder: (context, error, stackTrace) {
                     debugPrint("Error loading AdDU logo: $error");
                     // Display a generic school icon as fallback
                     return const Icon(Icons.school, color: Colors.white, size: 80);
                  }
                ),
                const SizedBox(height: 24), // Spacing between logo and title

                // App Title Text
                const Text(
                  'UNIVENTS!',
                  style: TextStyle(
                    fontFamily: 'SpectralSC', // Ensure this font is declared in pubspec.yaml
                    fontSize: 40,
                    color: Colors.white, // White text for visibility
                    letterSpacing: 1.5, // Adjust letter spacing
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8), // Spacing between title and subtitle

                // Subtitle Text
                const Text(
                  'Ad Majorem dei Gloriam!',
                  style: TextStyle(
                    fontFamily: 'SpectralSC', // Ensure font is declared
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                 const SizedBox(height: 60), // Add some extra space at the bottom

                 // You could add a subtle loading indicator here if desired,
                 // especially if the delay or auth check takes noticeable time.
                 // Example:
                 // CircularProgressIndicator(
                 //   valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                 //   strokeWidth: 2.0,
                 // ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}
