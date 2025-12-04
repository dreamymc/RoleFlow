import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roleflow_app/screens/tabs/edit_task_sheet.dart';
import '../../models/role.dart';
import '../../models/task_model.dart'; // Ensure you have this model from Phase A

class RoleTasksTab extends StatelessWidget {
  final Role role;

  const RoleTasksTab({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      // Listen to the specific Role's task collection
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('roles')
          .doc(role.id)
          .collection('tasks')
          .orderBy('deadline', descending: false) // Show urgent tasks first
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading tasks'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "No pending tasks.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                Text(
                  "Tap '+' to add a logic-gated task.",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80), // Space for FAB
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final task = Task.fromFirestore(data, docs[index].id);
            final dateFormat = DateFormat('MMM dd • h:mm a');

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                // CHECKBOX (To Complete Task)
                leading: Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    activeColor: role.color,
                    shape: const CircleBorder(),
                    value: task.isCompleted,
                    onChanged: (val) async {
                      // Toggle completion in Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('roles')
                          .doc(role.id)
                          .collection('tasks')
                          .doc(task.id)
                          .update({'isCompleted': val});
                    },
                  ),
                ),
                // TITLE & DESCRIPTION
                title: Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.isCompleted ? Colors.grey : Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // DEADLINE BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: role.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: role.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy, size: 12, color: role.color),
                          const SizedBox(width: 4),
                          Text(
                            "Due: ${dateFormat.format(task.deadline)}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: role.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  // Import edit_task_sheet.dart at the top first!
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => EditTaskSheet(
                      task: task, // Pass the task object we clicked
                      roleId: role.id,
                      roleColor: role.color,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
