// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For user info and logout
import 'package:google_sign_in/google_sign_in.dart'; // For Google logout
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
import 'dart:async'; // Import for StreamController and debounce

// Import the screen for organization events
import 'organization_events_screen.dart';

// Model class for Organization data
class Organization {
  final String id;
  final String name;
  final String? acronym;
  final String? logoUrl;

  Organization({
    required this.id,
    required this.name,
    this.acronym,
    this.logoUrl,
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Organization',
      acronym: data['acronym'],
      logoUrl: data['logo'],
    );
  }
}

// HomeScreen Widget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // Default to Home tab
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<Organization> _allOrganizations = []; // Store all fetched organizations
  List<Organization> _filteredOrganizations =
      []; // Organizations filtered by search
  StreamSubscription?
  _organizationsSubscription; // To manage the stream subscription
  // Stream controller to push filtered results to the StreamBuilder
  final StreamController<List<Organization>>
  _filteredOrganizationsStreamController = StreamController.broadcast();

  Timer? _debounce; // Timer for debouncing search input

  @override
  void initState() {
    super.initState();
    // Set status bar icons to light for visibility on background
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent, // Make status bar transparent
      ),
    );
    _subscribeToOrganizations(); // Fetch and listen for organization updates
    _searchController.addListener(
      _onSearchChanged,
    ); // Listen for changes in the search field
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _organizationsSubscription?.cancel(); // Cancel Firestore subscription
    _filteredOrganizationsStreamController
        .close(); // Close the stream controller
    _debounce?.cancel(); // Cancel the debounce timer
    super.dispose();
  }

  // Subscribe to Firestore stream, store all orgs, and perform initial filtering
  void _subscribeToOrganizations() {
    _organizationsSubscription?.cancel(); // Cancel any previous subscription

    _organizationsSubscription = FirebaseFirestore.instance
        .collection('organizations')
        .orderBy('name', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
            // Map Firestore docs to Organization objects and store them
            _allOrganizations =
                snapshot.docs
                    .map((doc) => Organization.fromFirestore(doc))
                    .toList();
            // Apply the current search filter (initially empty)
            _filterOrganizations();
          },
          onError: (error) {
            debugPrint("Error in organizations stream: $error");
            if (mounted) {
              _allOrganizations = [];
              _filteredOrganizations = [];
              // Push an empty list to the stream on error
              if (!_filteredOrganizationsStreamController.isClosed) {
                _filteredOrganizationsStreamController.add(
                  _filteredOrganizations,
                );
              }
            }
          },
        );
  }

  // Called when the search text field changes
  void _onSearchChanged() {
    // Debounce: Wait for a short period after the user stops typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // Check if mounted and if the search text actually changed
      if (mounted && _searchController.text != _searchQuery) {
        // Update the state with the new search query
        setState(() {
          _searchQuery = _searchController.text;
        });
        _filterOrganizations(); // Trigger the filtering logic
      }
    });
  }

  // Filter the full list of organizations based on the search query
  void _filterOrganizations() {
    if (_searchQuery.isEmpty) {
      // If search is empty, show all organizations
      _filteredOrganizations = List.from(_allOrganizations);
    } else {
      // Otherwise, filter based on name or acronym (case-insensitive)
      final queryLower = _searchQuery.toLowerCase();
      _filteredOrganizations =
          _allOrganizations.where((org) {
            final nameLower = org.name.toLowerCase();
            final acronymLower = org.acronym?.toLowerCase() ?? '';
            // Return true if name OR acronym contains the query
            return nameLower.contains(queryLower) ||
                (acronymLower.isNotEmpty && acronymLower.contains(queryLower));
          }).toList();
    }
    // Add the newly filtered list to our stream controller
    if (!_filteredOrganizationsStreamController.isClosed) {
      _filteredOrganizationsStreamController.add(_filteredOrganizations);
    }
  }

  // Handle bottom navigation taps
  void _onItemTapped(int index) {
    if (index == 1) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      // Placeholder for other tabs
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation to other tabs not implemented yet.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Logout function
  Future<void> _logout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      try {
        debugPrint("Logging out...");
        // Sign out from Google and Firebase
        await GoogleSignIn.instance.signOut();
        await FirebaseAuth.instance.signOut();
        // Navigate back to login screen, removing all previous routes
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint("Error during logout: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      debugPrint("Logout cancelled by user.");
    }
  }

  // Build individual organization card
  Widget _buildOrganizationCard(Organization org) {
    const int nameLengthThreshold =
        18; // Use acronym if name is longer than this
    final bool useAcronym =
        org.name.length > nameLengthThreshold &&
        org.acronym != null &&
        org.acronym!.isNotEmpty;
    final String displayName = useAcronym ? org.acronym! : org.name;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      elevation: 3.0,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // Navigate to the specific organization's events screen
          debugPrint('Navigating to events for ${org.name}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrganizationEventsScreen(organization: org),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
                child:
                    (org.logoUrl != null && org.logoUrl!.isNotEmpty)
                        ? Image.network(
                          // Display network image if URL exists
                          org.logoUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            // Show progress indicator while loading
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                strokeWidth: 2.0,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Show fallback icon if image fails to load
                            debugPrint("Error loading image ${org.logoUrl}: $error");
                            return Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                            );
                          },
                        )
                        // Show fallback icon if no logo URL
                        : Center(
                          child: Icon(
                            Icons.business,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ),
              ),
            ),
            // Text Area (Name/Acronym)
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 10.0),
              child: Text(
                displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.grey[850],
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Allow up to two lines
                overflow:
                    TextOverflow.ellipsis, // Add ellipsis if text overflows
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF0B4EA8); // AdDU Blue
    final User? currentUser = FirebaseAuth.instance.currentUser;
    // Get user display name or email as fallback
    String userDisplayName =
        currentUser?.displayName ?? currentUser?.email ?? 'Guest';
    const String backgroundImagePath = 'assets/images/splash_background.jpg';
    final filterColor = primaryColor;
    const filterOpacity = 0.6;

    return Scaffold(
      // Use Stack for layering background, filter, and content
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Background Image
          Image.asset(
            backgroundImagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint("Error loading background image: $error");
              return Container(
                color: primaryColor.withValues(alpha: 0.8),
              ); // Fallback color
            },
          ),

          // Layer 2: Translucent Blue Filter
          Container(color: filterColor.withValues(alpha: filterOpacity)),

          // Layer 3: Content (wrapped in SafeArea)
          SafeArea(
            bottom: false, // Allow card to go near bottom edge
            child: Column(
              children: [
                // --- Top Section (Custom AppBar Look) ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/addu_logo.jpg',
                        height: 40,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.school,
                              color: Colors.white,
                              size: 30,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'UNIVENTS!',
                              style: TextStyle(
                                fontFamily: 'SpectralSC',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(blurRadius: 2, color: Colors.black54),
                                ],
                              ),
                            ),
                            Text(
                              userDisplayName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                                shadows: [
                                  Shadow(blurRadius: 1, color: Colors.black54),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        // Action buttons
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.logout_outlined,
                              color: Colors.white,
                            ),
                            onPressed: _logout,
                            tooltip: 'Logout',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.brightness_6_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              /* TODO: Theme */
                            },
                            tooltip: 'Toggle Theme',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10), // Space
                // --- Content Card Section ---
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero, // No margin for edge-to-edge feel
                    color: Colors.white,
                    shape: const RoundedRectangleBorder(
                      // Round only top corners
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25.0),
                        topRight: Radius.circular(25.0),
                      ),
                    ),
                    elevation: 5.0,
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Card Title
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 8.0,
                              bottom: 8.0,
                            ),
                            child: Text(
                              'Select an Organization',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[850],
                              ),
                            ),
                          ),
                          // --- Search Bar ---
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 16.0,
                              left: 4.0,
                              right: 4.0,
                            ),
                            child: TextField(
                              controller:
                                  _searchController, // Controller for search input
                              decoration: InputDecoration(
                                hintText: 'Search Organizations...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                filled: true,
                                fillColor:
                                    Colors
                                        .grey[100], // Light background for search bar
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                  borderSide:
                                      BorderSide.none, // No visible border
                                ),
                                // Clear button appears when text is entered
                                suffixIcon:
                                    _searchQuery.isNotEmpty
                                        ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.grey[600],
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _searchController
                                                .clear(); // Clears text and triggers the listener
                                          },
                                        )
                                        : null, // No clear button when empty
                              ),
                              // The listener (_onSearchChanged) handles text changes
                            ),
                          ),
                          // --- Organizations Grid ---
                          Expanded(
                            child: StreamBuilder<List<Organization>>(
                              // Listen to the stream of FILTERED organizations
                              stream:
                                  _filteredOrganizationsStreamController.stream,
                              // Initial data helps prevent brief "loading" flicker if data is ready
                              initialData: _filteredOrganizations,
                              builder: (context, snapshot) {
                                // Check for errors from the stream controller
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Error loading organizations.',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  );
                                }

                                // Get the latest list of organizations from the stream
                                final organizations = snapshot.data ?? [];

                                // Determine what to display based on the data and search query
                                if (organizations.isEmpty) {
                                  if (_searchQuery.isNotEmpty) {
                                    // No results for the current search
                                    return Center(
                                      child: Text(
                                        'No organizations found matching "$_searchQuery".',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  } else if (_allOrganizations.isEmpty &&
                                      snapshot.connectionState !=
                                          ConnectionState.waiting) {
                                    // Initial load finished, but no organizations found in Firestore
                                    return Center(
                                      child: Text(
                                        'No organizations available.',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Still loading initial data OR empty list before first load completes
                                    return Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              primaryColor,
                                            ),
                                      ),
                                    );
                                  }
                                }

                                // Display the Grid if we have organizations
                                return GridView.builder(
                                  itemCount: organizations.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2, // Two cards per row
                                        crossAxisSpacing: 10.0,
                                        mainAxisSpacing: 10.0,
                                        childAspectRatio:
                                            0.85, // Adjust aspect ratio if needed
                                      ),
                                  itemBuilder: (context, index) {
                                    // Build a card for each organization in the filtered list
                                    return _buildOrganizationCard(
                                      organizations[index],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // --- Bottom Navigation Bar ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Account',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            label: 'Notification',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Calendar',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed, // Ensures all labels are visible
        onTap: _onItemTapped,
        showUnselectedLabels: true,
      ),
    );
  }
}
