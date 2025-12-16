import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../models/role.dart';

// Helper class to store the summary + the "Fingerprint" of the data that generated it
class _CachedSummary {
  final String text;
  final String dataFingerprint;

  _CachedSummary(this.text, this.dataFingerprint);
}

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // 1. IN-MEMORY CACHE (First line of defense)
  final Map<String, _CachedSummary> _cache = {};

  // 2. CONFIGURATION
  static final String _apiKey = dotenv.get('GEMINI_API_KEY');

  // Use the smart model
  final _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

  // 3. THE DEEP BRAIN ENGINE
  Future<String> generateRoleSummary(Role role) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Error: User not logged in.";

      final now = DateTime.now().toLocal();

      // --- STEP A: GATHER DEEP CONTEXT ---

      // 1. Tasks (Pending)
      final taskSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('roles')
          .doc(role.id)
          .collection('tasks')
          .where('isCompleted', isEqualTo: false)
          .get();

      // 2. Routines (Active)
      final routineSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('roles')
          .doc(role.id)
          .collection('routines')
          .get();

      // --- ZERO DATA GUARD (NEW) ---
      // If there is absolutely nothing, skip the AI entirely.
      if (taskSnap.docs.isEmpty && routineSnap.docs.isEmpty) {
        return "This role is a blank canvas! Add some tasks or habits to generate insights.";
      }

      // 3. Routine Logs (Mining for Context)
      StringBuffer logBuffer = StringBuffer();

      for (var doc in routineSnap.docs) {
        final routineName = doc['title'];
        final logs = await doc.reference
            .collection('logs')
            .orderBy('timestamp', descending: true)
            .limit(2)
            .get();

        if (logs.docs.isNotEmpty) {
          logBuffer.writeln("Notes for '$routineName':");
          for (var log in logs.docs) {
            final note = log['note'];
            if (note != null && note.toString().isNotEmpty) {
              logBuffer.writeln(" - '$note'");
            }
          }
        }
      }

      // --- STEP B: GENERATE FINGERPRINT ---
      final taskListStr = taskSnap.docs
          .map((d) {
            final deadline = (d['deadline'] as Timestamp).toDate().toLocal();
            final todayStart = DateTime(now.year, now.month, now.day);
            final deadlineStart = DateTime(
              deadline.year,
              deadline.month,
              deadline.day,
            );
            final diff = deadlineStart.difference(todayStart).inDays;

            String statusLabel;
            if (diff < 0) {
              statusLabel = "[URGENT: OVERDUE by ${diff.abs()} days!]";
            } else if (diff == 0) {
              statusLabel = "[DUE TODAY]";
            } else {
              statusLabel = "(Due in $diff days)";
            }

            return "- ${d['title']} $statusLabel";
          })
          .join('\n');

      final routineListStr = routineSnap.docs
          .map((d) => "${d['title']}-${d['count']}/${d['target']}")
          .join('|');

      final logsStr = logBuffer.toString();

      final currentFingerprint = (taskListStr + routineListStr + logsStr)
          .hashCode
          .toString();

      // --- STEP C: CHECK DATABASE PERSISTENCE ---
      final roleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('roles')
          .doc(role.id)
          .get();

      final savedFingerprint = roleDoc.data()?['aiFingerprint'];
      final savedSummary = roleDoc.data()?['aiSummary'];

      if (savedFingerprint == currentFingerprint && savedSummary != null) {
        _cache[role.id] = _CachedSummary(savedSummary, currentFingerprint);
        print("🧠 Database Hit: Loading saved summary.");
        return savedSummary;
      }

      print("🔌 Data Changed. Calling Gemini API...");

      // --- STEP D: THE PROMPT ---
      final promptText =
          """
      You are analyzing the user's life role called '${role.name}'.
      
      CRITICAL INSTRUCTIONS:
      1. Speak directly to the user as "You". 
      2. NEVER address the user as "${role.name}" (that is a category, not a person).
      3. Give suggestions about what the user can do right now and DO NOT ask questions like "How about...".
      4. Just give a pure, specific analysis of their balance and consistency.
      5. Keep it natural, encouraging, and under 5 sentences.
      
      TODAY'S DATE: ${DateFormat('yyyy-MM-dd').format(now)}
      
      CURRENT DATA:
      
      [PENDING TASKS]
      $taskListStr
      ${taskListStr.isEmpty ? "(No pending tasks)" : ""}
      
      [HABIT ROUTINES]
      ${routineSnap.docs.map((d) => "- ${d['title']}: ${d['count']}/${d['target']} done").join('\n')}
      
      [RECENT NOTES (Context)]
      $logsStr
      """;

      // --- STEP E: CALL API & SAVE ---
      final content = [Content.text(promptText)];
      final response = await _model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        final validText = response.text!;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('roles')
            .doc(role.id)
            .update({
              'aiSummary': validText,
              'aiFingerprint': currentFingerprint,
              'aiLastUpdated': FieldValue.serverTimestamp(),
            });

        _cache[role.id] = _CachedSummary(validText, currentFingerprint);
        return validText;
      } else {
        return "AI Response was empty. Tap refresh to try again.";
      }
    } catch (e) {
      print("AI Error: $e");
      return "AI Service Unavailable. Tap refresh to try again.";
    }
  }
}
