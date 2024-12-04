import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  String _category = 'Academic';
  List<PlatformFile> _selectedFiles = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<String>> _uploadFiles() async {
    List<String> uploadedFileUrls = [];

    for (PlatformFile file in _selectedFiles) {
      if (file.path != null) {
        final fileName = path.basename(file.path!);
        final destination = 'resources/${_titleController.text}/$fileName';
        
        try {
          final ref = _storage.ref(destination);
          final uploadTask = ref.putData(
            file.bytes!,
            SettableMetadata(contentType: 'application/${path.extension(fileName).replaceAll('.', '')}'),
          );

          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();
          uploadedFileUrls.add(downloadUrl);
        } catch (e) {
          throw Exception('Failed to upload file: $fileName');
        }
      }
    }

    return uploadedFileUrls;
  }

  Future<void> _uploadResource() async {
    if (!mounted) return;

    if (_formKey.currentState!.validate() && _selectedFiles.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        final resourceUrls = await _uploadFiles();

        await _firestore.collection('resources').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _category,
          'createdAt': FieldValue.serverTimestamp(),
          'files': resourceUrls.map((url) => {
            'url': url,
            'name': _selectedFiles.firstWhere(
              (file) => url.contains(path.basename(file.path ?? '')),
              orElse: () => PlatformFile(name: 'unknown', size: 0),
            ).name,
          }).toList(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resource uploaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Clear form
        _formKey.currentState!.reset();
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          _category = 'Academic';
          _selectedFiles = [];
        });
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload resource: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resource Upload Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Upload New Resource',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        controller: _titleController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        value: _category,
                        onChanged: (String? newValue) {
                          setState(() {
                            _category = newValue!;
                          });
                        },
                        items: <String>['Academic', 'Career', 'Personal Development']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        controller: _descriptionController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickFiles,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Select Files'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            return ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(file.name),
                              subtitle: Text('${(file.size / 1024).toStringAsFixed(2)} KB'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.removeAt(index);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _uploadResource,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Upload Resource'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // List of Uploaded Resources
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('resources')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Something went wrong');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final resources = snapshot.data!.docs;

                if (resources.isEmpty) {
                  return const Center(
                    child: Text('No resources uploaded yet'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    final resource = resources[index].data() as Map<String, dynamic>;
                    final files = (resource['files'] as List<dynamic>)
                        .map((file) => file as Map<String, dynamic>)
                        .toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(resource['title'] ?? 'Untitled'),
                        subtitle: Text(resource['category'] ?? 'No category'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(resource['description'] ?? 'No description'),
                                const SizedBox(height: 8),
                                const Divider(),
                                const Text(
                                  'Files:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: files.length,
                                  itemBuilder: (context, fileIndex) {
                                    return ListTile(
                                      leading: const Icon(Icons.file_present),
                                      title: Text(files[fileIndex]['name'] ?? 'Unknown file'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.download),
                                        onPressed: () {
                                          // TODO: Implement file download
                                          // Launch URL in browser for now
                                          // You can implement proper download later
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
