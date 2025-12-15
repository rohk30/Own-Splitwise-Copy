import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _filterByCreated = false;

  late AnimationController _fadeController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _listAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _listController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // -------------------- FIRESTORE HELPERS --------------------

  Future<List<DocumentSnapshot>> _fetchTripsByIds(List<String> tripIds) async {
    if (tripIds.isEmpty) return [];

    final futures = tripIds
        .map((id) => _firestore.collection('trips').doc(id).get())
        .toList();

    final snapshots = await Future.wait(futures);
    return snapshots.where((doc) => doc.exists).toList();
  }

  // -------------------- UI HELPERS --------------------

  void _copyGroupCode(String groupCode) {
    Clipboard.setData(ClipboardData(text: groupCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            const Text("Group code copied!"),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // -------------------- MAIN BUILD --------------------

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  "Please log in to view your trips",
                  style: GoogleFonts.poppins(
                    textStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final uid = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(),

            // Trips List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('users').doc(uid).snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Loading your trips..."),
                        ],
                      ),
                    );
                  }

                  if (userSnapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading trips',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${userSnapshot.error}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return Center(
                      child: Text(
                        "User data not found",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  }

                  final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
                  final List<String> tripIds =
                  List<String>.from(userData['trips'] ?? []);

                  if (tripIds.isEmpty) {
                    return _buildEmptyTripsUI();
                  }

                  return FutureBuilder<List<DocumentSnapshot>>(
                    future: _fetchTripsByIds(tripIds),
                    builder: (context, tripSnapshot) {
                      if (tripSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text("Loading your trips..."),
                            ],
                          ),
                        );
                      }

                      if (tripSnapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading trips',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${tripSnapshot.error}',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      if (!tripSnapshot.hasData || tripSnapshot.data!.isEmpty) {
                        return _buildEmptyTripsUI();
                      }

                      final trips = tripSnapshot.data!;
                      final filteredTrips = _filterByCreated
                          ? trips.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['createdBy'] == uid;
                      }).toList()
                          : trips;

                      if (filteredTrips.isEmpty && _filterByCreated) {
                        return _buildNoCreatedTripsUI();
                      }

                      return _buildTripsList(filteredTrips, uid);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- HEADER --------------------

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.blue.shade600,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Trips',
                        style: GoogleFonts.poppins(
                          textStyle: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        'Manage your travel expenses',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Filter Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _filterByCreated = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_filterByCreated
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_filterByCreated
                              ? [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Text(
                          'All Trips',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !_filterByCreated
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _filterByCreated = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _filterByCreated
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _filterByCreated
                              ? [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Text(
                          'Created by Me',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _filterByCreated
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
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
      ),
    );
  }

  // -------------------- EMPTY STATES --------------------

  Widget _buildEmptyTripsUI() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              "No trips yet",
              style: GoogleFonts.poppins(
                textStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Create your first trip or join\none using a group code",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/createTrip'),
              icon: const Icon(Icons.add),
              label: const Text('Create Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCreatedTripsUI() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.create_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              "No trips created by you",
              style: GoogleFonts.poppins(
                textStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Start by creating your first trip",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- TRIPS LIST --------------------

  Widget _buildTripsList(List<DocumentSnapshot> trips, String uid) {
    return FadeTransition(
      opacity: _listAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          final tripData = trip.data() as Map<String, dynamic>;
          final tripName = tripData['tripName'] ?? 'Unnamed Trip';
          final groupCode = trip.id;
          final isCreatedByUser = tripData['createdBy'] == uid;

          // Balance calculation logic
          final Map<String, dynamic>? overallOwesRaw = tripData['overallOwes'];
          final Map<String, Map<String, double>> overallOwes = {};

          if (overallOwesRaw != null && overallOwesRaw.isNotEmpty) {
            overallOwesRaw.forEach((fromUid, payeesRaw) {
              if (payeesRaw is Map) {
                final Map<String, double> payeesTyped = {};
                payeesRaw.forEach((toUid, amountRaw) {
                  payeesTyped[toUid.toString()] =
                      (amountRaw as num?)?.toDouble() ?? 0.0;
                });
                overallOwes[fromUid] = payeesTyped;
              }
            });
          }

          bool hasOutstandingBalance = false;
          bool currentUserHasOutstandingBalance = false;

          overallOwes.forEach((fromUid, payees) {
            payees.forEach((toUid, amount) {
              if (amount > 0.001) {
                hasOutstandingBalance = true;
                if (fromUid == uid || toUid == uid) {
                  currentUserHasOutstandingBalance = true;
                }
              }
            });
          });

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/tripDetails',
                    arguments: groupCode,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Trip Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCreatedByUser
                                  ? Colors.purple.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCreatedByUser
                                  ? Icons.star_outline
                                  : Icons.group_outlined,
                              color: isCreatedByUser
                                  ? Colors.purple.shade600
                                  : Colors.blue.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Trip Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tripName,
                                  style: GoogleFonts.poppins(
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Code: $groupCode',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _copyGroupCode(groupCode),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                          BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Status Indicator
                          if (hasOutstandingBalance &&
                              currentUserHasOutstandingBalance)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pending',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (hasOutstandingBalance)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'You\'re settled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'All settled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Owner indicator
                      if (isCreatedByUser) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.purple.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 14,
                                color: Colors.purple.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Trip Owner',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.purple.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _filterByCreated = false;

  late AnimationController _fadeController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutCubic,
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _listController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // -------------------- FIRESTORE HELPERS --------------------

  Future<List<DocumentSnapshot>> _fetchTripsByIds(List<String> tripIds) async {
    if (tripIds.isEmpty) return [];

    final futures = tripIds
        .map((id) => _firestore.collection('trips').doc(id).get())
        .toList();

    final snapshots = await Future.wait(futures);
    return snapshots.where((doc) => doc.exists).toList();
  }

  // -------------------- UI HELPERS --------------------

  void _copyGroupCode(String groupCode) {
    Clipboard.setData(ClipboardData(text: groupCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text("Group code copied!"),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEmptyTripsUI() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              "No trips yet",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Create your first trip or join one using a group code",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCreatedTripsUI() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.create_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              "No trips created by you",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- MAIN BUILD --------------------

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please login")),
      );
    }

    final uid = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('users').doc(uid).snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const Center(child: Text("User data not found"));
                  }

                  final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
                  final List<String> tripIds =
                  List<String>.from(userData['trips'] ?? []);

                  if (tripIds.isEmpty) {
                    return _buildEmptyTripsUI();
                  }

                  return FutureBuilder<List<DocumentSnapshot>>(
                    future: _fetchTripsByIds(tripIds),
                    builder: (context, tripSnapshot) {
                      if (tripSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      if (!tripSnapshot.hasData ||
                          tripSnapshot.data!.isEmpty) {
                        return _buildEmptyTripsUI();
                      }

                      final trips = tripSnapshot.data!;
                      final filteredTrips = _filterByCreated
                          ? trips.where((doc) {
                        final data =
                        doc.data() as Map<String, dynamic>;
                        return data['createdBy'] == uid;
                      }).toList()
                          : trips;

                      if (filteredTrips.isEmpty && _filterByCreated) {
                        return _buildNoCreatedTripsUI();
                      }

                      return _buildTripsList(filteredTrips, uid);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- HEADER --------------------

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                Text(
                  'My Trips',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton("All Trips", false),
                ),
                Expanded(
                  child: _buildFilterButton("Created by Me", true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String text, bool created) {
    final selected = _filterByCreated == created;
    return GestureDetector(
      onTap: () => setState(() => _filterByCreated = created),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  // -------------------- TRIPS LIST --------------------

  Widget _buildTripsList(List<DocumentSnapshot> trips, String uid) {
    return FadeTransition(
      opacity: _listAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          final data = trip.data() as Map<String, dynamic>;
          final tripName = data['tripName'] ?? 'Unnamed Trip';
          final isOwner = data['createdBy'] == uid;

          return ListTile(
            title: Text(tripName),
            subtitle: Text("Code: ${trip.id}"),
            trailing:
            isOwner ? const Icon(Icons.star, color: Colors.purple) : null,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/tripDetails',
                arguments: trip.id,
              );
            },
            onLongPress: () => _copyGroupCode(trip.id),
          );
        },
      ),
    );
  }
}

 */



/*
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  bool _filterByCreated = false;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    // Ensure the user is logged in. If not, handle it gracefully.
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Trips")),
        body: const Center(child: Text("Please log in to view your trips.")),
      );
    }
    final uid = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Trips"),
        actions: [
          Row(
            children: [
              const Text("Created Only"),
              Switch(
                value: _filterByCreated,
                onChanged: (val) {
                  setState(() => _filterByCreated = val);
                },
              ),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Use a Firestore query to filter by 'members' array for efficiency
        stream: _firestore
            .collection('trips')
            .where('members', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("You're not part of any trips yet."));
          }

          final trips = snapshot.data!.docs;

          // Apply the 'filterByCreated' logic if enabled
          final filteredTrips = _filterByCreated
              ? trips.where((doc) => (doc.data() as Map<String, dynamic>)['createdBy'] == uid).toList()
              : trips;

          if (filteredTrips.isEmpty && _filterByCreated) {
            return const Center(child: Text("No trips created by you found."));
          }
          if (filteredTrips.isEmpty) { // This case should be covered by the initial !snapshot.hasData, but as a fallback
            return const Center(child: Text("No trips found."));
          }


          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filteredTrips.length,
            itemBuilder: (context, index) {
              final trip = filteredTrips[index];
              final tripData = trip.data() as Map<String, dynamic>; // Explicitly cast to Map

              final tripName = tripData['tripName'] ?? 'Unnamed Trip';
              final groupCode = trip.id;

              // Safely access and parse overallOwes, handling null and nested types
              final Map<String, dynamic>? overallOwesRaw = tripData['overallOwes'];

              // This is the robust parsing logic for overallOwes
              final Map<String, Map<String, double>> overallOwes = {};
              if (overallOwesRaw != null && overallOwesRaw.isNotEmpty) {
                overallOwesRaw.forEach((fromUid, payeesRaw) {
                  if (payeesRaw is Map) {
                    final Map<String, double> payeesTyped = {};
                    payeesRaw.forEach((toUid, amountRaw) {
                      payeesTyped[toUid.toString()] = (amountRaw as num?)?.toDouble() ?? 0.0;
                    });
                    overallOwes[fromUid] = payeesTyped;
                  }
                });
              }

              // --- Balance Status Logic ---
              bool hasOutstandingBalance = false; // Does this trip have ANY outstanding balances?
              bool currentUserHasOutstandingBalance = false; // Is the current user involved in any outstanding balance?

              overallOwes.forEach((fromUid, payees) {
                payees.forEach((toUid, amount) {
                  if (amount > 0.001) { // Check for meaningful amounts (floating point precision)
                    hasOutstandingBalance = true; // Yes, there's at least one balance
                    if (fromUid == uid || toUid == uid) {
                      currentUserHasOutstandingBalance = true; // Yes, current user is involved
                    }
                  }
                });
              });

              Widget trailingWidget;

              // if (!hasOutstandingBalance) {
              //   // Case 1: The entire trip has no outstanding balances (everyone is settled up with everyone)
              //   trailingWidget = const Icon(Icons.verified, color: Colors.green, semanticLabel: 'All settled');
              // } else if (!currentUserHasOutstandingBalance) {
              //   // Case 2: The trip has outstanding balances, but the current user is not involved in any of them
              //   trailingWidget = const Text("You're settled", style: TextStyle(color: Colors.green));
              // } else {
                // Case 3: The trip has outstanding balances, and the current user is involved in one
                trailingWidget = IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy Group Code', // Good for UX
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: groupCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Group code copied!")),
                    );
                  },
                );
              // }

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    tripName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Group Code: $groupCode"),
                      // Only show this warning if there are balances AND the current user is involved
                      if (hasOutstandingBalance && currentUserHasOutstandingBalance)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Outstanding balance!",
                            style: TextStyle(color: Colors.red, fontSize: 12.0),
                          ),
                        ),
                    ],
                  ),
                  trailing: trailingWidget,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/tripDetails', // Make sure this route is correctly defined in your main.dart
                      arguments: groupCode,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
*/