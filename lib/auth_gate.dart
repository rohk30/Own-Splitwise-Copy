import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_view.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String?> _getUserName(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data()?['name'];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;

          // 🔁 Get name from Firestore and show HomeScreen
          return FutureBuilder<String?>(
            future: _getUserName(uid),
            builder: (context, nameSnapshot) {
              if (nameSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userName = nameSnapshot.data ?? snapshot.data!.email;

              return HomeScreen(userName: userName);
            },
          );
        }

        return const LoginView();
      },
    );
  }
}


// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasData) {
//           return HomeScreen(userName: snapshot.data?.email); // Already logged in
//         }
//         return const LoginView(); // Show login page
//       },
//     );
//   }
// }
