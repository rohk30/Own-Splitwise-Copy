import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> registerUser({
    required String email,
    required String password,
    required String name,
    required bool isAdmin,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await user.sendEmailVerification();

        await _db
            .collection(isAdmin ? "admins" : "consumers")
            .doc(user.uid)
            .set({
          "name": name,
          "email": email,
          "verified": false,
          "createdAt": DateTime.now(),
        });
      }
      return user;
    } catch (e) {
      throw Exception("Registration failed: $e");
    }
  }

  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null && !user.emailVerified) {
        await _auth.signOut();
        throw Exception("Please verify your email before logging in.");
      }
      return user;
    } catch (e) {
      throw Exception("Login failed: $e");
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
