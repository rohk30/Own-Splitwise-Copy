import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final TextEditingController _tripNameController = TextEditingController();
  bool _isLoading = false;

  String generateGroupCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _createTrip() async {
    final tripName = _tripNameController.text.trim();
    if (tripName.isEmpty) return;

    setState(() => _isLoading = true);

    final groupCode = generateGroupCode();
    final user = FirebaseAuth.instance.currentUser;

    final tripData = {
      'tripName': tripName,
      'createdBy': user?.uid,
      'createdAt': Timestamp.now(),
      'members': [user?.uid],
    };

    try {
      await FirebaseFirestore.instance.collection('trips').doc(groupCode).set(tripData);

      // Save trip locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastTripCode', groupCode);

      // Show group code with share/copy options
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Trip Created!"),
          content: Text("Group Code: $groupCode"),
          actions: [
            TextButton(
              onPressed: () => Share.share("Join my TripSplit trip using this code: $groupCode"),
              child: const Text("Share"),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: groupCode));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copied to clipboard")));
              },
              child: const Text("Copy"),
            ),
            TextButton(
              onPressed: () => Navigator.popUntil(context, ModalRoute.withName('/')),
              child: const Text("Done"),
            )
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Trip")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _tripNameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _createTrip,
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }
}