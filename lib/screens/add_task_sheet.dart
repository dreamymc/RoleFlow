import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskSheet extends StatefulWidget {
  final String roleId;
  final Color roleColor;

  const AddTaskSheet({super.key, required this.roleId, required this.roleColor});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  DateTime _deadline = DateTime.now().add(const Duration(hours: 24));
  DateTime? _reminder;
  
  bool _isSaving = false;
  String? _logicError;

  void _validateLogic() {
    setState(() {
      if (_reminder != null && _reminder!.isAfter(_deadline)) {
        _logicError = "🚫 LOGIC ERROR: You cannot be reminded AFTER the deadline.";
      } else {
        _logicError = null;
      }
    });
  }

  Future<void> _pickDateTime(bool isDeadline) async {
    final now = DateTime.now();
    final initialDate = isDeadline ? _deadline : (_reminder ?? now);
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
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
      builder: (context, child) {
        return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: widget.roleColor),
            ),
            child: child!,
        );
      },
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

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_logicError != null) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Save to Firestore ONLY (No notifications)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('roles')
          .doc(widget.roleId)
          .collection('tasks')
          .add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'deadline': Timestamp.fromDate(_deadline),
        'reminder': _reminder != null ? Timestamp.fromDate(_reminder!) : null,
        'isCompleted': false,
        'roleId': widget.roleId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
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
          Text(
            'New Logic-Gated Task',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: widget.roleColor,
            ),
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Task Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.check_box_outlined),
            ),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description / Notes',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 20),

          // Deadline Picker
          InkWell(
            onTap: () => _pickDateTime(true),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Deadline (Hard Limit)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(dateFormat.format(_deadline), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Reminder Picker
          InkWell(
            onTap: () => _pickDateTime(false),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _logicError != null ? Colors.red : Colors.grey.shade400,
                  width: _logicError != null ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.alarm, color: _logicError != null ? Colors.red : widget.roleColor),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminder Notification', 
                        style: TextStyle(fontSize: 12, color: _logicError != null ? Colors.red : Colors.grey)
                      ),
                      Text(
                        _reminder == null ? 'No Reminder Set' : dateFormat.format(_reminder!),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _logicError != null ? Colors.red : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_reminder != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() {
                          _reminder = null;
                          _validateLogic();
                        });
                      },
                    )
                ],
              ),
            ),
          ),

          if (_logicError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _logicError!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: (_isSaving || _logicError != null) ? null : _saveTask,
            style: FilledButton.styleFrom(
              backgroundColor: widget.roleColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.save),
            label: const Text('Add Logic-Gated Task'),
          ),
        ],
      ),
    );
  }
}