import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:own_splitwise_copy/auth_gate.dart';
import 'package:own_splitwise_copy/screens/home_screen.dart';
import 'package:own_splitwise_copy/screens/trip_screens/join_trip_screen.dart';
import 'package:own_splitwise_copy/screens/trip_screens/my_trips_view.dart';
import 'package:own_splitwise_copy/screens/trip_screens/trip_details_screen.dart';
import 'package:own_splitwise_copy/screens/trip_screens/create_trip_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Splitter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(), // You can dynamically pass user later
      routes: {
        '/createTrip': (context) => const CreateTripScreen(),
        '/joinTrip': (context) => const JoinTripScreen(),
        '/myTrips': (context) => const MyTripsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/tripDetails') {
          final groupCode = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => TripDetailsScreen(groupCode: groupCode),
          );
        }
        return null;
      },
    );
  }
}