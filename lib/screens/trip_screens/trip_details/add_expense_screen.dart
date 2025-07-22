import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}
