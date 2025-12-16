import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream to listen to auth changes (Login/Logout)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- EMAIL & PASSWORD ---

  Future<String?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Create the user
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Send verification email immediately
      User? user = result.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      return null; // Return null means SUCCESS
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  // --- PROFILE MANAGEMENT ---

  // Updates the display name (Fixes the "RoleFlow User" issue)
  Future<void> updateUserName(String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
      // Force a local refresh of the user object so UI updates instantly
      await user.reload();
    }
  }

  // Helper to manually send verification email if needed later
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- GOOGLE SIGN IN ---

  Future<String?> signInWithGoogle() async {
    try {
      // 1. Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Google sign in cancelled by user.";

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Once signed in, return the UserCredential
      await _auth.signInWithCredential(credential);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Google sign in failed.';
    }
  }

  // --- LOGOUT ---

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Sign out of Google too
      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // --- ERROR HANDLER ---
  // This translates technical errors into "Human" language
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Error: ${e.message}';
    }
  }
}
