// lib/login_screen.dart
import 'package:flutter/material.dart';

// --- Firebase Imports ---
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// --- End Firebase Imports ---


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- State Variables ---
  final _usernameController = TextEditingController(); // Using this for email
  final _passwordController = TextEditingController();
  bool _isPasswordObscured = true;
  final _formKey = GlobalKey<FormState>(); // Key for managing the form state

  // --- Firebase Instance Variables ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- State Variable for Loading Indicator ---
  bool _isLoading = false;

  // --- Constant for ADDU Domain ---
  // Make sure this domain is exactly correct
  final String _expectedDomain = "addu.edu.ph";

  // --- Lifecycle Methods ---
  @override
  void dispose() {
    // Dispose controllers when the widget is removed from the tree
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Helper Methods ---
  // Toggles the visibility of the password field
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordObscured = !_isPasswordObscured;
    });
  }

  // --- Email/Password Sign-In Logic with ADDU Check ---
  Future<void> _signInWithEmailPassword() async {
    // 1. Validate the form fields using the _formKey
    // The validator for the email field now includes the ADDU domain check
    if (!_formKey.currentState!.validate()) {
       return; // Exit if form is not valid (e.g., empty fields, invalid email format, wrong domain)
    }

    // 2. Hide keyboard to prevent obstruction
    FocusScope.of(context).unfocus();

    // Get trimmed email and password
    final String email = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    // 3. Double Check ADDU Domain (Safety check before Firebase call)
    // This check is redundant if the validator works correctly, but adds robustness.
    if (!email.toLowerCase().endsWith('@$_expectedDomain')) {
       if (mounted) { // Check if the widget is still mounted before showing SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Access denied. Please use your $_expectedDomain email.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
       }
       return; // Stop if domain is incorrect
    }

    // 4. Set loading state and attempt Firebase sign-in
    setState(() { _isLoading = true; });

    try {
      // Attempt to sign in using Firebase Authentication
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? firebaseUser = userCredential.user;

      // 5. If sign-in successful, check/update Firestore
      if (firebaseUser != null) {
        print("[Email/Pass] Signed in UID: ${firebaseUser.uid}, Email: ${firebaseUser.email}");
        // Get reference to the user's document in Firestore
        final DocumentReference userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
        final DocumentSnapshot userDoc = await userDocRef.get(); // Read the document

        // If the user document doesn't exist in Firestore, create it
        if (!userDoc.exists) {
          await userDocRef.set({
            'uid': firebaseUser.uid,
            'email': firebaseUser.email,
            'displayName': firebaseUser.displayName, // May be null initially
            'photoURL': firebaseUser.photoURL,       // May be null initially
            'createdAt': FieldValue.serverTimestamp(), // Record creation time
            'role': 'student',                       // Assign default role
          });
          print("[Email/Pass] New user document created with student role.");
        } else {
          // User document already exists, safely get the role
           final role = (userDoc.data() as Map<String, dynamic>?)?['role'] ?? 'N/A';
           print("[Email/Pass] Existing user signed in. Role: $role");
           // Optionally update last login time or other fields
           // await userDocRef.update({'lastLogin': FieldValue.serverTimestamp()});
        }

        // 6. Navigate to the home screen on successful login and Firestore check
        if (mounted) Navigator.pushReplacementNamed(context, '/home');

      } else {
         // This case should theoretically not be reached if signIn succeeds without error
         throw Exception("User details not found after email/password sign in.");
      }

    // Handle specific Firebase Authentication errors
    } on FirebaseAuthException catch (e) {
      print("[Email/Pass] Firebase Auth Error: ${e.code} - ${e.message}");
      String errorMessage = 'Login failed. Please check your credentials.';
      if (e.code == 'user-not-found' || e.code == 'invalid-email') errorMessage = 'No user found with that email address.';
      else if (e.code == 'wrong-password' || e.code == 'invalid-credential') errorMessage = 'Incorrect password. Please try again.';
      else if (e.code == 'user-disabled') errorMessage = 'This user account has been disabled.';
      else errorMessage = 'An authentication error occurred (${e.code}). Please try again later.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent));

    // Handle other potential errors
    } catch (e) {
      print("[Email/Pass] Error during Sign-In: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: ${e.toString()}'), backgroundColor: Colors.redAccent));

    // Ensure loading indicator is turned off regardless of success or failure
    } finally {
       if (mounted) setState(() { _isLoading = false; });
    }
  }
  // --- End Email/Password Sign-In Logic ---


  // --- Google Sign-In Logic (ADDU Check, Firestore Role) ---
  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus(); // Hide keyboard
    setState(() { _isLoading = true; });

    try {
      // 1. Trigger Google Sign-In prompt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Handle if user cancelled the Google Sign-In prompt
      if (googleUser == null) {
        if (mounted) setState(() { _isLoading = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Sign-In cancelled.'), duration: Duration(seconds: 2)));
        return;
      }

      // --- ADDU Email Check ---
      final String userEmail = googleUser.email; // googleUser is guaranteed non-null here
      // Check if email is null OR doesn't end with the expected domain (case-insensitive)
      if (!userEmail.toLowerCase().endsWith('@$_expectedDomain')) {
        await _googleSignIn.signOut(); // Sign out from Google side to allow re-selection
        if (mounted) setState(() { _isLoading = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Access denied. Please use your $_expectedDomain email.'), backgroundColor: Colors.orangeAccent));
        return; // Stop the process
      }
      // --- End Check ---

      // 2. Get Google authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a Firebase credential using Google tokens
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase using the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      // 5. If Firebase sign-in successful, check/update Firestore
      if (firebaseUser != null) {
        print("[Google] Signed in UID: ${firebaseUser.uid}, Email: ${firebaseUser.email}");
        // Get reference to the user's document in Firestore
        final DocumentReference userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
        final DocumentSnapshot userDoc = await userDocRef.get(); // Read the document

        // If the user document doesn't exist in Firestore, create it
        if (!userDoc.exists) {
          await userDocRef.set({
            'uid': firebaseUser.uid,
            'email': firebaseUser.email,
            'displayName': firebaseUser.displayName,
            'photoURL': firebaseUser.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'student', // Assign default student role
          });
          print("[Google] New user document created with student role.");
        } else {
           // User document exists, update display name and photo URL in case they changed
           await userDocRef.update({'displayName': firebaseUser.displayName,'photoURL': firebaseUser.photoURL});
           // Safely get the existing role
           final role = (userDoc.data() as Map<String, dynamic>?)?['role'] ?? 'N/A';
           print("[Google] Existing user signed in. Role: $role");
        }

        // 6. Navigate to Home Screen
        if (mounted) Navigator.pushReplacementNamed(context, '/home');

      } else {
         // This case should theoretically not be reached if signInWithCredential succeeds
         throw Exception("Failed to get Firebase user details after Google sign in.");
      }

    // Handle specific Firebase errors that might occur during credential linking
    } on FirebaseAuthException catch(e) {
       print("[Google] Firebase Auth Error: ${e.code} - ${e.message}");
        if (mounted) setState(() { _isLoading = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase error during Google sign-in: ${e.message ?? e.code}'), backgroundColor: Colors.redAccent));
        // Attempt to sign out from Google as well, as Firebase linking failed
        await _googleSignIn.signOut();

    // Handle other potential errors (network issues, etc.)
    } catch (e) {
      print("[Google] Error during Sign-In: $e");
      if (mounted) setState(() { _isLoading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred during Google Sign-In: ${e.toString()}'), backgroundColor: Colors.redAccent));
      // Attempt to sign out from Google as well
      await _googleSignIn.signOut();

    // Ensure loading indicator is turned off
    } finally {
       if (mounted && _isLoading) setState(() { _isLoading = false; });
    }
  }
  // --- End Google Sign-In Logic ---

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Define primary color for reuse
    final primaryColor = Color(0xFF0B4EA8);
    // Define opacity for the background overlay
    const filterOpacity = 0.5;

    return Scaffold(
      // Make scaffold background transparent to see the Stack background
      backgroundColor: Colors.transparent,
      // Allow content to resize when keyboard appears
      resizeToAvoidBottomInset: true,
      body: Stack(
        // Stack allows layering widgets (background, overlay, content)
        fit: StackFit.expand, // Make stack children fill the screen
        children: [
          // Background Image
          Image.asset(
            'assets/images/splash_background.jpg', // Ensure this path is correct
             fit: BoxFit.cover // Cover the entire screen area
          ),
          // Semi-transparent color overlay
          Container(color: primaryColor.withOpacity(filterOpacity)),
          // SafeArea ensures content isn't obscured by notches or system bars
          SafeArea(
            child: Center( // Center the main content vertically and horizontally
              child: SingleChildScrollView( // Allows scrolling if content overflows
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Center column content vertically
                  children: [
                    // --- Login Form Card ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                      decoration: BoxDecoration(
                        color: Colors.white, // White background for the card
                        borderRadius: BorderRadius.circular(16.0), // Rounded corners
                        // Subtle shadow for depth
                        boxShadow: [ BoxShadow( color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2)) ],
                      ),
                      // Form widget enables validation of TextFormFields
                      child: Form(
                        key: _formKey, // Assign the GlobalKey to the Form
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch, // Make children fill width
                          mainAxisSize: MainAxisSize.min, // Card height wraps content
                          children: [
                            // Logo
                            Image.asset('assets/images/addu_logo.jpg', height: 150),
                            const SizedBox(height: 16),

                            // Titles
                            Text('UNIVENTS!', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'SpectralSC', fontSize: 40, color: primaryColor)),
                            const SizedBox(height: 8),
                            const Text('Welcome Back!', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text('Please sign in using your AdDU account', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                            const SizedBox(height: 28),

                            // --- Email Field with ADDU Validation ---
                             Text('AdDU Email Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController, // Controller for email input
                              decoration: InputDecoration(
                                hintText: 'Email', // Hint text
                                // Standard border style
                                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0)), borderSide: BorderSide(color: Colors.grey)),
                                // Border style when focused
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0)), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]), // Email icon
                              ),
                              keyboardType: TextInputType.emailAddress, // Optimize keyboard
                              autovalidateMode: AutovalidateMode.onUserInteraction, // Validate on interaction
                              validator: (value) { // Validation logic
                                  final String email = (value ?? '').trim();
                                  if (email.isEmpty) return 'Please enter your AdDU email';
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) return 'Please enter a valid email address';
                                  // ADDU Domain Check
                                  if (!email.toLowerCase().endsWith('@$_expectedDomain')) return 'Must be an @$_expectedDomain email';
                                  return null; // Valid
                                },
                            ),
                            const SizedBox(height: 18),

                            // --- Password Field ---
                             Text('Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController, // Controller for password input
                              obscureText: _isPasswordObscured, // Hide/show password text
                              decoration: InputDecoration(
                                hintText: 'Password',
                                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0)), borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0)), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]), // Lock icon
                                // Suffix icon to toggle password visibility
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey[600]),
                                  onPressed: _togglePasswordVisibility, // Call helper method
                                ),
                              ),
                               validator: (value) { // Basic password validation
                                  if (value == null || value.isEmpty) return 'Please enter your password';
                                  return null; // Valid
                                },
                            ),
                            const SizedBox(height: 18),

                            // --- Forgot Password Link ---
                             Align(
                               alignment: Alignment.center, // Align link to the right
                               child: TextButton(
                                 onPressed: () {
                                     // Placeholder for forgot password functionality
                                     print('Forgot Password tapped - TODO');
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forgot password not implemented yet.')));
                                  },
                                 child: Text('Forgot Password?', style: TextStyle(color: Colors.grey[600]))
                               ),
                             ),
                            const SizedBox(height: 20),

                            // --- Conditional Loading Indicator or Login Buttons ---
                            // Show indicator if _isLoading is true, otherwise show buttons
                             _isLoading
                               ? const Center(child: Padding(
                                   // Add padding around the loading indicator
                                   padding: EdgeInsets.symmetric(vertical: 20.0),
                                   child: CircularProgressIndicator(),
                                 ))
                               : Column( // Display buttons in a column when not loading
                                   crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons fill width
                                   children: [
                                     // --- Standard Login Button (Functional + ADDU Check) ---
                                     ElevatedButton(
                                       onPressed: _signInWithEmailPassword, // Call email/password sign-in function
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: primaryColor, // Button background color
                                         foregroundColor: Colors.white, // Text color
                                         padding: const EdgeInsets.symmetric(vertical: 16.0), // Vertical padding
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), // Rounded corners
                                         textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Text style
                                       ),
                                       child: const Text('Login with Email'), // Button text
                                     ),
                                     const SizedBox(height: 10), // Spacing

                                     // --- OR Separator ---
                                     Row(
                                       children: <Widget>[
                                         Expanded(child: Divider(color: Colors.grey[400])), // Line on the left
                                         Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text("OR", style: TextStyle(color: Colors.grey[600]))), // OR text
                                         Expanded(child: Divider(color: Colors.grey[400])), // Line on the right
                                       ],
                                     ),
                                     const SizedBox(height: 10), // Spacing

                                     // --- Google Sign-In Button (Functional + ADDU Check) ---
                                     ElevatedButton.icon(
                                       // Google logo icon
                                       icon: Image.asset('assets/images/google_logo.png', height: 20.0), // Ensure logo exists in assets
                                       label: const Text("Sign in with Google"), // Button text
                                       onPressed: _signInWithGoogle, // Call Google sign-in function
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: Colors.white, // Google style background
                                         foregroundColor: Colors.black87, // Google style text color
                                         padding: const EdgeInsets.symmetric(vertical: 12.0), // Padding
                                         // Rounded corners with border
                                         shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: Colors.grey.shade400)),
                                         textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), // Text style
                                       ),
                                     ),
                                   ],
                                 ),
                            // --- End Conditional Buttons ---
                          ],
                        ),
                      ),
                    ), // --- End of Login Form Card ---
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}