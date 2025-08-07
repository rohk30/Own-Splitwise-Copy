import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:own_splitwise_copy/screens/auth/register_view.dart';

import '../../auth_gate.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true; // For password visibility toggle

  Future<String?> _promptForName() async {
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter your name'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Your name'),
            onChanged: (value) => name = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, name),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final credential =  await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if(user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final snapshot = await userDoc.get();

        if(!snapshot.exists || !snapshot.data()!.containsKey('name')) {
          final name = await _promptForName();
          if (name != null && name.trim().isNotEmpty) {
            await userDoc.set({
              'email': user.email ?? '',
              'name': name.trim(),
              'trips': [],
            }, SetOptions(merge: true));
          }
          // await userDoc.set({
          //   'email': user.email ?? '',
          //   'trips': [],
          // });
        }
      }

      // 🔄 Navigate to AuthGate to re-evaluate login state
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _signIn,
              child: const Text("Login"),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterView()),
              ),
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}