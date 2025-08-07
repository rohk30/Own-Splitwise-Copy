import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:own_splitwise_copy/screens/trip_screens/trip_details/show_settlement_history_screen.dart';
import 'add_expense_screen.dart';
import 'expense_details_screen.dart'; // Ensure correct path


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
  Map<String, String> _allUserNames = {};
  Map<String, Map<String, double>> overallOwes = {};
  TextEditingController _addMemberEmailController = TextEditingController();
  TextEditingController _settlePayerEmailController = TextEditingController();
  TextEditingController _settlePayeeEmailController = TextEditingController();
  TextEditingController _settleAmountController = TextEditingController();

  bool _useReducedTransactions = false;
  bool _isCalculating = false;
  Timer? _debounceTimer;
  bool _isInitialized = false;


  List<String> _currentMembers = [];

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
    _settlePayerEmailController.dispose();
    _settlePayeeEmailController.dispose();
    _settleAmountController.dispose();
    _debounceTimer?.cancel(); // Cancel debounce timer
    super.dispose();
  }

  void _debouncedCalculateOverallSplit() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _calculateOverallSplit();
    });
  }

  Future<void> _initializeTripData() async {
    try {
      await _fetchAllMemberData();
      await _calculateOverallSplit();
      setState(() {
        _isInitialized = true; // Add this
      });
    } catch (e) {
      print("Error initializing trip data: $e");
      setState(() {
        _isInitialized = true; // Still set to true to prevent infinite loading
      });
    }
  }

  List<MapEntry<String, String>> get sortedMembers {
    if (_allUserNames.isEmpty) return [];

    final List<Map<String, String>> entries = _allUserNames.entries
        .where((entry) => _currentMembers.contains(entry.key))
        .map((e) => {'uid': e.key, 'name': e.value})
        .toList();
    entries.sort((a, b) => a['name']!.compareTo(b['name']!));
    // Return a list of MapEntry for consistency with how it was used before,
    // though the actual type is now Map<String, String> for the entry itself.
    // This conversion is a bit redundant but maintains the previous getter signature.
    return entries.map((e) => MapEntry(e['uid']!, e['name']!)).toList();
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

  Future<void> _fetchAllMemberData() async {
    if (_currentMembers.isEmpty) {
      setState(() {
        _allUserEmails = {};
        _allUserNames = {};
      });
      return;
    }

    final Map<String, String> fetchedEmails = {};
    final Map<String, String> fetchedNames = {};

    try {
      for (String uid in _currentMembers) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          fetchedEmails[uid] = userDoc['email'] ?? uid;
          fetchedNames[uid] = userDoc['name'] ?? userDoc['email'] ?? uid;
        } else {
          fetchedEmails[uid] = 'Unknown User';
          fetchedNames[uid] = 'Unknown User';
        }
      }
      setState(() {
        _allUserEmails = fetchedEmails;
        _allUserNames = fetchedNames;
      });
    } catch (e) {
      print("Error fetching member data: $e");
      // Set fallback data to prevent infinite loading
      setState(() {
        for (String uid in _currentMembers) {
          _allUserEmails[uid] = 'Unknown User';
          _allUserNames[uid] = 'Unknown User';
        }
      });
    }
  }

  Future<void> _removeMember(String userIdToRemove) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Remove Member"),
          content: Text("Are you sure you want to remove ${_allUserNames[userIdToRemove] ?? 'this member'}? This will not remove their past expenses."),
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
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove member: $e")),
      );
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
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
      _debouncedCalculateOverallSplit();
      // _calculateOverallSplit();
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
      _debouncedCalculateOverallSplit();
      // _calculateOverallSplit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update expense: $e")),
      );
    }
  }

  void _showExpenseOptions(String expenseId, bool isSettled) {
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
                onTap: isSettled ? null : () async {
                  Navigator.pop(context); // Close the bottom sheet
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailsScreen(
                        tripId: widget.groupCode,
                        expenseId: expenseId,
                        memberEmails: _allUserNames,
                        onUpdateExpense: updateExpense,
                        onDeleteExpense: _deleteExpense,
                        initialEditing: true,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Expense', style: TextStyle(color: Colors.red)),
                onTap: isSettled ? null : () async {
                  Navigator.pop(context); // Close the bottom sheet
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
                    _deleteExpense(expenseId);
                  }
                },
              ),
              if (!isSettled)
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Mark as Settled'),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Mark as Settled?'),
                        content: const Text('This will mark the expense as paid and remove it from split calculations.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('trips')
                          .doc(widget.groupCode)
                          .collection('expenses')
                          .doc(expenseId)
                          .update({'settled': true});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense marked as settled')),
                      );
                      // _calculateOverallSplit();
                      _debouncedCalculateOverallSplit();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // NEW: _handleManualSettlement method (modified to use 'settlements' collection)
  /*   LAST NON WORKING ONE
  Future<void> _handleManualSettlement() async {
    final payerEmail = _settlePayerEmailController.text.trim();
    final payeeEmail = _settlePayeeEmailController.text.trim();
    final amountText = _settleAmountController.text.trim();

    if (payerEmail.isEmpty || payeeEmail.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all settlement fields.")),
      );
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount.")),
      );
      return;
    }

    String? payerUid;
    String? payeeUid;

    // Use Future.wait to fetch both UIDs concurrently
    /*await Future.wait([
      FirebaseFirestore.instance.collection('users').where('email', isEqualTo: payerEmail).limit(1).get().then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          payerUid = snapshot.docs.first.id;
        }
      }),
      FirebaseFirestore.instance.collection('users').where('email', isEqualTo: payeeEmail).limit(1).get().then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          payeeUid = snapshot.docs.first.id;
        }
      }),
    ]);
     */

    _allUserNames.forEach((uid, name) {
      if (name == payerEmail) payerUid = uid;
      if (name == payeeEmail) payeeUid = uid;
    });

    if (payerUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payer email '$payerEmail' not found among trip members.")),
      );
      return;
    }
    if (payeeUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payee email '$payeeEmail' not found among trip members.")),
      );
      return;
    }
    if (!_currentMembers.contains(payerUid) || !_currentMembers.contains(payeeUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Both payer and payee must be current trip members.")),
      );
      return;
    }

    if (payerUid == payeeUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payer and Payee cannot be the same person.")),
      );
      return;
    }

    try {
      // Store settlement in a separate 'settlements' subcollection
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('settlements')
          .add({
        'payerUid': payerUid,
        'payeeUid': payeeUid,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settlement recorded successfully!")),
      );

      _settlePayerEmailController.clear();
      _settlePayeeEmailController.clear();
      _settleAmountController.clear();

      _debouncedCalculateOverallSplit();

      // _buildSplitSummary();

      // await _calculateOverallSplit(); // Recalculate balances
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to record settlement: $e")),
      );
    }
  }
   */

  Future<void> _handleManualSettlement() async {
    final payerEmail = _settlePayerEmailController.text.trim();
    final payeeEmail = _settlePayeeEmailController.text.trim();
    final amountText = _settleAmountController.text.trim();

    if (payerEmail.isEmpty || payeeEmail.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all settlement fields.")),
      );
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid positive amount.")),
      );
      return;
    }

    String? payerUid;
    String? payeeUid;

    // Find UIDs from names
    _allUserNames.forEach((uid, name) {
      if (name == payerEmail) payerUid = uid;
      if (name == payeeEmail) payeeUid = uid;
    });

    if (payerUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payer '$payerEmail' not found among trip members.")),
      );
      return;
    }
    if (payeeUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payee '$payeeEmail' not found among trip members.")),
      );
      return;
    }
    if (!_currentMembers.contains(payerUid) || !_currentMembers.contains(payeeUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Both payer and payee must be current trip members.")),
      );
      return;
    }

    if (payerUid == payeeUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payer and Payee cannot be the same person.")),
      );
      return;
    }

    // OPTIONAL: Validate that settlement doesn't exceed current debt
    final currentDebt = overallOwes[payerUid]?[payeeUid] ?? 0.0;
    if (currentDebt == 0.0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Existing Debt"),
          content: Text(
              "${_allUserNames[payerUid]} doesn't currently owe ${_allUserNames[payeeUid]} any money. "
                  "Recording this settlement will create a debt in the opposite direction. Continue?"
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Continue")),
          ],
        ),
      ) ?? false;

      if (!confirm) return;
    } else if (amount > currentDebt + 0.01) { // Small buffer for floating point
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Settlement Exceeds Debt"),
          content: Text(
              "${_allUserNames[payerUid]} currently owes ${_allUserNames[payeeUid]} ₹${currentDebt.toStringAsFixed(2)}, "
                  "but you're recording a settlement of ₹${amount.toStringAsFixed(2)}. "
                  "The excess will become a debt in the opposite direction. Continue?"
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Continue")),
          ],
        ),
      ) ?? false;

      if (!confirm) return;
    }

    try {
      // Store settlement in the 'settlements' subcollection
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('settlements')
          .add({
        'payerUid': payerUid,
        'payeeUid': payeeUid,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Manual settlement', // Optional: add description
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settlement recorded successfully!")),
      );

      // Clear form
      _settlePayerEmailController.clear();
      _settlePayeeEmailController.clear();
      _settleAmountController.clear();

      // Recalculate balances
      _debouncedCalculateOverallSplit();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to record settlement: $e")),
      );
    }
  }
  // NEW: _showSettlementHistory method
  /*
  void _showSettlementHistory() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Settlement History"),
          content: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('trips')
                .doc(widget.groupCode)
                .collection('settlements')
                .orderBy('timestamp', descending: true) // Order by latest settlements first
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No settlements recorded yet."));
              }

              final settlements = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true, // Important for dialog content
                itemCount: settlements.length,
                itemBuilder: (context, index) {
                  final settlement = settlements[index].data() as Map<String, dynamic>;
                  final String payerUid = settlement['payerUid'];
                  final String payeeUid = settlement['payeeUid'];
                  final num amount = settlement['amount'] ?? 0;
                  final Timestamp? timestamp = settlement['timestamp'] as Timestamp?;

                  final String payerDisplay = _allUserEmails[payerUid] ?? payerUid;
                  final String payeeDisplay = _allUserEmails[payeeUid] ?? payeeUid;
                  // final String dateDisplay = timestamp != null
                  //     ? DateFormat('MMM dd, hh:mm a').format(timestamp.toDate())
                  //     : 'N/A';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('$payerDisplay paid $payeeDisplay'),
                      // subtitle: Text('₹${amount.toStringAsFixed(2)} on $dateDisplay'),
                      // You could add onTap for more details or actions here
                    ),
                  );
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
   */

  // Different screen
  void _showSettlementHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementHistoryScreen(
          groupCode: widget.groupCode,
          memberEmails: _allUserNames,
        ),
      ),
    );
  }

  Future<void> _settleAllExpenses() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Settle All Debts"),
          content: const Text("Are you sure you want to mark ALL outstanding expenses as settled for this trip? This action cannot be undone for individual expenses."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Settle All", style: TextStyle(color: Colors.white)),
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
      final expensesQuery = FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .where('settled', isEqualTo: false)
          .get();

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      (await expensesQuery).docs.forEach((doc) {
        batch.update(doc.reference, {'settled': true});
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All unsettled expenses marked as settled!")),
      );
      _calculateOverallSplit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to settle all expenses: $e")),
      );
    }
  }

  // Calculate overall split
  /*
  Future<void> _calculateOverallSplit() async {
    if (_isCalculating) return;

    setState(() {
      _isCalculating = true;
    });

    try {
      // 1. Fetch ALL unsettled expenses
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .where('settled', isEqualTo: false)
          .get();

      // 2. Fetch ALL settlements
      final settlementsSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('settlements') // <--- Fetch from new collection
          .get();

      final Map<String, double> netBalance = {};
      for (var memberId in _currentMembers) {
        netBalance[memberId] = 0.0;
      }

      // Initialize rawSplit for all current members
      final Map<String, Map<String, double>> rawSplit = {};
      for (var memberId1 in _currentMembers) {
        rawSplit.putIfAbsent(memberId1, () => {});
        for (var memberId2 in _currentMembers) {
          if (memberId1 != memberId2) {
            rawSplit[memberId1]![memberId2] = 0.0;
          }
        }
      }

      // Process expenses first
      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final payerId = data['paidBy'] as String? ?? '';
        final splits = (data['splits'] ?? {}) as Map<String, dynamic>;

        if (!_currentMembers.contains(payerId)) {
          continue;
        }

        for (final entry in splits.entries) {
          final userId = entry.key as String;
          final amount = (entry.value as num?)?.toDouble() ?? 0.0;

          if (!_currentMembers.contains(userId)) {
            continue;
          }

          // Normal expense: payer paid for userId
          netBalance[userId] = (netBalance[userId] ?? 0.0) - amount;
          netBalance[payerId] = (netBalance[payerId] ?? 0.0) + amount;

          rawSplit.putIfAbsent(userId, () => {});
          rawSplit[userId]![payerId] = (rawSplit[userId]![payerId] ?? 0.0) + amount;
        }
      }

      // Now, process settlements
      // Claude:=
      for (var doc in settlementsSnapshot.docs) {
        final data = doc.data();
        final payerUid = data['payerUid'] as String? ?? '';
        final payeeUid = data['payeeUid'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        if (!_currentMembers.contains(payerUid) || !_currentMembers.contains(payeeUid)) {
          continue;
        }

        rawSplit.putIfAbsent(payerUid, () => {});
        rawSplit[payerUid]![payeeUid] = (rawSplit[payerUid]![payeeUid] ?? 0.0) - amount;

      }

      if (_useReducedTransactions) {
        final reducedResult = _calculateMinTransactionsSplit(netBalance);
        setState(() => overallOwes = reducedResult);
      } else {
        final simplifiedSplit = _simplifyPairwiseDebts(rawSplit);
        setState(() => overallOwes = simplifiedSplit);
      }
      OptimizedSplitSummary(
        overallOwes: overallOwes,
        memberNames: _allUserNames,
      );
    } catch (e) {
      print("Error calculating split: $e");
    } finally {
      setState(() {
        _isCalculating = false; // Add this
      });
    }

  }
  */

  Future<void> _calculateOverallSplit() async {
    if (_isCalculating) return;

    setState(() {
      _isCalculating = true;
    });

    try {
      // 1. Fetch ALL unsettled expenses
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .where('settled', isEqualTo: false)
          .get();

      // 2. Fetch ALL settlements
      final settlementsSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('settlements')
          .get();

      // Use net balance approach (consistent with AddExpenseScreen)
      final Map<String, double> netBalance = {};
      for (var memberId in _currentMembers) {
        netBalance[memberId] = 0.0;
      }

      // Initialize rawSplit for non-reduced transactions
      final Map<String, Map<String, double>> rawSplit = {};
      for (var memberId1 in _currentMembers) {
        rawSplit.putIfAbsent(memberId1, () => {});
        for (var memberId2 in _currentMembers) {
          if (memberId1 != memberId2) {
            rawSplit[memberId1]![memberId2] = 0.0;
          }
        }
      }

      // Process expenses
      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final payerId = data['paidBy'] as String? ?? '';
        final splits = (data['splits'] ?? {}) as Map<String, dynamic>;

        if (!_currentMembers.contains(payerId)) {
          continue;
        }

        for (final entry in splits.entries) {
          final userId = entry.key as String;
          final amount = (entry.value as num?)?.toDouble() ?? 0.0;

          if (!_currentMembers.contains(userId)) {
            continue;
          }

          // Update net balances
          netBalance[userId] = (netBalance[userId] ?? 0.0) - amount; // User owes this amount
          netBalance[payerId] = (netBalance[payerId] ?? 0.0) + amount; // Payer is owed this amount

          // Update raw split for pairwise tracking
          rawSplit.putIfAbsent(userId, () => {});
          rawSplit[userId]![payerId] = (rawSplit[userId]![payerId] ?? 0.0) + amount;
        }
      }

      // Process settlements - FIXED LOGIC
      for (var doc in settlementsSnapshot.docs) {
        final data = doc.data();
        final payerUid = data['payerUid'] as String? ?? '';
        final payeeUid = data['payeeUid'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        if (!_currentMembers.contains(payerUid) || !_currentMembers.contains(payeeUid)) {
          continue;
        }

        // CORRECTED: Settlement reduces the payer's debt to payee
        // Net balance approach (consistent with AddExpenseScreen)
        netBalance[payerUid] = (netBalance[payerUid] ?? 0.0) + amount; // Payer's debt decreases
        netBalance[payeeUid] = (netBalance[payeeUid] ?? 0.0) - amount; // Payee's owed amount decreases

        // Raw split approach: reduce the existing debt between payer and payee
        rawSplit.putIfAbsent(payerUid, () => {});
        rawSplit[payerUid]![payeeUid] = (rawSplit[payerUid]![payeeUid] ?? 0.0) - amount;

        // Ensure we don't go negative (settlement can't exceed existing debt)
        if (rawSplit[payerUid]![payeeUid]! < 0) {
          // If settlement exceeds debt, the excess becomes a debt in the other direction
          final excess = -rawSplit[payerUid]![payeeUid]!;
          rawSplit[payerUid]![payeeUid] = 0.0;

          rawSplit.putIfAbsent(payeeUid, () => {});
          rawSplit[payeeUid]![payerUid] = (rawSplit[payeeUid]![payerUid] ?? 0.0) + excess;
        }
      }

      // Choose calculation method based on toggle
      if (_useReducedTransactions) {
        final reducedResult = _calculateMinTransactionsSplit(netBalance);
        setState(() => overallOwes = reducedResult);
      } else {
        final simplifiedSplit = _simplifyPairwiseDebts(rawSplit);
        setState(() => overallOwes = simplifiedSplit);
      }

    } catch (e) {
      print("Error calculating split: $e");
    } finally {
      setState(() {
        _isCalculating = false;
      });
    }
  }

  // Simplify Pairwise Debts
  /*
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

        final netAmount = amountFromTo - amountToFrom;

        if (netAmount.abs() > 0.001) {
          if (netAmount > 0) { // fromUid owes toUid
            result.putIfAbsent(fromUid, () => {});
            result[fromUid]![toUid] = netAmount;
          } else { // toUid owes fromUid
            result.putIfAbsent(toUid, () => {});
            result[toUid]![fromUid] = -netAmount; // Store as positive amount
          }
        }
      }
    }
    return result;
  }
   */

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

        final netAmount = amountFromTo - amountToFrom;

        if (netAmount.abs() > 0.01) { // Use 0.01 instead of 0.001 for currency
          if (netAmount > 0) { // fromUid owes toUid
            result.putIfAbsent(fromUid, () => {});
            result[fromUid]![toUid] = netAmount;
          }
          // Note: We don't add the reverse case here because we'll process it
          // when we iterate with fromUid and toUid swapped
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
    // _calculateOverallSplit();
    List<String> summary = [];
    overallOwes.forEach((fromUid, payees) {
      payees.forEach((toUid, amount) {
        if (amount > 0.001) {
          final fromNameOrEmail = _allUserNames[fromUid] ?? fromUid;
          final toNameOrEmail = _allUserNames[toUid] ?? toUid;
          summary.add("$fromNameOrEmail owes $toNameOrEmail ₹${amount.toStringAsFixed(2)}");
        }
      });
    });

    if (summary.isEmpty && overallOwes.isNotEmpty) {
      return const Text("All balances are settled or zero.",
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    } else if (summary.isEmpty && overallOwes.isEmpty) {
      return const Text("No balances to settle yet.",
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: summary.map((s) => Text(s)).toList(),
    );

    // List<String> summary = [];
    // overallOwes.forEach((fromUid, payees) {
    //   payees.forEach((toUid, amount) {
    //     if (amount > 0.001) {
    //       final fromNameOrEmail = _allUserEmails[fromUid] ?? fromUid;
    //       final toNameOrEmail = _allUserEmails[toUid] ?? toUid;
    //       summary.add("$fromNameOrEmail owes $toNameOrEmail ₹${amount.toStringAsFixed(2)}");
    //     }
    //   });
    // });
    //
    // if (summary.isEmpty && overallOwes.isNotEmpty) {
    //   return const Text("All balances are settled or zero.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    // } else if (summary.isEmpty && overallOwes.isEmpty) {
    //   return const Text("No balances to settle yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    // }
    // return Column(
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: summary.map((s) => Text(s)).toList(),
    // );
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
              onPressed: () async {
                final email = _addMemberEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  await _addMemberToTrip(email);
                  Navigator.of(dialogContext).pop();
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

  void _showMembersDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16), // Make dialog wider
          title: const Text("Trip Members"),
          content: SizedBox(
            width: double.maxFinite, // Take full available width
            child: SingleChildScrollView(
              child: ListBody(
                children: [
                  if (sortedMembers.isEmpty)
                    const Text("No members yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ...sortedMembers.map((entry) {
                    final String memberUid = entry.key;
                    final String memberName = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // More padding
                        title: Text(memberName),
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
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showAddMemberDialog();
                    },
                    child: const Text("Add Member"),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text("Trip Details")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'View Members',
            onPressed: _showMembersDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Expenses"),
            Tab(text: "Settle Up"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Expenses Display
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.groupCode)
                      .collection('expenses')
                      .orderBy('timestamp', descending: true) // Add ordering like settlement history
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Loading expenses..."),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
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
                              'Error loading expenses',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final expenses = snapshot.data!.docs;

                    if (expenses.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "No Expenses Yet",
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Start by adding your first expense\nto track group spending.",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        return Future.delayed(const Duration(milliseconds: 300));
                      },
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${expenses.length} Expense${expenses.length == 1 ? '' : 's'}",
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "All group expenses and who paid for them",
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                final expense = expenses[index];
                                final data = expense.data() as Map<String, dynamic>;

                                final String title = data['description'] ?? 'No Title';
                                final num amount = data['amount'] ?? 0;
                                final String paidByUid = data['paidBy'] as String;
                                final bool isSettled = data['settled'] == true;
                                final Timestamp? timestamp = data['timestamp'] as Timestamp?;

                                final paidByDisplay = _allUserNames[paidByUid] ?? paidByUid;

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ExpenseDetailsScreen(
                                              tripId: widget.groupCode,
                                              expenseId: expense.id,
                                              memberEmails: _allUserNames,
                                              onUpdateExpense: updateExpense,
                                              onDeleteExpense: _deleteExpense,
                                            ),
                                          ),
                                        );
                                      },
                                      onLongPress: () {
                                        _showExpenseOptions(expense.id, isSettled);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: isSettled
                                                        ? Colors.green.shade50
                                                        : Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    isSettled ? Icons.check_circle : Icons.receipt,
                                                    color: isSettled
                                                        ? Colors.green.shade600
                                                        : Colors.orange.shade600,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        title,
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      RichText(
                                                        text: TextSpan(
                                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                            color: Colors.grey.shade600,
                                                          ),
                                                          children: [
                                                            const TextSpan(text: "Paid by "),
                                                            TextSpan(
                                                              text: paidByDisplay,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: isSettled
                                                            ? Colors.green.shade600
                                                            : Theme.of(context).colorScheme.primary,
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        "₹${amount.toStringAsFixed(2)}",
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isSettled) ...[
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.shade100,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          "✅ Settled",
                                                          style: TextStyle(
                                                            color: Colors.green.shade700,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: expenses.length,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 80), // Bottom padding
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Tab 2: Settle Up Display
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Record a Direct Payment:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Dropdown for Payer (Who paid)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Payer (Who paid)',
                    border: OutlineInputBorder(),
                    helperText: 'Select who made the payment',
                  ),
                  value: _settlePayerEmailController.text.isEmpty
                      ? null
                      : _settlePayerEmailController.text, // Keep selected value consistent
                  items: sortedMembers.map((entry) {
                    return DropdownMenuItem(
                      value: entry.value, // Email as value
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _settlePayerEmailController.text = newValue;
                    }
                  },
                  hint: const Text('Select Payer'),
                ),
                const SizedBox(height: 12),

                // Dropdown for Payee (Who was paid)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Payee (Who was paid)',
                    border: OutlineInputBorder(),
                    helperText: 'Select who received the payment',
                  ),
                  value: _settlePayeeEmailController.text.isEmpty
                      ? null
                      : _settlePayeeEmailController.text, // Keep selected value consistent
                  items: sortedMembers.map((entry) {
                    return DropdownMenuItem(
                      value: entry.value, // Email as value
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _settlePayeeEmailController.text = newValue;
                    }
                  },
                  hint: const Text('Select Payee'),
                ),
                const SizedBox(height: 12),

                //For amount Paid
                TextField(
                  controller: _settleAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid',
                    border: OutlineInputBorder(),
                    prefixText: '₹',
                    helperText: 'Enter the amount settled',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Record settlement button
                ElevatedButton(
                  onPressed: _handleManualSettlement,
                  child: const Text('Record Settlement'),
                ),
                const Divider(height: 40, thickness: 1), // Separator

                // NEW: Button to view settlement history
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('View Settlement History'),
                  onTap: _showSettlementHistory,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  contentPadding: EdgeInsets.zero, // Adjust padding if needed
                ),
                const Divider(height: 40, thickness: 1), // Separator

                // Reduce Transactions button
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
                const SizedBox(height: 16),

                // Settle all debts button
                ElevatedButton.icon(
                  onPressed: () async {
                    await _settleAllExpenses();
                  },
                  icon: const Icon(Icons.done_all),
                  label: const Text("Settle All Debts"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
                const SizedBox(height: 24),
                const Text("Overall Balance:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // _buildSplitSummary(),
                OptimizedSplitSummary(
                  overallOwes: overallOwes,
                  memberNames: _allUserNames,
                ),
                const SizedBox(height: 20),
              ],
            ),
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
                memberNames: _allUserNames,
              ),
            ),
          );
          // _calculateOverallSplit();
          _debouncedCalculateOverallSplit();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class OptimizedSplitSummary extends StatelessWidget {
  final Map<String, Map<String, double>> overallOwes;
  final Map<String, String> memberNames;

  const OptimizedSplitSummary({
    super.key,
    required this.overallOwes,
    required this.memberNames,
  });

  @override
  Widget build(BuildContext context) {
    List<String> summary = [];
    overallOwes.forEach((fromUid, payees) {
      payees.forEach((toUid, amount) {
        if (amount > 0.001) {
          final fromNameOrEmail = memberNames[fromUid] ?? fromUid;
          final toNameOrEmail = memberNames[toUid] ?? toUid;
          summary.add("$fromNameOrEmail owes $toNameOrEmail ₹${amount.toStringAsFixed(2)}");
        }
      });
    });

    if (summary.isEmpty && overallOwes.isNotEmpty) {
      return const Text("All balances are settled or zero.",
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    } else if (summary.isEmpty && overallOwes.isEmpty) {
      return const Text("No balances to settle yet.",
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: summary.map((s) => Text(s)).toList(),
    );
  }
}

// Working but wanna add the functionalities in the settle up tab properly
/*
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

  // This getter remains for consistent member display logic in the dialog
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
    // Changed length to 2 for "Expenses" and "Split"
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
      // If the dialog is still open, pop it after removal
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove member: $e")),
      );
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
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

  void _showExpenseOptions(String expenseId, bool isSettled) {
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
                onTap: isSettled ? null : () async {
                  Navigator.pop(context); // Close the bottom sheet
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailsScreen(
                        tripId: widget.groupCode,
                        expenseId: expenseId,
                        memberEmails: _allUserEmails,
                        onUpdateExpense: updateExpense,
                        onDeleteExpense: _deleteExpense,
                        initialEditing: true,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Expense', style: TextStyle(color: Colors.red)),
                onTap: isSettled ? null : () async {
                  Navigator.pop(context); // Close the bottom sheet
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
                    _deleteExpense(expenseId);
                  }
                },
              ),
              if (!isSettled)
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Mark as Settled'),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Mark as Settled?'),
                        content: const Text('This will mark the expense as paid and remove it from split calculations.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('trips')
                          .doc(widget.groupCode)
                          .collection('expenses')
                          .doc(expenseId)
                          .update({'settled': true});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense marked as settled')),
                      );
                      _calculateOverallSplit();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _settleAllExpenses() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Settle All Debts"),
          content: const Text("Are you sure you want to mark ALL outstanding expenses as settled for this trip? This action cannot be undone for individual expenses."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Settle All", style: TextStyle(color: Colors.white)),
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
      final expensesQuery = FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .where('settled', isEqualTo: false)
          .get();

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      (await expensesQuery).docs.forEach((doc) {
        batch.update(doc.reference, {'settled': true});
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All unsettled expenses marked as settled!")),
      );
      _calculateOverallSplit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to settle all expenses: $e")),
      );
    }
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
        .where('settled', isEqualTo: false)
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
      // We don't pop the dialog here, instead let _showAddMemberDialog handle it
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
              onPressed: () async {
                final email = _addMemberEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  // Wait for add member to complete before potentially closing
                  await _addMemberToTrip(email);
                  Navigator.of(dialogContext).pop(); // Close dialog after attempting to add
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

  // New method to show the members list as a dialog
  void _showMembersDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Trip Members"),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
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
                        onPressed: () => _removeMember(memberUid), // This will also pop the dialog on success
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close current dialog first
                    _showAddMemberDialog(); // Then show add member dialog
                  },
                  child: const Text("Add Member"),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
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
        // Added actions for the members button
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'View Members',
            onPressed: _showMembersDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // Updated tabs
          tabs: const [
            Tab(text: "Expenses"),
            Tab(text: "Settle Up"),
          ],
        ),
      ),
      body: TabBarView(
        // padding:
        controller: _tabController,
        children: [
          // Tab 1: Expenses Display
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                          final bool isSettled = data['settled'] == true;

                          final paidByDisplay = _allUserEmails[paidByUid] ?? paidByUid;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(title)),
                                  if (isSettled)
                                    const Text(
                                      '✅ Settled',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
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
                                      onDeleteExpense: _deleteExpense,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () {
                                _showExpenseOptions(expense.id, isSettled);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              // Existing Split-related widgets within the first tab
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await _settleAllExpenses();
                },
                icon: const Icon(Icons.done_all),
                label: const Text("Settle All Debts"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
              // --- THIS IS THE MINOR ADJUSTMENT ---
              // The Padding widget needs a single 'child'.
              // The children for your balance display should be inside a Column,
              // and that Column is the child of the Padding.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column( // <--- Wrap your balance elements in a Column
                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                  children: [
                    const SizedBox(height: 24),
                    const Text("Overall Balance:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildSplitSummary(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),

          // Tab 2: Split Display (formerly where Members was)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _settleAllExpenses();
                  },
                  icon: const Icon(Icons.done_all),
                  label: const Text("Settle All Debts"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
                const SizedBox(height: 24),
                const Text("Overall Balance:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildSplitSummary(),
                const SizedBox(height: 20),
                // You can add more split-related UI here if needed
              ],
            ),
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
*/
