import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up
  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'invalid-email':
          return 'The email address is invalid.';
        default:
          return e.message;
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Sign in
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'invalid-email':
          return 'Invalid email format.';
        default:
          return e.message;
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
