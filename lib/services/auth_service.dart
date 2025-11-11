import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // -------------------- auth (existing) --------------------
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
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    return _auth.signInWithCredential(cred);
  }

  // -------------------- FCM device token sync --------------------
  /// Saves this device's FCM token to the driver's Firestore doc so the backend
  /// can notify the correct (last logged-in) phone on assignment.
  ///
  /// If [driverId] is omitted, the current FirebaseAuth UID is used.
  Future<void> syncDeviceToken({String? driverId}) async {
    // Resolve driver id
    final uid = driverId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      // Not logged in yet; nothing to do
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // iOS permission prompt (Android is auto-granted).
    // Safe to call on Android too; it no-ops there.
    await messaging.requestPermission();

    // Current token
    final token = await messaging.getToken();

    if (token != null && token.isNotEmpty) {
      await _db.doc('drivers/$uid').set({
        'lastFcmToken': token,                          // use this to hit last phone only
        'fcmTokens': FieldValue.arrayUnion([token]),    // or notify all devices if you prefer
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Keep Firestore up to date when FCM rotates the token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      await _db.doc('drivers/$uid').set({
        'lastFcmToken': newToken,
        'fcmTokens': FieldValue.arrayUnion([newToken]),
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
