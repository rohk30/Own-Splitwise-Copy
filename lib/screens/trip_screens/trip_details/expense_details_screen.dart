/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpenseDetailsScreen extends StatelessWidget {
  final String tripId;
  final String expenseId;

  const ExpenseDetailsScreen({
    super.key,
    required this.tripId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context) {
    final expenseRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expenseId);

    return Scaffold(
      appBar: AppBar(title: const Text("Expense Details")),
      body: FutureBuilder<DocumentSnapshot>(
        future: expenseRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Expense not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'No Title';
          final amount = data['amount'] ?? 0;
          final payerName = data['payerName'] ?? 'Unknown';
          final splitType = data['splitType'] ?? 'N/A';
          final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Title: $title", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text("Total Amount: ₹$amount"),
                const SizedBox(height: 8),
                Text("Paid by: $payerName"),
                const SizedBox(height: 8),
                // Text("Split Type: $splitType"),
                // const Divider(height: 32),
                Text("Breakdown", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: splitDetails.length,
                    itemBuilder: (context, index) {
                      final userId = splitDetails.keys.elementAt(index);
                      final userAmount = splitDetails[userId];
                      return ListTile(
                        title: Text("User ID: $userId"),
                        trailing: Text("₹$userAmount"),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}     */


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Define a type for the update callback, which is what TripDetailsScreen will provide
typedef OnUpdateExpenseCallback = Future<void> Function(String expenseId, Map<String, dynamic> updatedData);
// NEW: Define a type for the delete callback
typedef OnDeleteExpenseCallback = Future<void> Function(String expenseId);


class ExpenseDetailsScreen extends StatefulWidget {
  final String tripId;
  final String expenseId;
  final Map<String, String> memberEmails;
  final OnUpdateExpenseCallback onUpdateExpense;
  final OnDeleteExpenseCallback onDeleteExpense; // NEW: Callback for deleting expense
  final bool initialEditing;

  const ExpenseDetailsScreen({
    super.key,
    required this.tripId,
    required this.expenseId,
    required this.memberEmails,
    required this.onUpdateExpense,
    required this.onDeleteExpense,
    this.initialEditing = false, // NEW: Required in constructor
  });

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  String? _selectedPayerId;
  Map<String, double> _currentSplits = {};

  bool _isEditing = false;
  Future<DocumentSnapshot>? _expenseFuture;
  bool _isSettled = false; // NEW: State variable to hold the settled status

  final Map<String, TextEditingController> _splitAmountControllers = {};

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialEditing;
    _expenseFuture = _fetchExpenseData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _splitAmountControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<DocumentSnapshot> _fetchExpenseData() async {
    final expenseDoc = await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('expenses')
        .doc(widget.expenseId)
        .get();

    // CORRECTED SYNTAX AND LOGIC:
    if (expenseDoc.exists) {
      final data = expenseDoc.data()!;
      _titleController = TextEditingController(text: data['description'] ?? '');
      _amountController = TextEditingController(text: (data['amount'] ?? 0.0).toStringAsFixed(2));
      _selectedPayerId = data['paidBy'];
      _currentSplits = Map<String, double>.from(data['splits']?.map((key, value) => MapEntry(key, value.toDouble())) ?? {});
      _isSettled = data['settled'] == true; // CORRECTED: Access through data map and ensure boolean comparison

      _currentSplits.forEach((uid, amount) {
        _splitAmountControllers[uid] = TextEditingController(text: amount.toStringAsFixed(2));
      });

      // NEW: If the expense is settled, disable editing from the start
      if (_isSettled) {
        _isEditing = false;
      }
    } else {
      _titleController = TextEditingController();
      _amountController = TextEditingController();
      _selectedPayerId = null;
      _currentSplits = {};
      _isSettled = false; // Default to false if expense doesn't exist
    }
    return expenseDoc;
  }

  Future<void> _updateExpense() async {
    // NEW: Prevent update if settled
    if (_isSettled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot update a settled expense.")),
      );
      return;
    }

    if (_titleController.text.isEmpty || _amountController.text.isEmpty || _selectedPayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields.")),
      );
      return;
    }

    final double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid total amount.")),
      );
      return;
    }

    double sumOfSplits = 0.0;
    Map<String, double> finalSplits = {};
    _splitAmountControllers.forEach((uid, controller) {
      final double amount = double.tryParse(controller.text) ?? 0.0;
      finalSplits[uid] = amount;
      sumOfSplits += amount;
    });

    if ((sumOfSplits - totalAmount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Sum of individual shares (₹${sumOfSplits.toStringAsFixed(2)}) does not equal total amount (₹${totalAmount.toStringAsFixed(2)}).')),
      );
      return;
    }

    try {
      final Map<String, dynamic> updatedData = {
        'description': _titleController.text.trim(),
        'amount': totalAmount,
        'paidBy': _selectedPayerId,
        'splits': finalSplits,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await widget.onUpdateExpense(widget.expenseId, updatedData);

      setState(() {
        _isEditing = false;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update expense: $e")),
      );
    }
  }

  Future<void> _deleteExpenseFromDetails() async {
    // NEW: Prevent deletion if settled (optional, depends on your business logic)
    if (_isSettled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot delete a settled expense.")),
      );
      return;
    }

    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Expense"),
          content: const Text("Are you sure you want to permanently delete this expense? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      try {
        await widget.onDeleteExpense(widget.expenseId);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense deleted successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete expense: $e")),
        );
      }
    }
  }

  String _getUserDisplayName(String uid) {
    return widget.memberEmails[uid] ?? uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Details"),
        actions: [
          // Delete button (disabled if settled)
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _isSettled ? null : _deleteExpenseFromDetails, // NEW: Disable if settled
          ),
          // Edit/Save button (disabled if settled)
          _isEditing
              ? IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSettled ? null : _updateExpense, // NEW: Disable if settled
          )
              : IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isSettled ? null : () { // NEW: Disable if settled
              setState(() {
                _isEditing = true;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _expenseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading expense: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Expense not found.'));
          }

          // Use _isSettled from state, which was set in _fetchExpenseData
          final bool displayIsSettled = _isSettled; // Renamed for clarity in build method

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Description:", style: Theme.of(context).textTheme.bodyLarge),
                _isEditing && !displayIsSettled // NEW: Disable TextField if settled
                    ? TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: "Expense Description"),
                )
                    : Text(
                  _titleController.text.isEmpty ? 'No Description' : _titleController.text,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                Text("Total Amount:", style: Theme.of(context).textTheme.bodyLarge),
                _isEditing && !displayIsSettled // NEW: Disable TextField if settled
                    ? TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: "₹"),
                )
                    : Text(
                  "₹${double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? '0.00'}",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                Text("Paid by:", style: Theme.of(context).textTheme.bodyLarge),
                _isEditing && !displayIsSettled // NEW: Disable Dropdown if settled
                    ? DropdownButtonFormField<String>(
                  value: _selectedPayerId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text("Select Payer"),
                  items: widget.memberEmails.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPayerId = newValue;
                    });
                  },
                )
                    : Text(
                  _getUserDisplayName(_selectedPayerId ?? 'Unknown'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                // Mark as Settled Button (disabled if already settled)
                ElevatedButton.icon(
                  onPressed: displayIsSettled
                      ? null // Disable button if settled
                      : () async {
                    final confirm = await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Mark as Settled?'),
                        content: Text('This will mark the expense as paid and remove it from split calculations. You will no longer be able to edit or delete it.'), // More descriptive
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirm')),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('trips')
                          .doc(widget.tripId)
                          .collection('expenses')
                          .doc(widget.expenseId)
                          .update({'settled': true});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Expense marked as settled')),
                      );

                      // After updating in Firestore, update local state
                      setState(() {
                        _isSettled = true;
                        _isEditing = false; // Exit edit mode
                      });
                    }
                  },
                  icon: Icon(Icons.check_circle),
                  label: Text(displayIsSettled ? 'Settled' : 'Mark as Settled'), // Change label
                ),

                const Divider(height: 32),
                Text("Breakdown", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),

                Expanded(
                  child: ListView.builder(
                    itemCount: _currentSplits.length,
                    itemBuilder: (context, index) {
                      final uid = _currentSplits.keys.elementAt(index);
                      final TextEditingController controller = _splitAmountControllers[uid]!;
                      final userName = _getUserDisplayName(uid);

                      return ListTile(
                        title: Text(userName),
                        trailing: _isEditing && !displayIsSettled // NEW: Disable TextField if settled
                            ? SizedBox(
                          width: 100,
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              prefixText: "₹",
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              // No need for setState here, as controller updates automatically
                              // The validation will read from controllers on save
                            },
                          ),
                        )
                            : Text("₹${(double.tryParse(controller.text) ?? 0.0).toStringAsFixed(2)}"),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}