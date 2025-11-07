import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> signOut() => _auth.signOut();

  // Email fallback
  Future<UserCredential> signInWithEmail(String email, String pass) {
    return _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  // Phone OTP
  Future<void> verifyPhone({
    required String phone,
    required Function(PhoneAuthCredential) onVerified,
    required Function(String, int?) onCodeSent,
    required Function(FirebaseAuthException) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: onVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> signInWithSmsCode(String verificationId, String code) {
    final cred = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code);
    return _auth.signInWithCredential(cred);
  }
}
