import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final TextEditingController _groupCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinTrip() async {
    final groupCode = _groupCodeController.text.trim().toUpperCase();
    if (groupCode.length != 6 || !RegExp(r'^[A-Z0-9]+\$').hasMatch(groupCode)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid group code')));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    final docRef = FirebaseFirestore.instance.collection('trips').doc(groupCode);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip not found!')));
        setState(() => _isLoading = false);
        return;
      }

      final members = List<String>.from(snapshot['members']);
      if (!members.contains(user?.uid)) {
        await docRef.update({ 'members': FieldValue.arrayUnion([user?.uid]) });
      }

      // Save trip code locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastTripCode', groupCode);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully joined trip!')));
      Navigator.popUntil(context, ModalRoute.withName('/'));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Trip")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _groupCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Enter Group Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _joinTrip,
              child: const Text("Join"),
            ),
          ],
        ),
      ),
    );
  }
}
