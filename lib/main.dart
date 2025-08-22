import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBxuNHhZdedxLnetQqQ8evQGOLph29ixqs",
      authDomain: "ratemylunch-2270c.firebaseapp.com",
      projectId: "ratemylunch-2270c",
      storageBucket: "ratemylunch-2270c.firebasestorage.app",
      messagingSenderId: "702467284612",
      appId: "1:702467284612:web:50bbc8b5d93397966eacd1",
      measurementId: "G-X2G80G0F26",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rate My Lunch',
      theme: isDarkMode ? ThemeData.dark() : ThemeData(primarySwatch: Colors.orange),
      home: LunchPage(
        isDarkMode: isDarkMode,
        onThemeToggle: () => setState(() => isDarkMode = !isDarkMode),
      ),
    );
  }
}

class LunchPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const LunchPage({super.key, required this.isDarkMode, required this.onThemeToggle});

  @override
  LunchPageState createState() => LunchPageState();
}

class LunchPageState extends State<LunchPage> {
  int rating = 5;
  String description = '';
  Uint8List? imageBytes;
  bool isLoading = false;
  String userId = 'user1';
  DateTime? selectedDate;

  // Track selected entries for average calculation
  final Set<String> selectedEntries = {};

  Future<void> submitEntry() async {
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final fileName = 'lunch_images/${DateTime.now().toIso8601String()}_$userId.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(imageBytes!);
      final imageUrl = await ref.getDownloadURL();

      final date = (selectedDate ?? DateTime.now()).toIso8601String().split('T')[0];

      await FirebaseFirestore.instance.collection('lunch_entries').add({
        'user': userId,
        'date': date,
        'rating': rating,
        'description': description,
        'image_url': imageUrl,
      });

      setState(() {
        rating = 5;
        description = '';
        imageBytes = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error uploading entry')));
    }

    setState(() => isLoading = false);
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        imageBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  void showEntryDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${data['user']} - Rating: ${data['rating']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 5,
              child: Image.network(data['image_url'], height: 200),
            ),
            const SizedBox(height: 10),
            Text(data['description']),
            const SizedBox(height: 10),
            Text('Date: ${data['date']}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    final filterDate = selectedDate ?? today;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate My Lunch'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.nights_stay : Icons.wb_sunny),
            onPressed: widget.onThemeToggle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Your Username'),
              onChanged: (val) => userId = val,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: pickDate,
                  child: Text('Date: ${filterDate.toIso8601String().split('T')[0]}'),
                ),
                if (selectedDate != null)
                  IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => selectedDate = null)),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: pickImage,
              child: Text(imageBytes == null ? 'Pick Image' : 'Change Image'),
            ),
            if (imageBytes != null) Image.memory(imageBytes!, height: 150, width: 150),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (val) => description = val,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              children: List.generate(10, (index) {
                final number = index + 1;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: rating == number ? Colors.orange : null),
                  onPressed: () => setState(() => rating = number),
                  child: Text(number.toString()),
                );
              }),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isLoading ? null : submitEntry,
              child: Text(isLoading ? 'Uploading...' : 'Submit'),
            ),
            const SizedBox(height: 30),
            const Text('Lunches', style: TextStyle(fontSize: 20)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lunch_entries')
                  .where('date', isGreaterThanOrEqualTo: sevenDaysAgo.toIso8601String().split('T')[0])
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) return const Text('No entries yet.');

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['date'] == filterDate.toIso8601String().split('T')[0];
                }).toList();

                // Sort by rating descending
                filteredDocs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  return (dataB['rating'] as int).compareTo(dataA['rating'] as int);
                });

                // Calculate average based on selected entries
                double averageRating = 0;
                final selectedDocs = filteredDocs.where((doc) => selectedEntries.contains(doc.id)).toList();
                if (selectedDocs.isNotEmpty) {
                  final total = selectedDocs.fold<int>(0, (sum, doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return sum + (data['rating'] as int);
                  });
                  averageRating = total / selectedDocs.length;
                }

                return Column(
                  children: [
                    Text('Average Rating: ${averageRating.toStringAsFixed(1)} / 10',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('(Select lunches to claculate average rating.)'),
                    const Text('(Long click on lunch to open details.)'),
                    const SizedBox(height: 10),
                    ...filteredDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isSelected = selectedEntries.contains(doc.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: isSelected ? Colors.orange[100] : null,
                        child: ListTile(
                          leading: Image.network(data['image_url'], width: 50, height: 50, fit: BoxFit.cover),
                          title: Text('${data['user']} - Rating: ${data['rating']}'),
                          subtitle: Text('${data['description']}\nDate: ${data['date']}'),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedEntries.remove(doc.id);
                              } else {
                                selectedEntries.add(doc.id);
                              }
                            });
                          },
                          onLongPress: () => showEntryDetails(data),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
