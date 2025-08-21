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
      // storageBucket: "ratemylunch-2270c.firebasestorage.app",
      storageBucket: "ratemylunch-2270c.appspot.com",
      messagingSenderId: "702467284612",
      appId: "1:702467284612:web:50bbc8b5d93397966eacd1",
      measurementId: "G-X2G80G0F26",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rate My Lunch',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const LunchPage(),
    );
  }
}

class LunchPage extends StatefulWidget {
  const LunchPage({super.key});

  @override
  LunchPageState createState() => LunchPageState();
}

class LunchPageState extends State<LunchPage> {
  int rating = 5;
  String description = '';
  Uint8List? imageBytes;
  bool isLoading = false;
  final userId = "user1"; // Replace with actual user identifier if needed

  // Upload image and save entry
  Future<void> submitEntry() async {
    print('----- Starting submit');

    if (imageBytes == null) {
      print('----- No image');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() {
      print('----- setting loading state');
      isLoading = true;
    });

    try {
      print('----- Attempting to upload data');

      final fileName = 'lunch_images/${DateTime.now().toIso8601String()}_$userId.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(imageBytes!);
      final imageUrl = await ref.getDownloadURL();

      final date = DateTime.now().toIso8601String().split('T')[0];

      await FirebaseFirestore.instance.collection('lunch_entries').add({
        'user': userId,
        'date': date,
        'rating': rating,
        'description': description,
        'image_url': imageUrl,
      });

      // Reset form
      setState(() {
        print('----- Resetting form');

        rating = 5;
        description = '';
        imageBytes = null;
      });

      print('----- Finished submit');
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error uploading entry')));
    }

    setState(() => isLoading = false);
  }

  // Pick image
  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        imageBytes = result.files.first.bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    return Scaffold(
      appBar: AppBar(title: const Text('Rate My Lunch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Upload form
            const Text('Upload your lunch', style: TextStyle(fontSize: 20)),
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

            // Display past 7 days entries
            const Text('Recent Lunches', style: TextStyle(fontSize: 20)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lunch_entries')
                  .where('date', isGreaterThanOrEqualTo: sevenDaysAgo.toIso8601String().split('T')[0])
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No entries yet.');

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Image.network(data['image_url'], width: 50),
                        title: Text('${data['user']} - Rating: ${data['rating']}'),
                        subtitle: Text('${data['description']}\nDate: ${data['date']}'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
