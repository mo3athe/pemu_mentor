import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'mentor_resources_screen.dart';

enum EventSortOption {
  dateTime('Date and Time'),
  alphabetical('Alphabetical Order'),
  relevance('Relevance');

  final String label;
  const EventSortOption(this.label);
}

class MentorDetailScreen extends StatefulWidget {
  final String mentorId;
  final String mentorName;

  const MentorDetailScreen({
    super.key,
    required this.mentorId,
    required this.mentorName,
  });

  @override
  State<MentorDetailScreen> createState() => _MentorDetailScreenState();
}

class _MentorDetailScreenState extends State<MentorDetailScreen> {
  EventSortOption _currentSortOption = EventSortOption.dateTime;

  List<QueryDocumentSnapshot> _sortEvents(List<QueryDocumentSnapshot> events) {
    switch (_currentSortOption) {
      case EventSortOption.dateTime:
        events.sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['dateTime'] as Timestamp;
          final bDate = (b.data() as Map<String, dynamic>)['dateTime'] as Timestamp;
          return aDate.compareTo(bDate);
        });
        break;
      case EventSortOption.alphabetical:
        events.sort((a, b) {
          final aTitle = (a.data() as Map<String, dynamic>)['title'] as String;
          final bTitle = (b.data() as Map<String, dynamic>)['title'] as String;
          return aTitle.compareTo(bTitle);
        });
        break;
      case EventSortOption.relevance:
        // Sort by category and then by date
        events.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCategory = aData['category'] as String;
          final bCategory = bData['category'] as String;
          
          // First compare by category
          final categoryComparison = aCategory.compareTo(bCategory);
          if (categoryComparison != 0) return categoryComparison;
          
          // If categories are the same, compare by date
          final aDate = aData['dateTime'] as Timestamp;
          final bDate = bData['dateTime'] as Timestamp;
          return aDate.compareTo(bDate);
        });
        break;
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mentorName),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'View Resources',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MentorResourcesScreen(
                    mentorId: widget.mentorId,
                    mentorName: widget.mentorName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.mentorId)
            .get(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> mentorSnapshot) {
          if (mentorSnapshot.hasError) {
            return Center(
              child: Text('Error: ${mentorSnapshot.error}'),
            );
          }

          if (mentorSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final mentorData = mentorSnapshot.data?.data() as Map<String, dynamic>?;

          return Column(
            children: [
              if (mentorData != null)
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              child: Text(
                                mentorData['name']?[0] ?? '?',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mentorData['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    mentorData['expertise'] ?? 'No expertise listed',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (mentorData['bio'] != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            mentorData['bio'],
                            style: TextStyle(
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Sort Options and Events Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Events',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<EventSortOption>(
                      value: _currentSortOption,
                      items: EventSortOption.values.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _currentSortOption = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Events List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .where('mentorId', isEqualTo: widget.mentorId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading events: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var events = snapshot.data?.docs ?? [];

                    if (events.isEmpty) {
                      return const Center(
                        child: Text(
                          'No events scheduled\nCheck back later!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    // Sort events based on selected option
                    events = _sortEvents(events);

                    // Group events by upcoming and past
                    final now = DateTime.now();
                    final upcomingEvents = events.where((doc) {
                      final event = doc.data() as Map<String, dynamic>;
                      final eventDate = (event['dateTime'] as Timestamp).toDate();
                      return eventDate.isAfter(now);
                    }).toList();

                    final pastEvents = events.where((doc) {
                      final event = doc.data() as Map<String, dynamic>;
                      final eventDate = (event['dateTime'] as Timestamp).toDate();
                      return eventDate.isBefore(now);
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (upcomingEvents.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Upcoming Events',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          ...upcomingEvents.map((doc) => _buildEventCard(
                                context,
                                doc.data() as Map<String, dynamic>,
                                false,
                              )),
                        ],
                        if (pastEvents.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Past Events',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ...pastEvents.map((doc) => _buildEventCard(
                                context,
                                doc.data() as Map<String, dynamic>,
                                true,
                              )),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    Map<String, dynamic> event,
    bool isPastEvent,
  ) {
    final DateTime eventDate = (event['dateTime'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPastEvent ? Colors.grey : Colors.blue,
          child: Icon(
            event['eventType'] == 'Virtual'
                ? Icons.video_call
                : Icons.location_on,
            color: Colors.white,
          ),
        ),
        title: Text(
          event['title'] ?? 'Untitled Event',
          style: TextStyle(
            decoration: isPastEvent ? TextDecoration.lineThrough : null,
            color: isPastEvent ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, yyyy - hh:mm a').format(eventDate),
              style: TextStyle(
                color: isPastEvent ? Colors.grey : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event['description'] ?? 'No description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    event['category'] ?? 'No category',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    event['eventType'] ?? 'No type',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.grey[200],
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showEventDetails(context, event, eventDate, isPastEvent),
      ),
    );
  }

  void _showEventDetails(
    BuildContext context,
    Map<String, dynamic> event,
    DateTime eventDate,
    bool isPastEvent,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  event['title'] ?? 'Untitled Event',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(eventDate),
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('hh:mm a').format(eventDate),
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(event['description'] ?? 'No description'),
                const SizedBox(height: 16),
                const Text(
                  'Location/Meeting Link',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(event['location'] ?? 'No location specified'),
                const SizedBox(height: 24),
                if (!isPastEvent)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement event registration
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Event registration coming soon!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Register for Event'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
