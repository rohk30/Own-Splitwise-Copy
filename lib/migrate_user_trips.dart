import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateUserTrips() async {
  final firestore = FirebaseFirestore.instance;

  print("🚀 Starting user–trip migration...");

  final tripsSnapshot = await firestore.collection('trips').get();

  for (final tripDoc in tripsSnapshot.docs) {
    final tripId = tripDoc.id;
    final data = tripDoc.data();

    final membersRaw = data['members'];

    // SAFETY CHECK
    if (membersRaw == null) {
      print("⚠️ Trip $tripId has no members field. Skipping.");
      continue;
    }

    List<String> memberIds = [];

    // CASE 1: members is a List (correct schema)
    if (membersRaw is List) {
      memberIds = membersRaw.map((e) => e.toString()).toList();
    }

    // CASE 2: members is a Map (legacy / bad schema)
    else if (membersRaw is Map) {
      memberIds = membersRaw.keys.map((e) => e.toString()).toList();
      print("⚠️ Trip $tripId has members as Map. Using keys as userIds.");
    }

    // CASE 3: Unknown type
    else {
      print(
        "❌ Trip $tripId has invalid members type: ${membersRaw.runtimeType}",
      );
      continue;
    }

    // Update each user
    for (final uid in memberIds) {
      await firestore.collection('users').doc(uid).set({
        'trips': FieldValue.arrayUnion([tripId]),
      }, SetOptions(merge: true));

      print("✅ Added trip $tripId to user $uid");
    }
  }

  print("🎉 Migration completed successfully.");
}
