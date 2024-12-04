import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

class MenteeResourcesTab extends StatefulWidget {
  const MenteeResourcesTab({super.key});

  @override
  State<MenteeResourcesTab> createState() => _MenteeResourcesTabState();
}

class _MenteeResourcesTabState extends State<MenteeResourcesTab> {
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadedFilePaths = {};
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Academic', 'Career', 'Personal Development'];

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw 'Storage permission denied';
      }

      // Get the downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Check if file already exists
      if (await File(filePath).exists()) {
        _downloadedFilePaths[url] = filePath;
        _openFile(filePath);
        return;
      }

      // Start download
      setState(() {
        _downloadProgress[url] = 0;
      });

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[url] = received / total;
            });
          }
        },
      );

      _downloadedFilePaths[url] = filePath;
      _openFile(filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _downloadProgress.remove(url);
      });
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw result.message;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildResourceTypeIcon(String fileType) {
    IconData iconData;
    Color iconColor;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'ppt':
      case 'pptx':
        iconData = Icons.slideshow;
        iconColor = Colors.orange;
        break;
      case 'txt':
        iconData = Icons.text_snippet;
        iconColor = Colors.grey;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Icon(
      iconData,
      color: iconColor,
      size: 40,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category Filter
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Text(
                'Category: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Resources List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('resources')
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              var resources = snapshot.data?.docs ?? [];

              // Filter by category
              if (_selectedCategory != 'All') {
                resources = resources.where((doc) {
                  final resource = doc.data() as Map<String, dynamic>;
                  return resource['category'] == _selectedCategory;
                }).toList();
              }

              if (resources.isEmpty) {
                return Center(
                  child: Text(
                    _selectedCategory == 'All'
                        ? 'No resources available\nCheck back later!'
                        : 'No resources in $_selectedCategory category',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: resources.length,
                itemBuilder: (context, index) {
                  final resource = resources[index].data() as Map<String, dynamic>;
                  final fileName = resource['fileName'] as String;
                  final fileUrl = resource['fileUrl'] as String;
                  final fileType = resource['fileType'] as String;
                  final uploadDate = (resource['uploadedAt'] as Timestamp).toDate();
                  final description = resource['description'] as String?;
                  final category = resource['category'] as String?;
                  final mentorId = resource['mentorId'] as String;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(mentorId)
                        .get(),
                    builder: (context, mentorSnapshot) {
                      final mentorName = mentorSnapshot.data?.get('name') as String? ?? 'Unknown Mentor';

                      return Card(
                        child: ListTile(
                          leading: _buildResourceTypeIcon(fileType),
                          title: Text(fileName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shared by $mentorName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Uploaded on ${DateFormat('MMM dd, yyyy').format(uploadDate)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              if (description != null && description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (category != null && category.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Chip(
                                    label: Text(
                                      category,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.grey[200],
                                  ),
                                ),
                              if (_downloadProgress.containsKey(fileUrl))
                                LinearProgressIndicator(
                                  value: _downloadProgress[fileUrl],
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                            ],
                          ),
                          trailing: _downloadedFilePaths.containsKey(fileUrl)
                              ? IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () => _openFile(_downloadedFilePaths[fileUrl]!),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _downloadFile(fileUrl, fileName),
                                ),
                        ),
                      );
                    },
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
