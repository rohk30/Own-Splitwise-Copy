import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/*
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
  String _title = '';
  double _amount = 0.0;
  String? _selectedPayer;
  Map<String, double> _splitAmounts = {};

  @override
  void initState() {
    super.initState();
    for (var member in widget.members) {
      _splitAmounts[member] = 0.0;
    }
  }

  void _submitExpense() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final splitDetails = <String, double>{};
      _splitAmounts.forEach((member, amount) {
        if (amount > 0) {
          splitDetails[member] = amount;
        }
      });

      final docRef = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.groupCode)
          .collection('expenses')
          .add({
        'title': _title,
        'amount': _amount,
        'payerId': _selectedPayer,
        'payerName': widget.memberEmails[_selectedPayer] ?? _selectedPayer,
        'splitType': 'manual',
        'splitDetails': splitDetails,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update trip-level summary
      await _updateTripSummary(splitDetails);

      Navigator.pop(context);
    }
  }

  Future<void> _updateTripSummary(Map<String, double> splitDetails) async {
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(widget.groupCode);
    final tripDoc = await tripRef.get();
    final existingSplits = Map<String, dynamic>.from(tripDoc.data()?['overallSplit'] ?? {});

    splitDetails.forEach((userId, amount) {
      if (userId == _selectedPayer) return;
      final key = '$userId owes $_selectedPayer';
      existingSplits[key] = (existingSplits[key] ?? 0) + amount;
    });

    await tripRef.update({
      'overallSplit': existingSplits,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Expense Title'),
                onSaved: (val) => _title = val ?? '',
                validator: (val) => val == null || val.isEmpty ? 'Enter a title' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                onSaved: (val) => _amount = double.tryParse(val ?? '0') ?? 0,
                validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid amount' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPayer,
                items: widget.members.map((member) {
                  return DropdownMenuItem<String>(
                    value: member,
                    child: Text(widget.memberEmails[member] ?? member),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPayer = val),
                decoration: const InputDecoration(labelText: 'Paid By'),
                validator: (val) => val == null ? 'Select a payer' : null,
              ),
              const SizedBox(height: 16),
              const Text('Split Amounts:'),
              ...widget.members.map((member) {
                return Row(
                  children: [
                    Expanded(child: Text(widget.memberEmails[member] ?? member)),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '₹0'),
                        onSaved: (val) => _splitAmounts[member] = double.tryParse(val ?? '0') ?? 0,
                      ),
                    ),
                  ],
                );
              }).toList(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitExpense,
                child: const Text("Add Expense"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}     */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/*
class AddExpenseScreen extends StatefulWidget {
  final String groupCode;
  final List<String> members;
  final Map<String, String> memberEmails;

  const AddExpenseScreen({
    super.key,
    required this.groupCode,
    required this.members,
    required this.memberEmails,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedPayer;
  String _splitType = 'equal_all';

  Set<String> _selectedMembers = {};
  Map<String, String> _unequalSplits = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.members.isNotEmpty) {
      _selectedPayer = widget.members.first;
      _selectedMembers = widget.members.toSet();
    }
  }

  Future<void> _saveExpense() async {
    final desc = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (desc.isEmpty || amount == null || _selectedPayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    List<String> splitBetween;
    Map<String, double> splits = {};

    if (_splitType == 'equal_all') {
      splitBetween = widget.members;
      final splitAmount = amount / splitBetween.length;
      for (var uid in splitBetween) {
        splits[uid] = double.parse(splitAmount.toStringAsFixed(2));
      }
    } else if (_splitType == 'equal_selected') {
      if (_selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one member.')),
        );
        return;
      }
      splitBetween = _selectedMembers.toList();
      final splitAmount = amount / splitBetween.length;
      for (var uid in splitBetween) {
        splits[uid] = double.parse(splitAmount.toStringAsFixed(2));
      }
    } else if (_splitType == 'unequal_value') {
      double totalEntered = 0;
      for (var uid in _selectedMembers) {
        final val = double.tryParse(_unequalSplits[uid]?.trim() ?? '');
        if (val == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid amount for ${widget.memberEmails[uid] ?? uid}')),
          );
          return;
        }
        splits[uid] = val;
        totalEntered += val;
      }
      if ((totalEntered - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unequal splits must sum to total amount.')),
        );
        return;
      }
      splitBetween = _selectedMembers.toList();
    } else {
      return; // invalid type
    }

    setState(() => _isLoading = true);

    final expenseData = {
      'description': desc,
      'amount': amount,
      'paidBy': _selectedPayer,
      'splitBetween': splitBetween,
      'splitType': _splitType,
      'splits': splits,
      'createdAt': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.groupCode)
        .collection('expenses')
        .add(expenseData);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPayer,
              decoration: const InputDecoration(
                labelText: 'Paid By',
                border: OutlineInputBorder(),
              ),
              items: widget.members.map((uid) {
                final email = widget.memberEmails[uid] ?? uid;
                return DropdownMenuItem(
                  value: uid,
                  child: Text(email),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedPayer = val;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('Split Type', style: TextStyle(fontWeight: FontWeight.bold)),
            Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Equal among all members'),
                  value: 'equal_all',
                  groupValue: _splitType,
                  onChanged: (val) => setState(() => _splitType = val!),
                ),
                RadioListTile<String>(
                  title: const Text('Equal among selected members'),
                  value: 'equal_selected',
                  groupValue: _splitType,
                  onChanged: (val) => setState(() {
                    _splitType = val!;
                    _selectedMembers = widget.members.toSet();
                  }),
                ),
                RadioListTile<String>(
                  title: const Text('Unequal by value'),
                  value: 'unequal_value',
                  groupValue: _splitType,
                  onChanged: (val) => setState(() {
                    _splitType = val!;
                    _selectedMembers = widget.members.toSet();
                  }),
                ),
              ],
            ),

            if (_splitType == 'equal_selected' || _splitType == 'unequal_value')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text('Select Members'),
                  ...widget.members.map((uid) {
                    final email = widget.memberEmails[uid] ?? uid;
                    return CheckboxListTile(
                      title: Text(email),
                      value: _selectedMembers.contains(uid),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedMembers.add(uid);
                          } else {
                            _selectedMembers.remove(uid);
                          }
                        });
                      },
                    );
                  }).toList(),
                ],
              ),

            if (_splitType == 'unequal_value')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text('Enter split amounts'),
                  ..._selectedMembers.map((uid) {
                    final email = widget.memberEmails[uid] ?? uid;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount for $email',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          _unequalSplits[uid] = val;
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveExpense,
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}     */

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

  @override
  void initState() {
    super.initState();
    for (var uid in widget.members) {
      _manualAmountControllers[uid] = TextEditingController();
    }
    _selectedPayer = widget.members.isNotEmpty ? widget.members.first : null;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final String title = _titleController.text.trim();
    final double totalAmount = double.parse(_amountController.text.trim());
    final Map<String, double> splits = {};

    if (_splitType == 'Equal') {
      final double splitAmount = totalAmount / widget.members.length;
      for (var uid in widget.members) {
        splits[uid] = double.parse(splitAmount.toStringAsFixed(2));
      }
    } else if (_splitType == 'Manual') {
      double sum = 0;
      for (var uid in widget.members) {
        double userAmount = double.tryParse(_manualAmountControllers[uid]!.text.trim()) ?? 0.0;
        splits[uid] = userAmount;
        sum += userAmount;
      }
      if (sum != totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual amounts do not sum up to total amount.')),
        );
        return;
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
      }
      for (var uid in widget.members) {
        if (!splits.containsKey(uid)) splits[uid] = 0.0;
      }
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
                  child: Text(widget.memberEmails[uid] ?? uid),
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
                onChanged: (val) => setState(() => _splitType = val!),
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
                      labelText: "${widget.memberEmails[uid] ?? uid}'s share",
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
                        title: Text(widget.memberEmails[uid] ?? uid),
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
