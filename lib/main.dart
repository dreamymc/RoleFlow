import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import this
import 'firebase_options.dart';
import 'services/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Attempt to load the .env file
    // If this fails (file missing), it will jump to 'catch'
    await dotenv.load(fileName: ".env");
    print("✅ Environment variables loaded successfully.");
  } catch (e) {
    print("⚠️ WARNING: .env file not found or invalid. Using defaults/failing safely.");
    print("Error: $e");
    // We continue anyway so the app doesn't freeze, 
    // but the AI features might break later.
  }

  try {
    // 2. Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully.");
  } catch (e) {
    print("❌ CRITICAL: Firebase failed to initialize.");
    print("Error: $e");
  }

  runApp(const RoleFlowApp());
}

class RoleFlowApp extends StatelessWidget {
  const RoleFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoleFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}