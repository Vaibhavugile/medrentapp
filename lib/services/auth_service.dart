import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // -------------------- auth (existing) --------------------
  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> signOut() => _auth.signOut();

  // Email login
  Future<UserCredential> signInWithEmail(String email, String pass) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: pass,
    );
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

  Future<UserCredential> signInWithSmsCode(
    String verificationId,
    String code,
  ) {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    return _auth.signInWithCredential(cred);
  }

  // -------------------- ROLE RESOLUTION (NEW) --------------------
  /// Determines the logged-in user's role using Firestore.
  /// Order matters: Driver → Marketing → Staff (Nurse/Caretaker)
  Future<String> resolveUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not logged in');
    }

    // 1️⃣ DRIVER
    final driverDoc = await _db.collection('drivers').doc(uid).get();
    if (driverDoc.exists) {
      if (driverDoc.data()?['active'] == false) {
        throw Exception('Driver account is inactive');
      }
      return 'driver';
    }

    // 2️⃣ MARKETING
    final marketingDoc = await _db.collection('marketing').doc(uid).get();
    if (marketingDoc.exists) {
      if (marketingDoc.data()?['active'] == false) {
        throw Exception('Marketing account is inactive');
      }
      return 'marketing';
    }

    // 3️⃣ STAFF (NURSE / CARETAKER)
    final staffDoc = await _db.collection('staff').doc(uid).get();
    if (staffDoc.exists) {
      if (staffDoc.data()?['active'] == false) {
        throw Exception('Staff account is inactive');
      }
      return 'staff';
    }

    // 🚫 No role found
    throw Exception('No role assigned to this account');
  }

  // -------------------- FCM device token sync --------------------
  /// Saves this device's FCM token to the DRIVER Firestore doc.
  /// (Staff/Marketing tokens can be added later if needed.)
  Future<void> syncDeviceToken({String? driverId}) async {
    final uid = driverId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    final token = await messaging.getToken();

    if (token != null && token.isNotEmpty) {
      await _db.doc('drivers/$uid').set({
        'lastFcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

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
