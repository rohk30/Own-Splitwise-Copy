import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AddExpenseScreen extends StatefulWidget {
  final String groupCode;
  final List<String> members;
  final Map<String, String> memberEmails;

  const AddExpenseScreen({
    required this.groupCode,
    required this.members,
    required this.memberEmails,
    Key? key,
  }) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedPayer;
  String _splitType = 'Equal';
  final Map<String, TextEditingController> _manualAmountControllers = {};
  final Set<String> _selectedMembersForPartialSplit = {};

  // NEW: For optimal payer suggestion
  String? _suggestedOptimalPayer;
  bool _isCalculatingOptimal = false;
  Map<String, double> _currentNetBalances = {};

  @override
  void initState() {
    super.initState();
    for (var uid in widget.members) {
      _manualAmountControllers[uid] = TextEditingController();
    }
    _selectedPayer = widget.members.isNotEmpty ? widget.members.first : null;
    _loadCurrentBalances(); // Load existing balances
  }

  String _getUserDisplayName(String uid) {
    return widget.memberEmails[uid] ?? uid;
  }

  // NEW: Load current net balances from existing expenses
  Future<void> _loadCurrentBalances() async {
    try {
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .where('settled', isEqualTo: false)
          .get();

      final settlementsSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('settlements')
          .get();

      final Map<String, double> netBalance = {};
      for (var memberId in widget.members) {
        netBalance[memberId] = 0.0;
      }

      // Process expenses
      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final payerId = data['paidBy'] as String? ?? '';
        final splits = (data['splits'] ?? {}) as Map<String, dynamic>;

        if (!widget.members.contains(payerId)) continue;

        for (final entry in splits.entries) {
          final userId = entry.key as String;
          final amount = (entry.value as num?)?.toDouble() ?? 0.0;

          if (!widget.members.contains(userId)) continue;

          netBalance[userId] = (netBalance[userId] ?? 0.0) - amount;
          netBalance[payerId] = (netBalance[payerId] ?? 0.0) + amount;
        }
      }

      // Process settlements (apply your corrected settlement logic)
      for (var doc in settlementsSnapshot.docs) {
        final data = doc.data();
        final payerUid = data['payerUid'] as String? ?? '';
        final payeeUid = data['payeeUid'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        if (!widget.members.contains(payerUid) || !widget.members.contains(payeeUid)) {
          continue;
        }

        // Settlement reduces payer's debt (your corrected logic)
        netBalance[payerUid] = (netBalance[payerUid] ?? 0.0) + amount;
        netBalance[payeeUid] = (netBalance[payeeUid] ?? 0.0) - amount;
      }

      setState(() {
        _currentNetBalances = netBalance;
      });
    } catch (e) {
      print('Error loading current balances: $e');
    }
  }

  // NEW: Calculate optimal payer suggestion
  Future<void> _calculateOptimalPayer() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the total amount first')),
      );
      return;
    }

    setState(() {
      _isCalculatingOptimal = true;
    });

    try {
      final double totalAmount = double.parse(_amountController.text.trim());
      final Map<String, double> currentSplits = _getCurrentSplits(totalAmount);

      if (currentSplits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set up the expense splits first')),
        );
        setState(() {
          _isCalculatingOptimal = false;
        });
        return;
      }

      String? bestPayer;
      int minTransactions = double.maxFinite.toInt();

      // Test each potential payer
      for (String potentialPayer in widget.members) {
        final int transactionCount = _calculateTransactionCount(potentialPayer, currentSplits);

        if (transactionCount < minTransactions) {
          minTransactions = transactionCount;
          bestPayer = potentialPayer;
        }
      }

      setState(() {
        _suggestedOptimalPayer = bestPayer;
        _isCalculatingOptimal = false;
      });

    } catch (e) {
      setState(() {
        _isCalculatingOptimal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating optimal payer: $e')),
      );
    }
  }

  // NEW: Get current splits based on split type
  Map<String, double> _getCurrentSplits(double totalAmount) {
    final Map<String, double> splits = {};

    if (_splitType == 'Equal') {
      final double splitAmount = totalAmount / widget.members.length;
      for (var uid in widget.members) {
        splits[uid] = double.parse(splitAmount.toStringAsFixed(2));
      }
    } else if (_splitType == 'Manual') {
      for (var uid in widget.members) {
        double userAmount = double.tryParse(_manualAmountControllers[uid]!.text.trim()) ?? 0.0;
        splits[uid] = userAmount;
      }
    } else if (_splitType == 'Partial Equal') {
      if (_selectedMembersForPartialSplit.isEmpty) return {};

      final double partialSplitAmount = totalAmount / _selectedMembersForPartialSplit.length;
      for (var uid in _selectedMembersForPartialSplit) {
        splits[uid] = double.parse(partialSplitAmount.toStringAsFixed(2));
      }
      for (var uid in widget.members) {
        if (!splits.containsKey(uid)) splits[uid] = 0.0;
      }
    }

    return splits;
  }

  // NEW: Calculate number of transactions needed if this person pays
  int _calculateTransactionCount(String payer, Map<String, double> splits) {
    // Create a copy of current balances
    final Map<String, double> testBalances = Map.from(_currentNetBalances);

    // Apply the new expense with this payer
    for (final entry in splits.entries) {
      final userId = entry.key;
      final amount = entry.value;

      if (userId == payer) continue; // Payer doesn't owe themselves

      // User owes the payer this amount
      testBalances[userId] = (testBalances[userId] ?? 0.0) - amount;
      testBalances[payer] = (testBalances[payer] ?? 0.0) + amount;
    }

    // Use the same min-transactions algorithm as your existing code
    return _calculateMinTransactionsCount(testBalances);
  }

  // NEW: Calculate minimum transactions needed (similar to your existing heap-based algorithm)
  int _calculateMinTransactionsCount(Map<String, double> netBalance) {
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

    int transactionCount = 0;

    while (owesHeap.isNotEmpty && owedHeap.isNotEmpty) {
      final owe = owesHeap.removeFirst();
      final owed = owedHeap.removeFirst();

      final minAmount = owe.value < owed.value ? owe.value : owed.value;
      transactionCount++; // Each iteration represents one transaction

      final remainingOwe = owe.value - minAmount;
      final remainingOwed = owed.value - minAmount;

      if (remainingOwe > 0.001) {
        owesHeap.add(MapEntry(owe.key, remainingOwe));
      }
      if (remainingOwed > 0.001) {
        owedHeap.add(MapEntry(owed.key, remainingOwed));
      }
    }

    return transactionCount;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final String title = _titleController.text.trim();
    final double totalAmount = double.parse(_amountController.text.trim());
    final Map<String, double> splits = {};
    double sumOfSplits = 0.0;

    if (_splitType == 'Equal') {
      final double splitAmount = totalAmount / widget.members.length;
      for (var uid in widget.members) {
        splits[uid] = double.parse(splitAmount.toStringAsFixed(2));
        sumOfSplits += splits[uid]!;
      }
    } else if (_splitType == 'Manual') {
      for (var uid in widget.members) {
        double userAmount = double.tryParse(_manualAmountControllers[uid]!.text.trim()) ?? 0.0;
        splits[uid] = userAmount;
        sumOfSplits += userAmount;
      }
    } else if (_splitType == 'Partial Equal') {
      if (_selectedMembersForPartialSplit.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one member.')),
        );
        return;
      }
      final double partialSplitAmount = totalAmount / _selectedMembersForPartialSplit.length;
      for (var uid in _selectedMembersForPartialSplit) {
        splits[uid] = double.parse(partialSplitAmount.toStringAsFixed(2));
        sumOfSplits += splits[uid]!;
      }
      for (var uid in widget.members) {
        if (!splits.containsKey(uid)) splits[uid] = 0.0;
      }
    }

    if ((sumOfSplits - totalAmount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Sum of individual shares (₹${sumOfSplits.toStringAsFixed(2)}) does not equal total amount (₹${totalAmount.toStringAsFixed(2)}).')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.groupCode)
        .collection('expenses')
        .add({
      'description': title,
      'amount': totalAmount,
      'paidBy': _selectedPayer,
      'splitType': _splitType,
      'splits': splits.map((uid, amt) => MapEntry(uid, amt.toDouble())),
      'timestamp': FieldValue.serverTimestamp(),
      'settled': false,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Expense Title"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Total Amount"),
                keyboardType: TextInputType.number,
                validator: (val) =>
                val == null || double.tryParse(val) == null ? "Enter valid amount" : null,
              ),
              const SizedBox(height: 12),

              // Paid By dropdown with optimal payer suggestion
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: null,
                      hint: Text('Select the payer'),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Select the payer', style: TextStyle(color: Colors.grey)),
                          enabled: false,
                        ),
                        ...widget.members.map((uid) => DropdownMenuItem(
                          value: uid,
                          child: Text(_getUserDisplayName(uid)),
                        )).toList(),
                      ],
                      onChanged: (val) {
                        if(val != null) {
                          setState(() =>
                            _selectedPayer = val
                          );
                        }
                      },
                      decoration: const InputDecoration(labelText: "Paid By"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // NEW: Optimal payer suggestion button
                  IconButton(
                    onPressed: _isCalculatingOptimal ? null : _calculateOptimalPayer,
                    icon: _isCalculatingOptimal
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)
                    )
                        : const Icon(Icons.lightbulb_outline),
                    tooltip: 'Suggest Optimal Payer',
                  ),
                ],
              ),

              // NEW: Optimal payer suggestion display
              if (_suggestedOptimalPayer != null)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggested Optimal Payer:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getUserDisplayName(_suggestedOptimalPayer!),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPayer = _suggestedOptimalPayer;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Use', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: null,
                hint: const Text('Select a split type'),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Select a split type', style: TextStyle(color: Colors.grey)),
                    enabled: true,
                  ),
                  DropdownMenuItem(value: 'Equal', child: Text('Split Equally')),
                  DropdownMenuItem(value: 'Manual', child: Text('Split Manually')),
                  DropdownMenuItem(value: 'Partial Equal', child: Text('Split Among Selected')),
                ],
                onChanged: (val) {
                  setState(() {
                    _splitType = val!;
                    // _suggestedOptimalPayer = null; // Clear suggestion when split type changes
                    if (_splitType != 'Partial Equal') {
                      _selectedMembersForPartialSplit.clear();
                    }
                    if (_splitType != 'Manual') {
                      _manualAmountControllers.forEach((key, controller) {
                        controller.clear();
                      });
                    }
                  });
                },
                decoration: const InputDecoration(labelText: "Split Type"),
              ),
              const SizedBox(height: 20),
              if (_splitType == 'Manual') ...widget.members.map((uid) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextFormField(
                    controller: _manualAmountControllers[uid],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "${_getUserDisplayName(uid)}'s share",
                    ),
                    onChanged: (value) {
                      // Clear suggestion when manual amounts change
                      if (_suggestedOptimalPayer != null) {
                        setState(() {
                          // _suggestedOptimalPayer = null;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
              if (_splitType == 'Partial Equal')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select members to split among:", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    ...widget.members.map((uid) {
                      return CheckboxListTile(
                        title: Text(_getUserDisplayName(uid)),
                        value: _selectedMembersForPartialSplit.contains(uid),
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedMembersForPartialSplit.add(uid);
                            } else {
                              _selectedMembersForPartialSplit.remove(uid);
                            }
                            // Clear suggestion when selection changes
                            _suggestedOptimalPayer = null;
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: const Text("Add Expense"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (var controller in _manualAmountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

/*
class AddExpenseScreen extends StatefulWidget {
  final String groupCode;
  final List<String> members;
  final Map<String, String> memberEmails;
  // final bool settled;

  const AddExpenseScreen({
    required this.groupCode,
    required this.members,
    required this.memberEmails,
    // settled = false,
    Key? key,
  }) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedPayer;
  String _splitType = 'Equal';
  final Map<String, TextEditingController> _manualAmountControllers = {};
  final Set<String> _selectedMembersForPartialSplit = {};

  @override
  void initState() {
    super.initState();
    for (var uid in widget.members) {
      _manualAmountControllers[uid] = TextEditingController();
    }
    _selectedPayer = widget.members.isNotEmpty ? widget.members.first : null;
  }

  // NEW: Helper to get display name for UIDs
  String _getUserDisplayName(String uid) {
    return widget.memberEmails[uid] ?? uid;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final String title = _titleController.text.trim();
    final double totalAmount = double.parse(_amountController.text.trim());
    final Map<String, double> splits = {};
    double sumOfSplits = 0.0; // NEW: To calculate sum of breakdown

    if (_splitType == 'Equal') {
      final double splitAmount = totalAmount / widget.members.length;
      for (var uid in widget.members) {
        splits[uid] = double.parse(splitAmount.toStringAsFixed(2));
        sumOfSplits += splits[uid]!; // NEW
      }
    } else if (_splitType == 'Manual') {
      for (var uid in widget.members) {
        double userAmount = double.tryParse(_manualAmountControllers[uid]!.text.trim()) ?? 0.0;
        splits[uid] = userAmount;
        sumOfSplits += userAmount; // NEW
      }
      // OLD: This check was already here, but now it's part of a more unified check
    } else if (_splitType == 'Partial Equal') {
      if (_selectedMembersForPartialSplit.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one member.')),
        );
        return;
      }
      final double partialSplitAmount = totalAmount / _selectedMembersForPartialSplit.length;
      for (var uid in _selectedMembersForPartialSplit) {
        splits[uid] = double.parse(partialSplitAmount.toStringAsFixed(2));
        sumOfSplits += splits[uid]!; // NEW
      }
      for (var uid in widget.members) {
        if (!splits.containsKey(uid)) splits[uid] = 0.0;
      }
    }

    // NEW: Centralized validation for total amount vs sum of splits
    // Using a small epsilon for floating-point comparison
    if ((sumOfSplits - totalAmount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Sum of individual shares (₹${sumOfSplits.toStringAsFixed(2)}) does not equal total amount (₹${totalAmount.toStringAsFixed(2)}).')),
      );
      return; // Stop submission
    }


    await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.groupCode)
        .collection('expenses')
        .add({
      'description': title,
      'amount': totalAmount,
      'paidBy': _selectedPayer,
      'splitType': _splitType,
      'splits': splits.map((uid, amt) => MapEntry(uid, amt.toDouble())),
      'timestamp': FieldValue.serverTimestamp(),
      'settled': false,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Expense Title"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Total Amount"),
                keyboardType: TextInputType.number,
                validator: (val) =>
                val == null || double.tryParse(val) == null ? "Enter valid amount" : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedPayer,
                items: widget.members
                    .map((uid) => DropdownMenuItem(
                  value: uid,
                  child: Text(_getUserDisplayName(uid)), // Use helper for display
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedPayer = val),
                decoration: const InputDecoration(labelText: "Paid By"),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _splitType,
                items: const [
                  DropdownMenuItem(value: 'Equal', child: Text('Split Equally')),
                  DropdownMenuItem(value: 'Manual', child: Text('Split Manually')),
                  DropdownMenuItem(value: 'Partial Equal', child: Text('Split Among Selected')),
                ],
                onChanged: (val) {
                  setState(() {
                    _splitType = val!;
                    // Clear selected members for partial split if changing type
                    if (_splitType != 'Partial Equal') {
                      _selectedMembersForPartialSplit.clear();
                    }
                    // Clear manual amount controllers if changing type
                    if (_splitType != 'Manual') {
                      _manualAmountControllers.forEach((key, controller) {
                        controller.clear();
                      });
                    }
                  });
                },
                decoration: const InputDecoration(labelText: "Split Type"),
              ),
              const SizedBox(height: 20),
              if (_splitType == 'Manual') ...widget.members.map((uid) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextFormField(
                    controller: _manualAmountControllers[uid],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "${_getUserDisplayName(uid)}'s share", // Use helper for display
                    ),
                  ),
                );
              }).toList(),
              if (_splitType == 'Partial Equal')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select members to split among:", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    ...widget.members.map((uid) {
                      return CheckboxListTile(
                        title: Text(_getUserDisplayName(uid)), // Use helper for display
                        value: _selectedMembersForPartialSplit.contains(uid),
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedMembersForPartialSplit.add(uid);
                            } else {
                              _selectedMembersForPartialSplit.remove(uid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: const Text("Add Expense"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (var controller in _manualAmountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
*/