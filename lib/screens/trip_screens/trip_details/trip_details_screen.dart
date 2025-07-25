import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
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
import 'add_expense_screen.dart';

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

class _TripDetailsScreenState extends State<TripDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, String> _allUserEmails = {};
  Map<String, Map<String, double>> overallOwes = {};
  TextEditingController _addMemberEmailController = TextEditingController(); // Controller for the add member dialog
  bool _useReducedTransactions = false; // default


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

    final Map<String, double> netBalance = {}; // For reduced transaction
    final Map<String, Map<String, double>> rawSplit = {}; // To build initial

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final payerId = data['paidBy'] ?? '';
      final splits = (data['splits'] ?? {}) as Map<String, dynamic>;

      for (final entry in splits.entries) {
        final userId = entry.key;
        final amount = (entry.value as num?)?.toDouble() ?? 0.0;

        if (userId == payerId) continue;

        // Store raw split
        rawSplit.putIfAbsent(userId, () => {});
        rawSplit[userId]![payerId] =
            (rawSplit[userId]![payerId] ?? 0) + amount;

        // Net balance for reduced
        netBalance[userId] = (netBalance[userId] ?? 0) - amount;
        netBalance[payerId] = (netBalance[payerId] ?? 0) + amount;
      }
    }

    if (_useReducedTransactions) {
      final reducedResult = _calculateMinTransactionsSplit(netBalance);
      setState(() => overallOwes = reducedResult);
    } else {
      // Simplify mutual debts (A->B and B->A)
      final simplifiedSplit = _simplifyPairwiseDebts(rawSplit);
      setState(() => overallOwes = simplifiedSplit);
    }
  }

  Map<String, Map<String, double>> _simplifyPairwiseDebts(
      Map<String, Map<String, double>> rawSplit) {
    final Map<String, Map<String, double>> result = {};

    for (final from in rawSplit.keys) {
      for (final to in rawSplit[from]!.keys) {
        final amountFromTo = rawSplit[from]![to] ?? 0;
        final amountToFrom = rawSplit[to]?[from] ?? 0;

        if (amountFromTo > amountToFrom) {
          final netAmount = amountFromTo - amountToFrom;
          result.putIfAbsent(from, () => {});
          result[from]![to] = netAmount;
        }
        // else if B owes A more or equal, A pays nothing
      }
    }
    return result;
  }


  Map<String, Map<String, double>> _calculateMinTransactionsSplit(
      Map<String, double> netBalance) {
    final owesHeap = PriorityQueue<MapEntry<String, double>>(
          (a, b) => b.value.compareTo(a.value), // Max heap
    );
    final owedHeap = PriorityQueue<MapEntry<String, double>>(
          (a, b) => b.value.compareTo(a.value), // Max heap
    );

    // Separate users who owe and are owed
    netBalance.forEach((user, amount) {
      if (amount < 0) {
        owesHeap.add(MapEntry(user, -amount)); // Make positive
      } else if (amount > 0) {
        owedHeap.add(MapEntry(user, amount));
      }
    });

    final Map<String, Map<String, double>> result = {};

    while (owesHeap.isNotEmpty && owedHeap.isNotEmpty) {
      final owe = owesHeap.removeFirst();
      final owed = owedHeap.removeFirst();

      final minAmount = owe.value < owed.value ? owe.value : owed.value;

      // owe.key owes owed.key
      result.putIfAbsent(owe.key, () => {});
      result[owe.key]![owed.key] = minAmount;

      final remainingOwe = owe.value - minAmount;
      final remainingOwed = owed.value - minAmount;

      if (remainingOwe > 0) {
        owesHeap.add(MapEntry(owe.key, remainingOwe));
      }
      if (remainingOwed > 0) {
        owedHeap.add(MapEntry(owed.key, remainingOwed));
      }
    }

    return result;
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
                  // subtitle: Text(entry.key),
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
              SwitchListTile(
                title: Text("Reduce Transactions"),
                value: _useReducedTransactions,
                onChanged: (val) {
                  setState(() {
                    _useReducedTransactions = val;
                  });
                  _calculateOverallSplit(); // recalculate using the new method
                },
              ),
              // ElevatedButton(
              //   onPressed: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (_) => ExpenseGraphScreen(
              //           balances: overallOwes,
              //           memberEmails: _allUserEmails,
              //         ),
              //       ),
              //     );
              //   },
              //   child: Text("View Balance Graph"),
              // ),

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


