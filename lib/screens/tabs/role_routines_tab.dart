import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/role.dart';
import '../../models/routine_model.dart';
import 'routine_card.dart'; // <--- THIS IS THE KEY IMPORT

class RoleRoutinesTab extends StatelessWidget {
  final Role role;
  const RoleRoutinesTab({super.key, required this.role});

  // --- LOGIC 1: INCREMENT (Weekly + Lifetime) ---
  Future<void> _incrementRoutine(BuildContext context, Routine routine) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final routineRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('roles')
        .doc(role.id)
        .collection('routines')
        .doc(routine.id);

    // Update Count + Lifetime + Timestamp
    await routineRef.update({
      'count': FieldValue.increment(1),
      'totalLifetimeCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      _showJournalDialog(context, routine, routineRef);
    }
  }

  // --- LOGIC 2: UNDO ---
  Future<void> _undoRoutine(BuildContext context, Routine routine) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('roles')
        .doc(role.id)
        .collection('routines')
        .doc(routine.id)
        .update({
      'count': FieldValue.increment(-1),
      'totalLifetimeCount': FieldValue.increment(-1),
      // Reset date to unlock button (Year 2000)
      'lastUpdated': DateTime(2000, 1, 1), 
    });
  }

  // --- LOGIC 3: JOURNAL DIALOG ---
  void _showJournalDialog(BuildContext context, Routine routine, DocumentReference routineRef) {
    final noteController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
          left: 20, 
          right: 20, 
          top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Checked In! ✅",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Great work on '${routine.title}'!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Add a quick note (Optional)',
                hintText: 'e.g., Felt tired but pushed through...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final note = noteController.text.trim();
                if (note.isNotEmpty) {
                  await routineRef.collection('logs').add({
                    'note': note,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: role.color),
              child: const Text("Done"),
            )
          ],
        ),
      ),
    );
  }

  // Helper to check if "Done Today"
  bool _isDoneToday(DateTime lastUpdated) {
    final now = DateTime.now();
    return now.year == lastUpdated.year && 
           now.month == lastUpdated.month && 
           now.day == lastUpdated.day;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('roles')
          .doc(role.id)
          .collection('routines')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading routines'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "No routines yet. Tap 'Routine' to add one.",
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final routine = Routine.fromFirestore(data, docs[index].id);

            // -----------------------------------------------------------
            // THIS CONNECTS TO THE ANIMATED CARD
            // -----------------------------------------------------------
            return RoutineCard(
              routine: routine,
              role: role,
              isCompletedToday: _isDoneToday(routine.lastUpdated),
              onIncrement: () => _incrementRoutine(context, routine),
              onUndo: () => _undoRoutine(context, routine),
            );
          },
        );
      },
    );
  }
}