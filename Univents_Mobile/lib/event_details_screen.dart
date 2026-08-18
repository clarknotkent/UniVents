// lib/event_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Firestore operations
import 'package:firebase_auth/firebase_auth.dart'; // Needed for current user ID
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle

// Import the Event model (adjust path if necessary)
import 'organization_events_screen.dart'; // Assuming Event model is here

class EventDetailsScreen extends StatefulWidget {
  final Event event; // Receive the full Event object

  const EventDetailsScreen({required this.event, super.key});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  String? _organizerName;
  bool _isLoadingOrganizer = true;
  bool _isJoined = false; // Tracks if the current user has joined
  bool _isJoining = false; // Tracks if the join operation is in progress
  bool _isUnjoining =
      false; // <<< ADDED: Tracks if the unjoin operation is in progress
  bool _isLoadingJoinedStatus =
      true; // Tracks loading the initial joined status

  final User? _currentUser =
      FirebaseAuth.instance.currentUser; // Get current user

  @override
  void initState() {
    super.initState();
    _fetchOrganizerName();
    _checkIfUserJoined(); // Check joined status when screen loads
    // Set status bar icons to dark for light background
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent, // Keep status bar transparent
      ),
    );
  }

  @override
  void dispose() {
    // Optional: Restore default system UI overlay if needed
    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    super.dispose();
  }

  // Fetches the organization name (No changes needed)
  Future<void> _fetchOrganizerName() async {
    if (widget.event.organizationId.isEmpty) {
      if (mounted) {
        setState(() {
          _organizerName = "N/A";
          _isLoadingOrganizer = false;
        });
      }
      return;
    }
    try {
      DocumentSnapshot orgDoc =
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.event.organizationId)
              .get();
      if (orgDoc.exists && mounted) {
        setState(() {
          _organizerName =
              (orgDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
          _isLoadingOrganizer = false;
        });
      } else if (mounted) {
        setState(() {
          _organizerName = 'Not Found';
          _isLoadingOrganizer = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching organizer name: $e");
      if (mounted) {
        setState(() {
          _organizerName = "Error";
          _isLoadingOrganizer = false;
        });
      }
    }
  }

  // Checks if the current user has already joined this event (No changes needed)
  Future<void> _checkIfUserJoined() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoadingJoinedStatus = false);
      return; // Not logged in, can't check
    }
    try {
      final attendeeDoc =
          await FirebaseFirestore.instance
              .collection('events')
              .doc(widget.event.id)
              .collection('attendees')
              .doc(_currentUser.uid)
              .get();

      if (mounted) {
        setState(() {
          _isJoined = attendeeDoc.exists; // Set true if the document exists
          _isLoadingJoinedStatus = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking joined status: $e");
      if (mounted) setState(() => _isLoadingJoinedStatus = false);
      // Optionally show an error message
    }
  }

  // Handles the logic when the "Join Event" button is pressed
  Future<void> _joinEvent() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to join events.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // <<< Prevent action if already joined or another operation is in progress >>>
    if (_isJoined || _isJoining || _isUnjoining) {
      return;
    }

    if (mounted) {
      setState(() => _isJoining = true); // Show loading state on button
    }

    try {
      // Create a document in the 'attendees' subcollection
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('attendees')
          .doc(_currentUser.uid)
          .set({
            'userId': _currentUser.uid, // Store user ID
            'userName': _currentUser.displayName, // Store user name (optional)
            'userEmail': _currentUser.email, // Store user email (optional)
            'joinedAt': FieldValue.serverTimestamp(), // Record the timestamp
          });

      if (mounted) {
        setState(() {
          _isJoined = true; // Update joined status
          _isJoining = false; // Hide loading indicator
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined "${widget.event.title}"!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error joining event: $e");
      if (mounted) {
        setState(() => _isJoining = false); // Hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join event: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // <<< ADDED: Handles the logic when the "Unjoin" button is pressed >>>
  Future<void> _unjoinEvent() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // <<< Prevent action if not joined or another operation is in progress >>>
    if (!_isJoined || _isJoining || _isUnjoining) {
      return;
    }

    // Optional: Confirmation Dialog
    final bool? confirmUnjoin = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Unjoin'),
            content: Text(
              'Are you sure you want to unjoin "${widget.event.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Unjoin', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmUnjoin != true) {
      return; // User cancelled
    }
    // --- End Optional Confirmation ---

    if (mounted) setState(() => _isUnjoining = true); // Show loading state

    try {
      // Delete the document from the 'attendees' subcollection
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('attendees')
          .doc(_currentUser.uid)
          .delete();

      if (mounted) {
        setState(() {
          _isJoined = false; // Update joined status
          _isUnjoining = false; // Hide loading indicator
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully unjoined "${widget.event.title}".'),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error unjoining event: $e");
      if (mounted) {
        setState(() => _isUnjoining = false); // Hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unjoin event: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Date and Time Formatting --- (No changes)
    String dateStr = 'Date unavailable';
    String timeStr = 'Time unavailable';
    if (widget.event.startDateTime != null) {
      try {
        dateStr = DateFormat(
          'MMMM d, yyyy',
        ).format(widget.event.startDateTime!); // Corrected format string
        timeStr = DateFormat('h:mm a').format(widget.event.startDateTime!);
        if (widget.event.endDateTime != null &&
            widget.event.endDateTime!.isAfter(widget.event.startDateTime!)) {
          timeStr +=
              ' - ${DateFormat('h:mm a').format(widget.event.endDateTime!)}';
        }
      } catch (e) {
        debugPrint("Error formatting detail date/time: $e");
      }
    }
    // --- End Date and Time Formatting ---

    String seatsRemaining = "?? seats remaining"; // Placeholder
    final primaryColor = Color(0xFF0B4EA8); // AdDU Blue
    final Color screenBackgroundColor = Color(
      0xFFF0F2F5,
    ); // Light greyish background

    final double topPadding = MediaQuery.of(context).padding.top;

    // --- MODIFIED: Determine button properties based on state ---
    String buttonText = 'Join Event';
    IconData buttonIcon = Icons.add_circle_outline;
    Color buttonColor = primaryColor;
    VoidCallback? onPressedAction; // Null means disabled

    if (_isLoadingJoinedStatus) {
      buttonText = 'Loading...';
      buttonIcon = Icons.hourglass_empty;
      buttonColor = Colors.grey;
      onPressedAction = null;
    } else if (_isJoining) {
      buttonText = 'Joining...';
      // Icon handled by loading indicator logic below
      buttonColor = Colors.grey;
      onPressedAction = null;
    } else if (_isUnjoining) {
      // <<< ADDED: Check for unjoining state
      buttonText = 'Unjoining...';
      // Icon handled by loading indicator logic below
      buttonColor = Colors.grey;
      onPressedAction = null;
    } else if (_isJoined) {
      // <<< MODIFIED: If joined, button now triggers UNJOIN
      buttonText = 'Joined'; // You could change this to "Unjoin Event"
      buttonIcon =
          Icons.check_circle; // Keep check or use Icons.remove_circle_outline
      buttonColor = Colors.green; // Keep green or use e.g., Colors.orange[700]
      onPressedAction =
          _unjoinEvent; // <<< CHANGED: Set onPressed to unjoin function
    } else if (_currentUser == null) {
      buttonText = 'Login to Join';
      buttonIcon = Icons.login;
      buttonColor = Colors.orangeAccent;
      onPressedAction = null;
    } else {
      // Default case: Not joined, not loading, logged in
      buttonText = 'Join Event';
      buttonIcon = Icons.add_circle_outline;
      buttonColor = primaryColor;
      onPressedAction = _joinEvent; // <<< Set onPressed to join function
    }
    // --- End Button Logic Modification ---

    return Scaffold(
      backgroundColor: screenBackgroundColor, // Set main background
      // No AppBar

      // Use Stack for layering
      body: Stack(
        children: <Widget>[
          // --- Layer 1: Banner Image (at the top) --- (No changes)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 250, // Banner image height
              child:
                  (widget.event.bannerUrl != null &&
                          widget.event.bannerUrl!.isNotEmpty)
                      ? ClipRRect(
                        // Clip image with rounded bottom corners
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(25.0),
                        ),
                        child: Image.network(
                          widget.event.bannerUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (ctx, err, st) => Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                          loadingBuilder:
                              (ctx, child, progress) =>
                                  progress == null
                                      ? child
                                      : Container(
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                        ),
                      )
                      : ClipRRect(
                        // Apply rounding to fallback container too
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(25.0),
                        ),
                        child: Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[500],
                              size: 50,
                            ),
                          ),
                        ),
                      ),
            ),
          ),

          // --- Layer 2: Scrolling Content (starts below banner) --- (No changes)
          Positioned.fill(
            top: 0, // Let it start from the top to scroll under the banner
            child: ListView(
              padding: EdgeInsets.only(
                top: 250 - 30,
              ), // Start padding below banner height minus card overlap
              children: [
                // --- White Details Card ---
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ), // Side margins
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.location_on_outlined,
                        widget.event.location,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        Icons.calendar_today_outlined,
                        '$dateStr | $timeStr',
                      ),
                      const SizedBox(height: 10),
                      _isLoadingOrganizer
                          ? _buildDetailRow(
                            Icons.people_outline,
                            "Loading organizer...",
                          )
                          : _buildDetailRow(
                            Icons.people_outline,
                            _organizerName ?? 'Organizer not found',
                          ),
                      const SizedBox(height: 10),
                      // You might want to fetch and display the actual attendee count here later
                      // _buildDetailRow(Icons.group_outlined, "X attendees"),
                      _buildDetailRow(
                        Icons.chair_outlined,
                        seatsRemaining,
                      ), // Placeholder
                    ],
                  ),
                ), // --- End White Details Card ---
                // --- Event Overview Section ---
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 20,
                    bottom: 20.0,
                  ), // Padding for overview
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[850],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.event.description ?? 'No description available.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ), // --- End Event Overview Section ---
                // Add bottom padding to push content above the FAB
                const SizedBox(height: 80),
              ],
            ),
          ),

          // --- Layer 3: Overlay Buttons (Back & Theme) --- (No changes)
          Positioned(
            // Back Button
            top: topPadding + 5,
            left: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.3),
              shape: CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
            ),
          ),
          Positioned(
            // Theme Button
            top: topPadding + 5,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.3),
              shape: CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(
                  Icons.brightness_6_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  /* TODO: Theme Toggle */
                },
                tooltip: 'Toggle Theme',
              ),
            ),
          ),
        ],
      ),

      // --- Floating Action Button (MODIFIED to handle unjoin) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: onPressedAction, // Use dynamic onPressed based on state
            label:
                (_isJoining ||
                        _isUnjoining) // Show loading indicator if joining OR unjoining
                    ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(buttonText, style: TextStyle(fontSize: 16)),
            icon:
                (_isJoining || _isUnjoining)
                    ? null
                    : Icon(buttonIcon), // Hide icon when loading
            backgroundColor: buttonColor, // Use dynamic color
            foregroundColor: Colors.white,
            splashColor:
                onPressedAction != null
                    ? null
                    : Colors.transparent, // Control splash effect
            elevation:
                onPressedAction != null
                    ? 6.0
                    : 1.0, // Adjust elevation based on enabled state
          ),
        ),
      ),
    );
  }

  // Helper widget to build detail rows with icon and text (No changes)
  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}
