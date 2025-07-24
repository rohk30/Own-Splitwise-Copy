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

class ExpenseDetailsScreen extends StatelessWidget {
  final String tripId;
  final String expenseId;
  final Map<String, String> memberEmails;

  const ExpenseDetailsScreen({
    super.key,
    required this.tripId,
    required this.expenseId,
    required this.memberEmails,
  });

  Future<Map<String, String>> fetchUserNames(List<String> userIds) async {
    final Map<String, String> userNames = {};

    for (String uid in userIds) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        userNames[uid] = userDoc['email'] ?? 'Unknown';
      } else {
        userNames[uid] = 'Unknown';
      }
    }

    return userNames;
  }

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
          final title = data['description'] ?? 'No Title';
          final amount = data['amount'] ?? 0;
          final payerId = data['paidBy'] ?? 'Unknown';
          final splitType = data['splitType'] ?? 'N/A';
          final splits = Map<String, dynamic>.from(data['splits'] ?? {});

          final participantIds = splits.keys.toList();

          return FutureBuilder<Map<String, String>>(
            future: fetchUserNames(participantIds),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userNames = userSnapshot.data!;
              final payerName = userNames[payerId] ?? 'Unknown';

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
                        itemCount: splits.length,
                        itemBuilder: (context, index) {
                          final uid = splits.keys.elementAt(index);
                          final userAmount = splits[uid];
                          final userName = userNames[uid] ?? uid;
                          return ListTile(
                            title: Text(userName),
                            trailing: Text("₹$userAmount"),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
