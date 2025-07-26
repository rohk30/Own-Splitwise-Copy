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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // For PriorityQueue
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth (though not directly used in the provided snippet)

import 'add_expense_screen.dart';
import 'expense_details_screen.dart'; // Ensure correct path for ExpenseDetailsScreen

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // For PriorityQueue
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth (though not directly used in the provided snippet)

import 'add_expense_screen.dart';
import 'expense_details_screen.dart'; // Ensure correct path for ExpenseDetailsScreen

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
  TextEditingController _addMemberEmailController = TextEditingController();
  bool _useReducedTransactions = false;

  List<String> _currentMembers = [];

  List<MapEntry<String, String>> get sortedMembers {
    final List<MapEntry<String, String>> entries = _allUserEmails.entries
        .where((entry) => _currentMembers.contains(entry.key))
        .toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentMembers = List.from(widget.members);
    _initializeTripData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addMemberEmailController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllMemberEmails() async {
    if (_currentMembers.isEmpty) {
      setState(() {
        _allUserEmails = {};
      });
      return;
    }

    final Map<String, String> fetchedEmails = {};

    for (String uid in _currentMembers) {
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

  // Method to remove a member
  Future<void> _removeMember(String userIdToRemove) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Remove Member"),
          content: Text("Are you sure you want to remove ${_allUserEmails[userIdToRemove] ?? 'this member'}? This will not remove their past expenses."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              child: const Text("Remove"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm) {
      return;
    }

    try {
      final tripRef = FirebaseFirestore.instance.collection('trips').doc(widget.groupCode);

      await tripRef.update({
        'members': FieldValue.arrayRemove([userIdToRemove])
      });

      setState(() {
        _currentMembers.removeWhere((id) => id == userIdToRemove);
        _allUserEmails.remove(userIdToRemove);
      });

      await _initializeTripData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_allUserEmails[userIdToRemove] ?? 'Member'} removed successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove member: $e")),
      );
    }
  }

  // MODIFIED: _deleteExpense - now called from both Dismissible (if still used)
  // and the long-press menu.
  Future<void> _deleteExpense(String expenseId) async {
    // This dialog is redundant if called from the Dismissible's confirmDismiss,
    // but useful if called directly from an action.
    // For long press, we'll use a separate menu.
    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense deleted successfully!")),
      );
      // Recalculate balances after deletion
      _calculateOverallSplit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete expense: $e")),
      );
    }
  }

  Future<void> updateExpense(String expenseId, Map<String, dynamic> updatedData) async {
    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .doc(expenseId)
          .update(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense updated successfully!")),
      );
      _calculateOverallSplit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update expense: $e")),
      );
    }
  }

  // NEW: Function to show long-press options for an expense
  void _showExpenseOptions(String expenseId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Expense'),
                onTap: () async {
                  Navigator.pop(context); // Close the bottom sheet
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailsScreen(
                        tripId: widget.groupCode,
                        expenseId: expenseId,
                        memberEmails: _allUserEmails,
                        onUpdateExpense: updateExpense,
                        onDeleteExpense: _deleteExpense, // Pass the delete callback
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Expense', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context); // Close the bottom sheet
                  // Call the delete function with confirmation
                  final bool confirm = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Confirm Delete"),
                        content: const Text("Are you sure you want to delete this expense?"),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("Delete"),
                          ),
                        ],
                      );
                    },
                  ) ?? false;
                  if (confirm) {
                    _deleteExpense(expenseId); // Call the existing delete method
                  }
                },
              ),
            ],
          ),
        );
      },
    );
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

    final Map<String, double> netBalance = {};
    for (var memberId in _currentMembers) {
      netBalance[memberId] = 0.0;
    }

    final Map<String, Map<String, double>> rawSplit = {};
    for (var memberId1 in _currentMembers) {
      rawSplit.putIfAbsent(memberId1, () => {});
      for (var memberId2 in _currentMembers) {
        if (memberId1 != memberId2) {
          rawSplit[memberId1]![memberId2] = 0.0;
        }
      }
    }

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final payerId = data['paidBy'] as String? ?? '';
      final splits = (data['splits'] ?? {}) as Map<String, dynamic>;

      if (!_currentMembers.contains(payerId)) {
        continue;
      }

      for (final entry in splits.entries) {
        final userId = entry.key as String;
        final amount = (entry.value as num?)?.toDouble() ?? 0.0;

        if (!_currentMembers.contains(userId) || userId == payerId) {
          continue;
        }

        netBalance[userId] = (netBalance[userId] ?? 0.0) - amount;
        netBalance[payerId] = (netBalance[payerId] ?? 0.0) + amount;

        rawSplit.putIfAbsent(userId, () => {});
        rawSplit[userId]![payerId] = (rawSplit[userId]![payerId] ?? 0.0) + amount;
      }
    }

    if (_useReducedTransactions) {
      final reducedResult = _calculateMinTransactionsSplit(netBalance);
      setState(() => overallOwes = reducedResult);
    } else {
      final simplifiedSplit = _simplifyPairwiseDebts(rawSplit);
      setState(() => overallOwes = simplifiedSplit);
    }
  }

  Map<String, Map<String, double>> _simplifyPairwiseDebts(
      Map<String, Map<String, double>> rawSplit) {
    final Map<String, Map<String, double>> result = {};

    Set<String> allInvolvedUids = {};
    rawSplit.keys.forEach((uid) => allInvolvedUids.add(uid));
    rawSplit.values.forEach((toMap) => toMap.keys.forEach((uid) => allInvolvedUids.add(uid)));


    for (final fromUid in allInvolvedUids) {
      for (final toUid in allInvolvedUids) {
        if (fromUid == toUid) continue;

        final amountFromTo = rawSplit[fromUid]?[toUid] ?? 0.0;
        final amountToFrom = rawSplit[toUid]?[fromUid] ?? 0.0;

        if (amountFromTo > 0.001 || amountToFrom > 0.001) {
          final netAmount = amountFromTo - amountToFrom;

          if (netAmount > 0.001) {
            result.putIfAbsent(fromUid, () => {});
            result[fromUid]![toUid] = netAmount;
          }
        }
      }
    }
    return result;
  }

  Map<String, Map<String, double>> _calculateMinTransactionsSplit(
      Map<String, double> netBalance) {
    final owesHeap = PriorityQueue<MapEntry<String, double>>(
          (a, b) => b.value.compareTo(a.value),
    );
    final owedHeap = PriorityQueue<MapEntry<String, double>>(
          (a, b) => b.value.compareTo(a.value),
    );

    netBalance.forEach((user, amount) {
      if (amount < -0.001) {
        owesHeap.add(MapEntry(user, -amount));
      } else if (amount > 0.001) {
        owedHeap.add(MapEntry(user, amount));
      }
    });

    final Map<String, Map<String, double>> result = {};

    while (owesHeap.isNotEmpty && owedHeap.isNotEmpty) {
      final owe = owesHeap.removeFirst();
      final owed = owedHeap.removeFirst();

      final minAmount = owe.value < owed.value ? owe.value : owed.value;

      result.putIfAbsent(owe.key, () => {});
      result[owe.key]![owed.key] = (result[owe.key]![owed.key] ?? 0.0) + minAmount;

      final remainingOwe = owe.value - minAmount;
      final remainingOwed = owed.value - minAmount;

      if (remainingOwe > 0.001) {
        owesHeap.add(MapEntry(owe.key, remainingOwe));
      }
      if (remainingOwed > 0.001) {
        owedHeap.add(MapEntry(owed.key, remainingOwed));
      }
    }
    return result;
  }

  Widget _buildSplitSummary() {
    List<String> summary = [];
    overallOwes.forEach((fromUid, payees) {
      payees.forEach((toUid, amount) {
        if (amount > 0.001) {
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

  Future<void> _addMemberToTrip(String memberEmail) async {
    try {
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

      if (_currentMembers.contains(newMemberUid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This member is already in the trip.")),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .update({
        'members': FieldValue.arrayUnion([newMemberUid]),
      });

      setState(() {
        _currentMembers.add(newMemberUid);
      });

      await _initializeTripData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Member $memberEmail added successfully!")),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add member: $e")),
      );
    }
  }

  void _showAddMemberDialog() {
    _addMemberEmailController.clear();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
                if (email.isNotEmpty && email.contains('@')) {
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
    if (_allUserEmails.isEmpty && _currentMembers.isNotEmpty) {
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
              ...sortedMembers.map((entry) {
                final String memberUid = entry.key;
                final String memberEmail = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(memberEmail),
                    leading: const Icon(Icons.person),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeMember(memberUid),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showAddMemberDialog,
                child: const Text("Add Member"),
              )
            ],
          ),

          // Tab 2: Expenses Display - MODIFIED for long press and removed Dismissible
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
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExpenseDetailsScreen(
                                    tripId: widget.groupCode,
                                    expenseId: expense.id,
                                    memberEmails: _allUserEmails,
                                    onUpdateExpense: updateExpense,
                                    onDeleteExpense: _deleteExpense, // Pass the delete callback
                                  ),
                                ),
                              );
                            },
                            // NEW: Long press for options (Edit/Delete)
                            onLongPress: () {
                              _showExpenseOptions(expense.id);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SwitchListTile(
                title: const Text("Reduce Transactions"),
                value: _useReducedTransactions,
                onChanged: (val) {
                  setState(() {
                    _useReducedTransactions = val;
                  });
                  _calculateOverallSplit();
                },
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
                members: _currentMembers,
                memberEmails: _allUserEmails,
              ),
            ),
          );
          _calculateOverallSplit();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
