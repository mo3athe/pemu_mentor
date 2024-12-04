import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mentor_detail_screen.dart';

class MentorListScreen extends StatefulWidget {
  const MentorListScreen({super.key});

  @override
  State<MentorListScreen> createState() => _MentorListScreenState();
}

class _MentorListScreenState extends State<MentorListScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'mentor');

    if (_selectedCategory != 'All') {
      query = query.where('expertise', isEqualTo: _selectedCategory);
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter Section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search mentors...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 16),
              // Category Filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == 'All',
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = 'All';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Academic'),
                      selected: _selectedCategory == 'Academic',
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = 'Academic';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Career'),
                      selected: _selectedCategory == 'Career',
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = 'Career';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Personal Development'),
                      selected: _selectedCategory == 'Personal Development',
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = 'Personal Development';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Mentor List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final mentors = snapshot.data!.docs;

              if (mentors.isEmpty) {
                return const Center(
                  child: Text('No mentors found'),
                );
              }

              return ListView.builder(
                itemCount: mentors.length,
                itemBuilder: (context, index) {
                  final mentorDoc = mentors[index];
                  final mentor = mentorDoc.data() as Map<String, dynamic>;
                  final mentorId = mentorDoc.id; // Get the document ID

                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    final name = mentor['name']?.toString().toLowerCase() ?? '';
                    final bio = mentor['bio']?.toString().toLowerCase() ?? '';
                    if (!name.contains(_searchQuery) && !bio.contains(_searchQuery)) {
                      return const SizedBox.shrink();
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          mentor['name']?[0] ?? '?',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      title: Text(mentor['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mentor['expertise'] ?? 'No expertise listed'),
                          Text(
                            mentor['bio'] ?? 'No bio available',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MentorDetailScreen(
                              mentorId: mentorId,
                              mentorName: mentor['name'] ?? 'Unknown',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
