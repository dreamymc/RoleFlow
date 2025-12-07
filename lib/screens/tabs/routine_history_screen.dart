import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/role.dart';
import '../../models/routine_model.dart';

class RoutineHistoryScreen extends StatelessWidget {
  final Routine routine;
  final Role role;

  const RoutineHistoryScreen({
    super.key,
    required this.routine,
    required this.role,
  });

  // --- LOGIC 1: DELETE LOG ENTRY (The Data Fix) ---
  Future<void> _deleteLogEntry(BuildContext context, String logId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Delete the log document from the subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('roles')
        .doc(role.id)
        .collection('routines')
        .doc(routine.id)
        .collection('logs')
        .doc(logId)
        .delete();

    // 2. Synchronize the parent routine's counter (Decrement -1)
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
        });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log entry deleted and counter synchronized.'),
        ),
      );
    }
  }

  // --- LOGIC 2: EDIT LOG ENTRY (Tap-to-Edit) ---
  void _editLogNote(BuildContext context, String logId, String currentNote) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final TextEditingController controller = TextEditingController(
      text: currentNote,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Log Note"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Your updated note"),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('roles')
                    .doc(role.id)
                    .collection('routines')
                    .doc(routine.id)
                    .collection('logs')
                    .doc(logId)
                    .update({
                      'note': controller.text.trim(),
                      'editedAt':
                          FieldValue.serverTimestamp(), // Audit trail tag
                    });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final startStr = DateFormat('MMMM d, yyyy').format(routine.startDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(routine.title),
        backgroundColor: role.color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ------------------------------------------
          // 1. THE HERO HEADER (Legacy Stats)
          // ------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: role.color.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: role.color.withOpacity(0.2)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 32,
                      color: Colors.orange[800],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${routine.totalLifetimeCount}",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: role.color,
                      ),
                    ),
                  ],
                ),
                const Text(
                  "Lifetime Check-ins",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    "Started on $startStr",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                if (routine.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    routine.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[800],
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ------------------------------------------
          // 2. THE TIMELINE (Logs)
          // ------------------------------------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('roles')
                  .doc(role.id)
                  .collection('routines')
                  .doc(routine.id)
                  .collection('logs')
                  .orderBy('timestamp', descending: true) // Newest first
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_edu,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No history yet.",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Check in to start your journal.",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final logId = docs[index].id;
                    final timestamp =
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    final note = data['note'] as String? ?? '';
                    final isEdited = data.containsKey(
                      'editedAt',
                    ); // Check for audit trail

                    // Formatting
                    final dateLabel = DateFormat('MMM d').format(timestamp);
                    final timeLabel = DateFormat('h:mm a').format(timestamp);

                    return Dismissible(
                      key: Key(logId), // Key needed for Dismissible
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        color: Colors.red,
                        child: const Icon(
                          Icons.delete_forever,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Confirm Deletion"),
                          content: const Text(
                            "Are you sure you want to permanently delete this log entry?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                "Delete",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      onDismissed: (direction) =>
                          _deleteLogEntry(context, logId),

                      // Timeline Row Content
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Date/Timeline
                          SizedBox(
                            width: 50,
                            child: Column(
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  width: 2,
                                  height: 40,
                                  color: Colors.grey[200],
                                ),
                              ],
                            ),
                          ),

                          // Right: Card bubble (Editable on Tap)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _editLogNote(context, logId, note),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: role.color,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Checked In at $timeLabel",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (isEdited)
                                          Tooltip(
                                            message:
                                                "Note was edited after initial entry.",
                                            child: Text(
                                              "*Edited*",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.red[500],
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (note.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        note,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
