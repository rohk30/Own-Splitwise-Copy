import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_expense_screen.dart';
import 'expense_details_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final String groupCode;

  const TripDetailsScreen({super.key, required this.groupCode});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  late DocumentReference tripRef;
  late String currentUserId;
  Map<String, dynamic>? tripData;
  List<String> memberIds = [];
  Map<String, String> memberEmails = {};
  bool isLoading = true;
  bool isOwner = false;

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    tripRef = FirebaseFirestore.instance.collection('trips').doc(widget.groupCode);
    fetchTripData();
  }

  Future<void> fetchTripData() async {
    final doc = await tripRef.get();
    if (doc.exists) {
      tripData = doc.data() as Map<String, dynamic>;
      memberIds = List<String>.from(tripData!['members']);
      isOwner = tripData!['createdBy'] == currentUserId;
      await fetchMemberEmails();
    }
    setState(() => isLoading = false);
  }

  Future<void> fetchMemberEmails() async {
    for (var uid in memberIds) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        memberEmails[uid] = userDoc['email'] ?? 'Unknown';
      }
    }
  }

  Future<void> addMemberByEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() => isLoading = true);

    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found.')));
      setState(() => isLoading = false);
      return;
    }

    final newUserId = userQuery.docs.first.id;

    await tripRef.update({
      'members': FieldValue.arrayUnion([newUserId])
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(newUserId)
        .update({
      'tripIDs': FieldValue.arrayUnion([widget.groupCode])
    });

    _emailController.clear();
    await fetchTripData();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Member added!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tripData?['tripName'] ?? 'Unnamed Trip',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Group Code: ${widget.groupCode}'),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.groupCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')));
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Members:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: memberIds.length,
                itemBuilder: (context, index) {
                  final uid = memberIds[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(memberEmails[uid] ?? 'Unknown'),
                    subtitle: Text(uid),
                  );
                },
              ),
            ),
            if (isOwner || !isOwner) ...[
              const Divider(),
              const Text(
                'Expenses:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.groupCode)
                      .collection('expenses')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final expenses = snapshot.data!.docs;

                    if (expenses.isEmpty) {
                      return const Center(child: Text("No expenses yet"));
                    }

                    return ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        final data = expense.data() as Map<String, dynamic>;
                        final String title = data['description'] ?? 'No Title';
                        // title = title.toCapitalized();
                        final amount = data['amount'] ?? 0;

                        return ListTile(
                          title: Text(title),
                          subtitle: Text('₹$amount'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpenseDetailsScreen(
                                  tripId: widget.groupCode,
                                  expenseId: expense.id,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                          groupCode: widget.groupCode,
                          members: memberIds,
                          memberEmails: memberEmails
                      ),
                    ),
                  );
                },
                child: const Text('Add Expense'),
              ),
              const Divider(),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Add member by email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: addMemberByEmail,
                child: const Text('Add Member'),
              ),

            ],
          ],
        ),
      ),
    );
  }
}