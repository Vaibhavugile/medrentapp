
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
  FocusScope.of(context).unfocus();
  setState(() {
    _error = null;
  });

  final name = _name.text.trim();
  final email = _email.text.trim().toLowerCase();
  final pass = _pass.text;

  if (name.isEmpty) {
    setState(() => _error = 'Please enter your name.');
    return;
  }
  if (email.isEmpty) {
    setState(() => _error = 'Please enter your email.');
    return;
  }
  if (pass.length < 6) {
    setState(() => _error = 'Password must be at least 6 characters.');
    return;
  }

  setState(() => _submitting = true);

  try {
    // 1️⃣ Check drivers by loginEmail
    final driverSnap = await _db
        .collection('drivers')
        .where('loginEmail', isEqualTo: email)
        .limit(1)
        .get();
    final isDriver = driverSnap.docs.isNotEmpty;

    // 2️⃣ Check marketing by loginEmail
    final marketingSnap = await _db
        .collection('marketing')
        .where('loginEmail', isEqualTo: email)
        .limit(1)
        .get();
    final isMarketing = marketingSnap.docs.isNotEmpty;

    // 3️⃣ Check staff (NURSE / CARETAKER) by loginEmail
    final staffSnap = await _db
        .collection('staff')
        .where('loginEmail', isEqualTo: email)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    final isStaff = staffSnap.docs.isNotEmpty;

    // 🚫 Block signup if email not created by admin
    if (!isDriver && !isMarketing && !isStaff) {
      throw Exception(
        'No account found for this email. Please contact admin.',
      );
    }

    // 4️⃣ Create Firebase Auth user
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: pass,
    );

    // 5️⃣ Set display name
    await cred.user!.updateDisplayName(name);

    // 6️⃣ Decide role
    final role = isDriver
        ? 'driver'
        : isMarketing
            ? 'marketing'
            : 'staff';

    // 7️⃣ Create /users/{uid}
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 8️⃣ Backfill authUid to DRIVER doc
    if (isDriver) {
      final id = driverSnap.docs.first.id;
      await _db.collection('drivers').doc(id).set({
        'authUid': cred.user!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 9️⃣ Backfill authUid to MARKETING doc
    if (isMarketing) {
      final id = marketingSnap.docs.first.id;
      await _db.collection('marketing').doc(id).set({
        'authUid': cred.user!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 🔟 Backfill authUid to STAFF doc (NURSE)
    if (isStaff) {
      final id = staffSnap.docs.first.id;
      await _db.collection('staff').doc(id).set({
        'authUid': cred.user!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 1️⃣1️⃣ Go back to login
    if (mounted) {
      Navigator.of(context).pop(); // back to LoginScreen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Please log in.'),
        ),
      );
    }
  } on FirebaseAuthException catch (e) {
    String msg = 'Something went wrong. Please try again.';
    if (e.code == 'email-already-in-use') {
      msg = 'That email is already in use.';
    } else if (e.code == 'invalid-email') {
      msg = 'Please enter a valid email address.';
    } else if (e.code == 'weak-password') {
      msg = 'Password is too weak (min 6 characters).';
    }
    setState(() => _error = msg);
  } catch (e) {
    setState(() => _error = e.toString());
  } finally {
    if (mounted) {
      setState(() => _submitting = false);
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name'),
                  enabled: !_submitting,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _email,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_submitting,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  enabled: !_submitting,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 12),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
                FilledButton(
                  onPressed: _submitting ? null : _onSubmit,
                  child: Text(_submitting ? 'Creating...' : 'Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
