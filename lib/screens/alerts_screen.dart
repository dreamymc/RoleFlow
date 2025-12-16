import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  // --- LOGIC: IS THIS TASK WORTH ALERTING? ---
  bool _shouldShowAlert(Map<String, dynamic> data) {
    final reminderTs = data['reminder'] as Timestamp?;
    final deadlineTs = data['deadline'] as Timestamp?;

    // 1. If it has no reminder and no deadline, ignore it.
    if (reminderTs == null && deadlineTs == null) return false;

    final now = DateTime.now();

    // 2. CHECK REMINDER (Show if we are within the 5-minute window or past it)
    if (reminderTs != null) {
      final reminderTime = reminderTs.toDate();
      final alertStartTime = reminderTime.subtract(const Duration(minutes: 5));

      if (now.isAfter(alertStartTime)) {
        return true;
      }
    }

    // 3. CHECK DEADLINE (If it's overdue, always show it)
    if (deadlineTs != null) {
      final deadlineTime = deadlineTs.toDate();
      if (now.isAfter(deadlineTime)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String currentUserId = user!.uid;
    final dateFormat = DateFormat('MMM d, h:mm a');

    // 1. OUTER STREAM: Fetch Roles (To get Name & Color)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('roles')
          .snapshots(),
      builder: (context, roleSnapshot) {
        // Create a Lookup Map for Roles:  ID -> {name, color}
        Map<String, Map<String, dynamic>> roleMap = {};
        if (roleSnapshot.hasData) {
          for (var doc in roleSnapshot.data!.docs) {
            roleMap[doc.id] = doc.data() as Map<String, dynamic>;
          }
        }

        // 2. INNER STREAM: Fetch Pending Tasks
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('tasks')
              .where('isCompleted', isEqualTo: false)
              .snapshots(),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            // Filter tasks: Must belong to user AND meet time criteria
            final alerts = taskSnapshot.data!.docs.where((doc) {
              final isMyTask = doc.reference.path.contains(
                'users/$currentUserId',
              );
              if (!isMyTask) return false;

              return _shouldShowAlert(doc.data() as Map<String, dynamic>);
            }).toList();

            if (alerts.isEmpty) return _buildEmptyState();

            // Sort by Deadline
            alerts.sort((a, b) {
              final aTs =
                  (a.data() as Map<String, dynamic>)['deadline'] as Timestamp?;
              final bTs =
                  (b.data() as Map<String, dynamic>)['deadline'] as Timestamp?;
              final aTime = aTs?.toDate() ?? DateTime(2100);
              final bTime = bTs?.toDate() ?? DateTime(2100);
              return aTime.compareTo(bTime);
            });

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = alerts[index];
                final data = doc.data() as Map<String, dynamic>;
                final deadlineTs = data['deadline'] as Timestamp?;
                final roleId = data['roleId'] as String? ?? 'unknown';

                // LOOKUP ROLE DATA
                final roleData = roleMap[roleId];
                final roleName = roleData != null
                    ? roleData['name']
                    : 'Unknown Role';
                final roleColorVal = roleData != null
                    ? roleData['color']
                    : 0xFF9E9E9E; // Default Grey
                final roleColor = Color(roleColorVal);

                // Determine Overdue State
                bool isOverdue = false;
                String timeText = "No Deadline";

                if (deadlineTs != null) {
                  final dueTime = deadlineTs.toDate();
                  timeText = "Due ${dateFormat.format(dueTime)}";
                  if (DateTime.now().isAfter(dueTime)) {
                    isOverdue = true;
                    timeText = "OVERDUE • $timeText";
                  }
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border(
                      left: BorderSide(
                        color: isOverdue ? Colors.red : roleColor,
                        width: 6,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ROW 1: Role Name (Chip) & Date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                roleName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (deadlineTs != null)
                              Row(
                                children: [
                                  Icon(
                                    isOverdue ? Icons.error : Icons.access_time,
                                    size: 14,
                                    color: isOverdue ? Colors.red : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isOverdue
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isOverdue
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ROW 2: Task Title & Checkbox
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['title'] ?? 'Untitled Task',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                // Mark as done instantly
                                doc.reference.update({'isCompleted': true});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "You're all caught up!",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
