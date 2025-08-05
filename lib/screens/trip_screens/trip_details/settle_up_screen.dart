import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SettleUpScreen extends StatefulWidget {
  final String groupCode;
  final String payerName;

  const SettleUpScreen({
    required this.groupCode,
    required this.payerName,
    super.key,
  });

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  bool isSettling = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settle Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isSettling
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.done_all),
              label: const Text('Settle All Debts'),
              onPressed: _settleAllExpenses,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _settleAllExpenses() async {
    setState(() => isSettling = true);

    final tripRef = FirebaseFirestore.instance.collection('trips').doc(widget.groupCode);
    final expensesRef = tripRef.collection('expenses');

    // Fetch all expenses that are not settled
    final unsettledExpenses = await expensesRef.where('settled', isEqualTo: false).get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in unsettledExpenses.docs) {
      batch.update(doc.reference, {
        'settled': true,
        'settledBy': widget.payerName,
        'settledAt': FieldValue.serverTimestamp(),
      });
    }

    // Optional: Reset pairwise dues stored at trip level
    batch.update(tripRef, {'pairwiseDues': {}});

    await batch.commit();

    setState(() => isSettling = false);

    // Show confirmation dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('✅ All Settled!'),
          content: const Text(
            'All current expenses have been marked as settled.\n'
                'New expenses can still be added and will be shown normally.',
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // dismiss dialog
                Navigator.of(context).pop(); // go back
              },
            ),
          ],
        ),
      );
    }
  }
}
