import 'package:cloud_firestore/cloud_firestore.dart';
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