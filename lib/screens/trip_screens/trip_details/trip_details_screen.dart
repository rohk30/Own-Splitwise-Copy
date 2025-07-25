/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_expense_screen.dart';
import 'expense_details_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final String groupCode;
  final List<String> members;
  final Map<String, String> memberEmails;

  const TripDetailsScreen({
    super.key,
    required this.groupCode,
    required this.members,
    required this.memberEmails,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MapEntry<String, String>> get sortedMembers => widget.memberEmails.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  Map<String, Map<String, double>> overallOwes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateOverallSplit();
  }

  Future<void> _calculateOverallSplit() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.groupCode)
        .collection('expenses')
        .get();

    final Map<String, Map<String, double>> result = {};

    for (var doc in snapshot.docs) {
      final splitDetails = Map<String, dynamic>.from(doc['splitDetails'] ?? {});
      final payerId = doc['payerId'];

      splitDetails.forEach((userId, amount) {
        if (userId == payerId) return; // Skip payer
        result.putIfAbsent(userId, () => {});
        result[userId]![payerId] =
            (result[userId]![payerId] ?? 0) + (amount as num).toDouble();
      });
    }

    setState(() => overallOwes = result);
  }

  Widget _buildSplitSummary() {
    List<String> summary = [];
    overallOwes.forEach((from, payees) {
      payees.forEach((to, amount) {
        if (amount > 0) {
          final fromName = widget.memberEmails[from] ?? from;
          final toName = widget.memberEmails[to] ?? to;
          summary.add("$fromName owes $toName ₹${amount.toStringAsFixed(2)}");
        }
      });
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: summary.map((s) => Text(s)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Members"),
            Tab(text: "Expenses"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Members
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Trip Members:", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              ...sortedMembers.map((entry) => ListTile(
                title: Text(entry.value),
                subtitle: Text(entry.key),
              )),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement add member logic
                },
                child: const Text("Add Member"),
              )
            ],
          ),

          // Tab 2: Expenses
          Column(
            children: [

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.groupCode)
                      .collection('expenses')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final expenses = snapshot.data!.docs;

                    if (expenses.isEmpty) {
                      return const Center(child: Text("No expenses yet"));
                    }

                    return ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        final data = expense.data() as Map<String, dynamic>;
                        final String title = data['description'] ?? 'No Title';
                        // title = title.toCapitalized();
                        final amount = data['amount'] ?? 0;

                        return ListTile(
                          title: Text(title),
                          subtitle: Text('₹$amount paid by ${data['paidBy']}'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpenseDetailsScreen(
                                  tripId: widget.groupCode,
                                  expenseId: expenses[index].id,
                                  memberEmails: widget.memberEmails,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildSplitSummary(),
              )
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(
                groupCode: widget.groupCode,
                members: widget.members,
                memberEmails: widget.memberEmails,
              ),
            ),
          );
          _calculateOverallSplit();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}   */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_expense_screen.dart';
import 'expense_details_screen.dart'; // Ensure correct path
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'expense_details_screen.dart'; // Ensure correct path
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth if you need to access current user's info

// Make sure you have this screen, otherwise the FloatingActionButton will throw an error
import 'add_expense_screen.dart'; // Ensure correct path for AddExpenseScreen

class TripDetailsScreen extends StatefulWidget {
  final String groupCode;
  final List<String> members; // List of userIds of trip members

  const TripDetailsScreen({
    super.key,
    required this.groupCode,
    required this.members,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, String> _allUserEmails = {};
  Map<String, Map<String, double>> overallOwes = {};
  TextEditingController _addMemberEmailController = TextEditingController(); // Controller for the add member dialog

  List<MapEntry<String, String>> get sortedMembers {
    final List<MapEntry<String, String>> entries = _allUserEmails.entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value)); // Sort by email/name
    return entries;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeTripData(); // Unified initialization function
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addMemberEmailController.dispose(); // Dispose the controller
    super.dispose();
  }

  Future<void> _fetchAllMemberEmails() async {
    if (widget.members.isEmpty) {
      setState(() {
        _allUserEmails = {};
      });
      return;
    }

    final Map<String, String> fetchedEmails = {};

    for (String uid in widget.members) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        fetchedEmails[uid] = userDoc['email'] ?? userDoc['name'] ?? uid;
      } else {
        fetchedEmails[uid] = 'Unknown User';
      }
    }
    setState(() {
      _allUserEmails = fetchedEmails;
    });
  }

  Future<void> _initializeTripData() async {
    await _fetchAllMemberEmails();
    await _calculateOverallSplit();
  }

  Future<void> _calculateOverallSplit() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.groupCode)
        .collection('expenses')
        .get();

    final Map<String, Map<String, double>> raw = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final splitDetails = data['splits'] as Map<String, dynamic>? ?? {};
      final payerId = data['paidBy'];

      splitDetails.forEach((userId, amount) {
        if (userId == payerId) return;

        final amt = (amount as num?)?.toDouble() ?? 0.0;
        raw.putIfAbsent(userId, () => {});
        raw[userId]![payerId] = (raw[userId]![payerId] ?? 0.0) + amt;
      });
    }

    // Netting mutual debts
    final Map<String, Map<String, double>> netResult = {};

    for (var from in raw.keys) {
      for (var to in raw[from]!.keys) {
        final fromToAmount = raw[from]![to]!;
        final toFromAmount = raw[to]?[from] ?? 0.0;

        double netAmount = fromToAmount - toFromAmount;

        if (netAmount > 0) {
          netResult.putIfAbsent(from, () => {});
          netResult[from]![to] = netAmount;
        }
      }
    }

    setState(() => overallOwes = netResult);
  }




  Widget _buildSplitSummary() {
    List<String> summary = [];
    overallOwes.forEach((fromUid, payees) {
      payees.forEach((toUid, amount) {
        if (amount > 0) {
          final fromNameOrEmail = _allUserEmails[fromUid] ?? fromUid;
          final toNameOrEmail = _allUserEmails[toUid] ?? toUid;
          summary.add("$fromNameOrEmail owes $toNameOrEmail ₹${amount.toStringAsFixed(2)}");
        }
      });
    });

    if (summary.isEmpty && overallOwes.isNotEmpty) {
      return const Text("All balances are settled or zero.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    } else if (summary.isEmpty && overallOwes.isEmpty) {
      return const Text("No balances to settle yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: summary.map((s) => Text(s)).toList(),
    );
  }

  // --- New method to add a member ---
  Future<void> _addMemberToTrip(String memberEmail) async {
    try {
      // 1. Find the user by email in the 'users' collection
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: memberEmail)
          .limit(1)
          .get();

      if (userQuerySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User with this email not found.")),
        );
        return;
      }

      final newMemberUid = userQuerySnapshot.docs.first.id;

      // Check if the member is already in the trip
      if (widget.members.contains(newMemberUid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This member is already in the trip.")),
        );
        return;
      }

      // 2. Update the 'members' array in the 'trips' document
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .update({
        'members': FieldValue.arrayUnion([newMemberUid]), // Atomically add the new member's UID
      });

      // 3. Update the local state to reflect the change immediately
      setState(() {
        widget.members.add(newMemberUid); // Add to the local list (important for re-fetching emails)
      });

      // 4. Re-fetch all member emails (including the new one) and recalculate splits
      await _initializeTripData(); // Re-fetch emails and re-calculate splits

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Member $memberEmail added successfully!")),
      );
      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add member: $e")),
      );
    }
  }

  // --- Dialog for adding a member ---
  void _showAddMemberDialog() {
    _addMemberEmailController.clear(); // Clear previous input
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Use dialogContext to pop the dialog
        return AlertDialog(
          title: const Text("Add New Member"),
          content: TextField(
            controller: _addMemberEmailController,
            decoration: const InputDecoration(hintText: "Enter member's email"),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () {
                final email = _addMemberEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) { // Simple email validation
                  _addMemberToTrip(email);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid email address.")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_allUserEmails.isEmpty && widget.members.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Trip Details")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Members"),
            Tab(text: "Expenses"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Members Display
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Trip Members:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (sortedMembers.isEmpty)
                const Text("No members yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ...sortedMembers.map((entry) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(entry.value),
                  subtitle: Text(entry.key),
                  leading: const Icon(Icons.person),
                ),
              )).toList(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showAddMemberDialog, // Call the new dialog function
                child: const Text("Add Member"),
              )
            ],
          ),

          // Tab 2: Expenses Display
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.groupCode)
                      .collection('expenses')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading expenses: ${snapshot.error}'));
                    }

                    final expenses = snapshot.data!.docs;

                    if (expenses.isEmpty) {
                      return const Center(child: Text("No expenses yet. Add one!"));
                    }

                    return ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        final data = expense.data() as Map<String, dynamic>;

                        final String title = data['description'] ?? 'No Title';
                        final num amount = data['amount'] ?? 0;
                        final String paidByUid = data['paidBy'] as String;

                        final paidByDisplay = _allUserEmails[paidByUid] ?? paidByUid;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text('₹${amount.toStringAsFixed(2)} paid by $paidByDisplay'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExpenseDetailsScreen(
                                    tripId: widget.groupCode,
                                    expenseId: expense.id,
                                    memberEmails: _allUserEmails,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Overall Balance:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildSplitSummary(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(
                groupCode: widget.groupCode,
                members: widget.members, // List of UIDs
                memberEmails: _allUserEmails, // Pass the fetched map
              ),
            ),
          );
          _calculateOverallSplit(); // Recalculate after adding new expense
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


// class TripDetailsScreen extends StatefulWidget {
//   final String groupCode;
//   // We'll fetch member emails/names internally based on this list of IDs
//   final List<String> members; // List of userIds of trip members
//   // final Map<String, String> memberEmails1;
//
//   // Remove memberEmails from constructor, we'll build it internally
//   const TripDetailsScreen({
//     super.key,
//     required this.groupCode,
//     required this.members, // This list will be used to fetch emails
//     // required this.memberEmails1
//   });
//
//   @override
//   State<TripDetailsScreen> createState() => _TripDetailsScreenState();
// }
//
// class _TripDetailsScreenState extends State<TripDetailsScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   // New state variable to store fetched user emails/names
//   Map<String, String> _allUserEmails = {};
//   Map<String, Map<String, double>> overallOwes = {};
//
//   // Sort members using the fetched emails/names
//   List<MapEntry<String, String>> get sortedMembers {
//     final List<MapEntry<String, String>> entries = _allUserEmails.entries.toList();
//     entries.sort((a, b) => a.value.compareTo(b.value)); // Sort by email/name
//     return entries;
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _initializeTripData(); // Unified initialization function
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
//
//   // --- New method to fetch all member emails/names ---
//   Future<void> _fetchAllMemberEmails() async {
//     // Only fetch if members list is not empty to avoid unnecessary queries
//     if (widget.members.isEmpty) {
//       setState(() {
//         _allUserEmails = {}; // Ensure it's empty if no members
//       });
//       return;
//     }
//
//     final Map<String, String> fetchedEmails = {};
//
//     // Firestore 'whereIn' query has a limit of 10 values.
//     // If you expect more than 10 members, you'll need to split this into multiple queries.
//     // For simplicity, let's assume max 10 members for now, or handle in batches.
//     // A safer approach for many members: query one by one or batch if needed.
//     // For now, let's use individual gets which is robust for any number.
//     for (String uid in widget.members) {
//       final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
//       if (userDoc.exists) {
//         // Prioritize 'email' field, fallback to 'name', then to 'uid' if neither found
//         fetchedEmails[uid] = userDoc['email'] ?? userDoc['name'] ?? uid;
//       } else {
//         fetchedEmails[uid] = 'Unknown User'; // Fallback if user document not found
//       }
//     }
//     setState(() {
//       _allUserEmails = fetchedEmails;
//     });
//   }
//
//
//   // Unified data initialization
//   Future<void> _initializeTripData() async {
//     await _fetchAllMemberEmails(); // Fetch emails first
//     await _calculateOverallSplit(); // Then calculate splits using the fetched emails
//   }
//
//   // Calculates who owes whom based on expenses
//   Future<void> _calculateOverallSplit() async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('trips')
//         .doc(widget.groupCode)
//         .collection('expenses')
//         .get();
//
//     final Map<String, Map<String, double>> result = {};
//
//     for (var doc in snapshot.docs) {
//       final splitDetails = Map<String, dynamic>.from(doc['splitDetails'] ?? {});
//       final payerId = doc['payerId'];
//
//       splitDetails.forEach((userId, amount) {
//         if (userId == payerId) return; // Skip if user is the payer
//         result.putIfAbsent(userId, () => {});
//         result[userId]![payerId] =
//             (result[userId]![payerId] ?? 0) + (amount as num).toDouble();
//       });
//     }
//
//     setState(() => overallOwes = result);
//   }
//
//   // Builds the summary of who owes whom
//   Widget _buildSplitSummary() {
//     List<String> summary = [];
//     overallOwes.forEach((fromUid, payees) {
//       payees.forEach((toUid, amount) {
//         if (amount > 0) {
//           // Use _allUserEmails for lookup
//           final fromNameOrEmail = _allUserEmails[fromUid] ?? fromUid;
//           final toNameOrEmail = _allUserEmails[toUid] ?? toUid;
//           summary.add("$fromNameOrEmail owes $toNameOrEmail ₹${amount.toStringAsFixed(2)}");
//         }
//       });
//     });
//
//     if (summary.isEmpty && overallOwes.isNotEmpty) {
//       // This case might happen if all amounts are 0 or less
//       return const Text("All balances are settled or zero.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
//     } else if (summary.isEmpty && overallOwes.isEmpty) {
//       return const Text("No balances to settle yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
//     }
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: summary.map((s) => Text(s)).toList(),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Show a loading indicator if emails are not yet loaded
//     if (_allUserEmails.isEmpty && widget.members.isNotEmpty) {
//       return Scaffold(
//         appBar: AppBar(title: const Text("Trip Details")),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Trip Details"),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(text: "Members"),
//             Tab(text: "Expenses"),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           // Tab 1: Members Display
//           ListView(
//             padding: const EdgeInsets.all(16),
//             children: [
//               const Text("Trip Members:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 10),
//               // Use _allUserEmails to display sorted members
//               ...sortedMembers.map((entry) => Card(
//                 margin: const EdgeInsets.symmetric(vertical: 4),
//                 child: ListTile(
//                   title: Text(entry.value), // Display email/name
//                   subtitle: Text(entry.key), // Display userId below
//                   leading: const Icon(Icons.person),
//                 ),
//               )).toList(),
//               const SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: () {
//                   // TODO: Implement add member logic here.
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text("Add Member functionality not yet implemented.")),
//                   );
//                 },
//                 child: const Text("Add Member"),
//               )
//             ],
//           ),
//
//           // Tab 2: Expenses Display
//           Column(
//             children: [
//               Expanded(
//                 child: StreamBuilder<QuerySnapshot>(
//                   stream: FirebaseFirestore.instance
//                       .collection('trips')
//                       .doc(widget.groupCode)
//                       .collection('expenses')
//                       .snapshots(),
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return const Center(child: CircularProgressIndicator());
//                     }
//
//                     if (snapshot.hasError) {
//                       return Center(child: Text('Error loading expenses: ${snapshot.error}'));
//                     }
//
//                     final expenses = snapshot.data!.docs;
//
//                     if (expenses.isEmpty) {
//                       return const Center(child: Text("No expenses yet. Add one!"));
//                     }
//
//                     return ListView.builder(
//                       itemCount: expenses.length,
//                       itemBuilder: (context, index) {
//                         final expense = expenses[index];
//                         final data = expense.data() as Map<String, dynamic>;
//
//                         final String title = data['description'] ?? 'No Title';
//                         final num amount = data['amount'] ?? 0;
//                         final String paidByUid = data['paidBy'] as String;
//
//                         // Lookup the email using the internally fetched _allUserEmails map
//                         final paidByDisplay = _allUserEmails[paidByUid] ?? paidByUid; // Fallback to UID if not found
//
//                         return Card(
//                           margin: const EdgeInsets.symmetric(vertical: 4),
//                           child: ListTile(
//                             title: Text(title),
//                             subtitle: Text('₹${amount.toStringAsFixed(2)} paid by $paidByDisplay'),
//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => ExpenseDetailsScreen(
//                                     tripId: widget.groupCode,
//                                     expenseId: expense.id,
//                                     memberEmails: _allUserEmails, // Pass the fetched map
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: Align(
//                   alignment: Alignment.centerLeft,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text("Overall Balance:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                       const SizedBox(height: 8),
//                       _buildSplitSummary(),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//             ],
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
//           await Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => AddExpenseScreen(
//                 groupCode: widget.groupCode,
//                 members: widget.members, // List of UIDs
//                 memberEmails: _allUserEmails, // Pass the fetched map
//               ),
//             ),
//           );
//           _calculateOverallSplit(); // Recalculate after adding new expense
//         },
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

/*    Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.groupCode)
                      .collection('expenses')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final expenses = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final data = expenses[index].data();
                        return ListTile(
                          title: Text(data['title'] ?? 'No Title'),
                          subtitle: Text(
                            "₹${data['amount'].toString()} paid by ${widget.memberEmails[data['payerId']] ?? data['payerId']}",
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseDetailsScreen(
                                tripId: widget.groupCode,
                                expenseId: expenses[index].id,
                                memberEmails: widget.memberEmails,
                              ),
                            ),
                          ).then((_) => _calculateOverallSplit()),
                        );
                      },
                    );
                  },
                ),
              ),    */