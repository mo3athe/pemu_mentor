import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

class MentorResourcesScreen extends StatefulWidget {
  final String mentorId;
  final String mentorName;

  const MentorResourcesScreen({
    super.key,
    required this.mentorId,
    required this.mentorName,
  });

  @override
  State<MentorResourcesScreen> createState() => _MentorResourcesScreenState();
}

class _MentorResourcesScreenState extends State<MentorResourcesScreen> {
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadedFilePaths = {};

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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.mentorName}\'s Resources'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('resources')
            .where('mentorId', isEqualTo: widget.mentorId)
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

          final resources = snapshot.data?.docs ?? [];

          if (resources.isEmpty) {
            return const Center(
              child: Text(
                'No resources available\nCheck back later!',
                textAlign: TextAlign.center,
                style: TextStyle(
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

              return Card(
                child: ListTile(
                  leading: _buildResourceTypeIcon(fileType),
                  title: Text(fileName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
      ),
    );
  }
}
