// lib/organization_events_screen.dart
// Layout with Blue Background, White Content Card, Horizontal Upcoming List, All Grid

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:async'; // For debounce Timer

// Import the Organization model from home_screen.dart
import 'home_screen.dart'; // Assuming Organization class is here
// Import the details screen for navigation
import 'event_details_screen.dart';

// --- Event Model (UPDATED with description) ---
class Event {
  final String id;
  final String title;
  final String? bannerUrl;
  final String location;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String organizationId;
  final String? description; // <-- ADDED description field

  Event({
    required this.id,
    required this.title,
    this.bannerUrl,
    required this.location,
    this.startDateTime,
    this.endDateTime,
    required this.organizationId,
    this.description, // <-- ADDED description field to constructor
  });

  static DateTime? _parseDateString(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      print("Error parsing date string '$dateString': $e");
      return null;
    }
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? 'Unnamed Event',
      bannerUrl: data['banner'],
      location: data['location'] ?? 'No location',
      startDateTime: _parseDateString(data['datetimestart']),
      endDateTime: _parseDateString(data['datetimeend']),
      organizationId: data['orguid'] ?? '',
      description: data['description'], // <-- Fetch description from Firestore
    );
  }
}
// --- End Event Model ---

// --- Organization Events Screen Widget ---
class OrganizationEventsScreen extends StatefulWidget {
  final Organization organization;
  const OrganizationEventsScreen({required this.organization, super.key});

  @override
  State<OrganizationEventsScreen> createState() =>
      _OrganizationEventsScreenState();
}

class _OrganizationEventsScreenState extends State<OrganizationEventsScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  Timer? _debounce; // Timer for debouncing search input

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel(); // Cancel debounce timer
    super.dispose();
  }

  // Called when the search text field changes
  void _onSearchChanged() {
    // Debounce the search to avoid filtering on every keystroke
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // Check if the widget is still mounted and the query actually changed
      if (mounted && _searchController.text != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text;
          // No need to call a separate filter method here,
          // the streams will re-evaluate with the new _searchQuery
          print("Search query updated: $_searchQuery");
        });
      }
    });
  }

  // Helper method to filter a list of events based on the current search query
  List<Event> _filterEvents(List<Event> events) {
    if (_searchQuery.isEmpty) {
      return events; // Return all events if search is empty
    }
    final queryLower = _searchQuery.toLowerCase();
    return events.where((event) {
      final titleLower = event.title.toLowerCase();
      // Add more fields to search if needed (e.g., location, description)
      // final locationLower = event.location.toLowerCase();
      // final descriptionLower = event.description?.toLowerCase() ?? '';
      return titleLower.contains(
        queryLower,
      ); // || locationLower.contains(queryLower) || descriptionLower.contains(queryLower);
    }).toList();
  }

  // --- Firestore Streams ---
  // Stream for UPCOMING events (horizontal list) - NOW FILTERS LOCALLY
  Stream<List<Event>> _getUpcomingEventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .where('orguid', isEqualTo: widget.organization.id)
        .where(
          'datetimestart',
          isGreaterThanOrEqualTo: DateTime.now().toIso8601String(),
        )
        .orderBy('datetimestart', descending: false)
        .snapshots()
        // Map Firestore results to Event objects AND apply local filtering
        .map(
          (snapshot) => _filterEvents(
            snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList(),
          ),
        )
        .handleError((error) {
          print("Error in upcoming events stream: $error");
          return <Event>[];
        });
  }

  // Stream for ALL events (grid) - NOW FILTERS LOCALLY
  Stream<List<Event>> _getAllEventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .where('orguid', isEqualTo: widget.organization.id)
        .orderBy('datetimestart', descending: true) // Newest first
        .snapshots()
        // Map Firestore results to Event objects AND apply local filtering
        .map(
          (snapshot) => _filterEvents(
            snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList(),
          ),
        )
        .handleError((error) {
          print("Error in all events stream: $error");
          return <Event>[];
        });
  }
  // --- End Firestore Streams ---

  // --- Widget Builders ---

  // Builds card for the HORIZONTAL upcoming events list
  Widget _buildUpcomingEventCard(Event event) {
    String dateStr = 'Date N/A';
    String timeStr = 'Time N/A';
    if (event.startDateTime != null) {
      try {
        dateStr = DateFormat(
          'MMM d',
        ).format(event.startDateTime!); // Shorter date e.g., Apr 28
        timeStr = DateFormat(
          'h:mm a',
        ).format(event.startDateTime!); // e.g., 9:00 AM
      } catch (e) {
        print("Error formatting upcoming date/time: $e");
      }
    }

    return SizedBox(
      width: 250, // Adjust width as needed for the horizontal list card size
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        elevation: 3.0,
        margin: const EdgeInsets.only(
          right: 12.0,
        ), // Spacing between horizontal cards
        child: InkWell(
          // --- UPDATED onTap ---
          onTap: () {
            print('Navigating to details for: ${event.title}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => EventDetailsScreen(
                      event: event,
                    ), // Pass the event object
              ),
            );
          },
          // --- End Update ---
          child: Column(
            // Use Column: Image first, then details
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Image
              Expanded(
                flex: 2, // Give image more space
                child:
                    (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
                        ? Image.network(
                          event.bannerUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (ctx, err, st) => Container(
                                color: Colors.grey[200],
                                child: Center(child: Icon(Icons.broken_image)),
                              ),
                          loadingBuilder:
                              (ctx, child, progress) =>
                                  progress == null
                                      ? child
                                      : Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                        )
                        : Container(
                          color: Colors.grey[200],
                          child: Center(child: Icon(Icons.image_not_supported)),
                        ),
              ),
              // Text Details section
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$dateStr • $timeStr',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 2),
                    Text(
                      event.location,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds card for the ALL EVENTS GRID
  Widget _buildGridEventCard(Event event) {
    String dateStr = 'Date N/A';
    if (event.startDateTime != null) {
      try {
        dateStr = DateFormat('MMM d, yyyy').format(event.startDateTime!);
      } catch (e) {}
    }
    bool isPast = event.startDateTime?.isBefore(DateTime.now()) ?? false;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      elevation: isPast ? 1.0 : 3.0,
      color: isPast ? Colors.grey[100] : Colors.white,
      child: InkWell(
        // --- UPDATED onTap ---
        onTap: () {
          print('Navigating to details for: ${event.title}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      EventDetailsScreen(event: event), // Pass the event object
            ),
          );
        },
        // --- End Update ---
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Banner Image
            if (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: isPast ? 0.6 : 1.0,
                  child: Image.network(
                    event.bannerUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (ctx, err, st) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                    loadingBuilder:
                        (ctx, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[200],
                child: Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            // Gradient Overlay
            Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10.0),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(isPast ? 0.6 : 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Text Details
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 1, color: Colors.black87)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2),
                  Text(
                    dateStr + (isPast ? " (Past)" : ""),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.9),
                      fontStyle: isPast ? FontStyle.italic : FontStyle.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- End Widget Builders ---

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF0B4EA8); // AdDU Blue
    String userName =
        _currentUser?.displayName?.split(' ').first ??
        _currentUser?.email?.split('@')[0] ??
        'User';
    final Color screenBackgroundColor = Color(
      0xFFF0F2F5,
    ); // Light greyish background

    // Get the organization name or acronym for the hint text
    final String orgHintName =
        widget.organization.acronym?.isNotEmpty ?? false
            ? widget.organization.acronym!
            : widget.organization.name;

    return Scaffold(
      backgroundColor:
          screenBackgroundColor, // Use light background for scaffold
      // --- AppBar ---
      appBar: AppBar(
        /* ... AppBar code ... */
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, $userName!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Events by ${widget.organization.name}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () {
              /* TODO: Theme */
            },
            tooltip: 'Toggle Theme',
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 1.0,
      ),

      // --- Body ---
      body: ListView(
        // Use ListView for overall scrolling sections
        padding: const EdgeInsets.only(
          top: 12.0,
        ), // Add padding only at the top
        children: [
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ), // Horizontal padding for search
            child: TextField(
              /* Search Bar Config */
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Search $orgHintName Events...', // Use dynamic org name/acronym
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white, // White search bar
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                // Optional: Add a clear button
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
                                .clear(); // Clears text and triggers listener via _onSearchChanged
                          },
                        )
                        : null,
              ),
              // onChanged is handled by the listener added in initState
              // onChanged: (value) { /* Handled by listener */ },
            ),
          ),
          const SizedBox(height: 16),

          // --- Upcoming Events Section (Horizontal Scroll) ---
          Padding(
            padding: const EdgeInsets.only(
              left: 12.0,
              bottom: 8.0,
            ), // Padding for title
            child: Text(
              'Upcoming Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            // Constrain the height of the horizontal list
            height: 190, // Adjust height based on card size + padding
            child: StreamBuilder<List<Event>>(
              stream:
                  _getUpcomingEventsStream(), // Stream now includes filtering
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  // Show loader only if waiting AND no data has arrived yet
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.hasError)
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );

                // Use snapshot.data, which is the filtered list
                final upcomingEvents = snapshot.data ?? [];

                if (upcomingEvents.isEmpty) {
                  // Show message based on whether there's an active search query
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No upcoming events.'
                            : 'No upcoming events found matching "$_searchQuery".',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection:
                      Axis.horizontal, // Enable horizontal scrolling
                  padding: const EdgeInsets.only(
                    left: 12.0,
                  ), // Left padding for the list
                  itemCount: upcomingEvents.length,
                  itemBuilder: (context, index) {
                    return _buildUpcomingEventCard(
                      upcomingEvents[index],
                    ); // Use the horizontal card widget
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // --- All Events Grid Section ---
          Padding(
            padding: const EdgeInsets.only(
              left: 12.0,
              bottom: 8.0,
            ), // Padding for title
            child: const Text(
              'All Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            // Add horizontal padding for the grid itself
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: StreamBuilder<List<Event>>(
              stream: _getAllEventsStream(), // Stream now includes filtering
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  // Show loader only if waiting AND no data has arrived yet
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));

                // Use snapshot.data, which is the filtered list
                final allEvents = snapshot.data ?? [];

                if (allEvents.isEmpty) {
                  // Show message based on whether there's an active search query
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No events found for this organization.'
                            : 'No events found matching "$_searchQuery".',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                // Build the grid
                return GridView.builder(
                  shrinkWrap: true, // Important inside ListView
                  physics:
                      const NeverScrollableScrollPhysics(), // Let ListView handle scrolling
                  itemCount: allEvents.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.0,
                    mainAxisSpacing: 12.0,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    return _buildGridEventCard(
                      allEvents[index],
                    ); // Use the grid card widget
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20), // Add some padding at the very bottom
        ],
      ),
    );
  }
}
