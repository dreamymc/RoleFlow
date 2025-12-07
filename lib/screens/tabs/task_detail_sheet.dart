import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import 'edit_task_sheet.dart';

class TaskDetailSheet extends StatelessWidget {
  final Task task;
  final String roleId;
  final Color roleColor;

  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.roleId,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, yyyy • h:mm a');
    final isOverdue =
        task.deadline.isBefore(DateTime.now()) && !task.isCompleted;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Overdue/Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? Colors.red[50]
                      : (task.isCompleted
                            ? Colors.green[50]
                            : roleColor.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOverdue
                        ? Colors.red
                        : (task.isCompleted ? Colors.green : roleColor),
                  ),
                ),
                child: Text(
                  isOverdue
                      ? "OVERDUE"
                      : (task.isCompleted ? "COMPLETED" : "PENDING"),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOverdue
                        ? Colors.red
                        : (task.isCompleted ? Colors.green : roleColor),
                  ),
                ),
              ),
              // Edit Button (Pencil)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  // Close View Sheet first
                  Navigator.pop(context);
                  // Open Edit Sheet
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => EditTaskSheet(
                      task: task,
                      roleId: roleId,
                      roleColor: roleColor,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            task.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          if (task.description.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            )
          else
            Text(
              "No description provided.",
              style: TextStyle(
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),

          const SizedBox(height: 24),

          // Date Grid
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.event_busy,
                  label: "Deadline",
                  value: dateFormat.format(task.deadline),
                  color: isOverdue ? Colors.red : Colors.grey[800]!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoTile(
                  icon: Icons.alarm,
                  label: "Reminder",
                  value: task.reminder != null
                      ? dateFormat.format(task.reminder!)
                      : "None set",
                  color: Colors.grey[800]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40), // Bottom padding
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
