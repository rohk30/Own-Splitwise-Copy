/*
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
    if (groupCode.length != 6 || !RegExp(r'^[A-Z0-9]+$').hasMatch(groupCode)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid group code')));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "Unnamed";
    final docRef = FirebaseFirestore.instance.collection('trips').doc(groupCode);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip not found!')));
        setState(() => _isLoading = false);
        return;
      }

      final data = snapshot.data()!;
      final members = List<String>.from(data['members'] ?? []);
      final memberDetails = Map<String, dynamic>.from(data['memberDetails'] ?? {});

      if (!members.contains(user!.uid)) {
        await docRef.update({
          'members': FieldValue.arrayUnion([user.uid]),
          'memberDetails.${user.uid}': {
            'name': userName,
          }
        });
      } else if (!memberDetails.containsKey(user.uid)) {
        await docRef.update({
          'memberDetails.${user.uid}': {
            'name': userName,
          }
        });
      }

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
 */
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _groupCodeController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _groupCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinTrip() async {
    final groupCode = _groupCodeController.text.trim().toUpperCase();
    if (groupCode.length != 6 || !RegExp(r'^[A-Z0-9]+$').hasMatch(groupCode)) {
      _showSnackBar('Please enter a valid 6-character group code', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "Unnamed";
    final docRef = FirebaseFirestore.instance.collection('trips').doc(groupCode);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        _showSnackBar('Trip not found! Please check your code.', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final data = snapshot.data()!;
      final members = List<String>.from(data['members'] ?? []);
      final memberDetails = Map<String, dynamic>.from(data['memberDetails'] ?? {});

      if (!members.contains(user!.uid)) {
        await docRef.update({
          'members': FieldValue.arrayUnion([user.uid]),
          'memberDetails.${user.uid}': {
            'name': userName,
          }
        });
      } else if (!memberDetails.containsKey(user.uid)) {
        await docRef.update({
          'memberDetails.${user.uid}': {
            'name': userName,
          }
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastTripCode', groupCode);

      _showSnackBar('Successfully joined trip! 🎉', isError: false);

      // Small delay for better UX
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.popUntil(context, ModalRoute.withName('/'));
      }
    } catch (e) {
      _showSnackBar('Error joining trip: ${e.toString()}', isError: true);
    }

    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? Colors.red.shade600
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background matching home screen
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.5),
                radius: 1.2,
                colors: [
                  Color(0xFF1A2980),
                  Color(0xFF26D0CE),
                  Color(0xFF1A2980),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Join Trip',
                        style: GoogleFonts.poppins(
                          textStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),

                            // Header
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.group_add_outlined,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Enter Trip Code',
                                    style: GoogleFonts.poppins(
                                      textStyle: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ask your friend for the 6-character trip code',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 60),

                            // Input Field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: TextField(
                                controller: _groupCodeController,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 4,
                                ),
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                decoration: InputDecoration(
                                  hintText: 'ABC123',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 4,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.all(20),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.qr_code,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Join Button
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFf093fb).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _joinTrip,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : Text(
                                    'Join Trip',
                                    style: GoogleFonts.poppins(
                                      textStyle: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Help Text
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Trip codes are case-insensitive and contain 6 characters',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Add bottom padding for keyboard
                            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 50),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}