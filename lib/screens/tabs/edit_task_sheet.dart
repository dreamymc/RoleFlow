import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart'; // Ensure path is correct

class EditTaskSheet extends StatefulWidget {
  final Task task;
  final String roleId;
  final Color roleColor;

  const EditTaskSheet({
    super.key, 
    required this.task, 
    required this.roleId, 
    required this.roleColor
  });

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<EditTaskSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  
  late DateTime _deadline;
  DateTime? _reminder;
  
  bool _isSaving = false;
  String? _logicError; 

  @override
  void initState() {
    super.initState();
    // Pre-fill data from the existing task
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _deadline = widget.task.deadline;
    _reminder = widget.task.reminder;
  }

  // --- 1. LOGIC GATE (Same as Add Sheet) ---
  void _validateLogic() {
    setState(() {
      if (_reminder != null && _reminder!.isAfter(_deadline)) {
        _logicError = "🚫 LOGIC ERROR: You cannot be reminded AFTER the deadline.";
      } else {
        _logicError = null;
      }
    });
  }

  // --- 2. DATE PICKERS ---
  Future<void> _pickDateTime(bool isDeadline) async {
    final now = DateTime.now();
    final initialDate = isDeadline ? _deadline : (_reminder ?? now);
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020), // Allow editing past tasks?
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: widget.roleColor),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null) return;

    final combinedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isDeadline) {
        _deadline = combinedDateTime;
      } else {
        _reminder = combinedDateTime;
      }
    });

    _validateLogic();
  }

  // --- 3. UPDATE FUNCTION ---
  Future<void> _updateTask() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_logicError != null) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Update the specific document using widget.task.id
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('roles')
          .doc(widget.roleId)
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'deadline': Timestamp.fromDate(_deadline),
        'reminder': _reminder != null ? Timestamp.fromDate(_reminder!) : null,
        // We don't change createdAt or isCompleted here usually
      });

      if (mounted) Navigator.pop(context); 
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- 4. DELETE FUNCTION ---
  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('roles')
          .doc(widget.roleId)
          .collection('tasks')
          .doc(widget.task.id)
          .delete();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy - h:mm a');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20, 
        right: 20, 
        top: 20
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit Task',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.roleColor),
              ),
              // TRASH ICON
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _isSaving ? null : _deleteTask,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // DEADLINE
          InkWell(
            onTap: () => _pickDateTime(true),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Deadline', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(dateFormat.format(_deadline), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // REMINDER
          InkWell(
            onTap: () => _pickDateTime(false),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: _logicError != null ? Colors.red : Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.alarm, color: _logicError != null ? Colors.red : widget.roleColor),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reminder', style: TextStyle(fontSize: 12, color: _logicError != null ? Colors.red : Colors.grey)),
                      Text(
                        _reminder == null ? 'No Reminder' : dateFormat.format(_reminder!),
                        style: TextStyle(fontWeight: FontWeight.bold, color: _logicError != null ? Colors.red : Colors.black),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_reminder != null)
                     IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() { _reminder = null; _validateLogic(); });
                      },
                    )
                ],
              ),
            ),
          ),

          if (_logicError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_logicError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: (_isSaving || _logicError != null) ? null : _updateTask,
            style: FilledButton.styleFrom(backgroundColor: widget.roleColor, padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save_as),
            label: const Text('Update Task'),
          ),
        ],
      ),
    );
  }
}