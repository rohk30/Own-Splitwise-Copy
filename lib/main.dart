import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:own_splitwise_copy/auth_gate.dart';
import 'package:own_splitwise_copy/screens/trip_screens/join_trip_screen.dart';
import 'package:own_splitwise_copy/screens/trip_screens/my_trips_view.dart';
import 'package:own_splitwise_copy/screens/trip_screens/create_trip_screen.dart';
import 'package:own_splitwise_copy/screens/trip_screens/trip_details/trip_details_screen.dart';

import 'migrate_user_trips.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔥 ONE-TIME MIGRATION (RUN NOW)
  try {
    await migrateUserTrips();
    debugPrint("✅ User–Trip migration completed successfully");
  } catch (e, st) {
    debugPrint("❌ Migration failed: $e");
    debugPrintStack(stackTrace: st);
  }

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
      home: const AuthGate(),
      routes: {
        '/createTrip': (context) => const CreateTripScreen(),
        '/joinTrip': (context) => const JoinTripScreen(),
        '/myTrips': (context) => const MyTripsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/tripDetails') {
          final groupCode = settings.arguments as String;

          return MaterialPageRoute(
            builder: (context) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('trips')
                    .doc(groupCode)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Scaffold(
                      body: Center(child: Text("Trip not found")),
                    );
                  }

                  final data =
                  snapshot.data!.data() as Map<String, dynamic>;
                  final members =
                  List<String>.from(data['members'] ?? []);

                  return TripDetailsScreen(
                    groupCode: groupCode,
                    members: members,
                  );
                },
              );
            },
          );
        }
        return null;
      },
    );
  }
}


/*
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'HackScreens/Admin Side/admin_dashboard.dart';
import 'HackScreens/Authentication/login_screen.dart';
import 'HackScreens/Customer Side/customer_dashboard.dart';

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
      title: 'Smart Rental Tracking System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const RoleSelectionScreen(),
        '/customer': (context) => const CustomerDashboard(),  // <-- FIXED
        '/admin': (context) => const CustomerDashboard(),        // <-- FIXED
        '/loginCustomer': (context) => const LoginScreen(isAdmin: false),
        '/loginAdmin': (context) => const AdminDashboard(),
      },
    );
  }
}

/// First screen to choose role (Customer/Admin)
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Rental System")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/loginCustomer'),
              icon: const Icon(Icons.person),
              label: const Text("Customer App"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/loginAdmin'),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text("Admin App"),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for Customer App
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customer Dashboard")),
      body: const Center(
        child: Text(
          "Customer Home Screen\n(Equipment Booking, Usage Logging, etc.)",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Placeholder for Admin App
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: const Center(
        child: Text(
          "Admin Home Screen\n(Asset Tracking, Reports, Alerts, etc.)",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
} */

/*
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'HackScreens/Admin Side/admin_dashboard.dart';
import 'HackScreens/Authentication/login_screen.dart';
import 'HackScreens/Customer Side/customer_dashboard.dart';

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
      title: 'Smart Rental Tracking System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // cardTheme:
        //   elevation: 0,
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(16),
        //   ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const RoleSelectionScreen(),
        '/customer': (context) => const CustomerDashboard(),
        '/admin': (context) => const AdminDashboard(), // Fixed: was pointing to CustomerDashboard
        '/loginCustomer': (context) => const LoginScreen(isAdmin: false),
        '/loginAdmin': (context) => const AdminDashboard(), // Fixed: was pointing to AdminDashboard
      },
    );
  }
}

/// Enhanced Role Selection Screen with modern UI
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Logo/Icon Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.home_repair_service,
                    size: 48,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),

                const SizedBox(height: 32),

                // Title Section
                Text(
                  'Smart Rental\nTracking System',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  'Choose your role to get started',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                // Role Selection Cards
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoleCard(
                        icon: Icons.person_outline,
                        title: 'Customer',
                        subtitle: 'Rent and track your items',
                        color: theme.colorScheme.primary,
                        onTap: () => Navigator.pushNamed(context, '/loginCustomer'),
                      ),

                      const SizedBox(height: 24),

                      _RoleCard(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Admin',
                        subtitle: 'Manage rentals and inventory',
                        color: theme.colorScheme.secondary,
                        onTap: () => Navigator.pushNamed(context, '/loginAdmin'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) {
              _controller.reverse();
              widget.onTap();
            },
            onTapCancel: () => _controller.reverse(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.color.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 32,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} */
