import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard

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

/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final uid = _auth.currentUser!.uid;

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
        stream: _firestore
            .collection('trips')
            .where('members', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final trips = snapshot.data?.docs ?? [];

          final filtered = _filterByCreated
              ? trips.where((doc) => doc['createdBy'] == uid).toList()
              : trips;

          if (filtered.isEmpty) {
            return const Center(child: Text("No trips found"));
          }

          /*
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final trip = filtered[index];
              final tripName = trip['tripName'] ?? 'Unnamed Trip';
              final groupCode = trip.id;
              final Map<String, dynamic>? overallOwes = trip['overallOwes']?.cast<String, dynamic>();

              bool allSettled = true;
              bool userInvolved = false;

              if (overallOwes != null && overallOwes.isNotEmpty) {
                for (final fromUid in overallOwes.keys) {
                  final payees = Map<String, dynamic>.from(overallOwes[fromUid]);
                  for (final toUid in payees.keys) {
                    final amount = (payees[toUid] as num?)?.toDouble() ?? 0.0;
                    if (amount > 0.001) {
                      allSettled = false;
                      if (fromUid == uid || toUid == uid) {
                        userInvolved = true;
                      }
                    }
                  }
                }
              }

              Widget trailingWidget;
              if (allSettled) {
                trailingWidget = const Icon(Icons.check_circle, color: Colors.green);
              } else if (!userInvolved) {
                trailingWidget = const Text("✔ You are settled up", style: TextStyle(color: Colors.green));
              } else {
                trailingWidget = IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: groupCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Group code copied!")),
                    );
                  },
                );
              }

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    tripName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Group Code: $groupCode"),
                  trailing: trailingWidget,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/tripDetails',
                      arguments: groupCode,
                    );
                  },
                ),
              );
            },
          );
          */


          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final trip = filtered[index];
              final tripName = trip['tripName'] ?? 'Unnamed Trip';
              final groupCode = trip.id;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    tripName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Group Code: $groupCode"),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: groupCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Group code copied!")),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/tripDetails',
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