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
    setState(() => _error = null);

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

      final driverSnap = await _db
          .collection('drivers')
          .where('loginEmail', isEqualTo: email)
          .limit(1)
          .get();

      final marketingSnap = await _db
          .collection('marketing')
          .where('loginEmail', isEqualTo: email)
          .limit(1)
          .get();

      final staffSnap = await _db
          .collection('staff')
          .where('loginEmail', isEqualTo: email)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      final isDriver = driverSnap.docs.isNotEmpty;
      final isMarketing = marketingSnap.docs.isNotEmpty;
      final isStaff = staffSnap.docs.isNotEmpty;

      if (!isDriver && !isMarketing && !isStaff) {
        throw Exception(
          'No account found for this email. Please contact admin.',
        );
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      await cred.user!.updateDisplayName(name);

      final role = isDriver
          ? 'driver'
          : isMarketing
              ? 'marketing'
              : 'staff';

      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (isDriver) {
        final id = driverSnap.docs.first.id;
        await _db.collection('drivers').doc(id).set({
          'authUid': cred.user!.uid,
        }, SetOptions(merge: true));
      }

      if (isMarketing) {
        final id = marketingSnap.docs.first.id;
        await _db.collection('marketing').doc(id).set({
          'authUid': cred.user!.uid,
        }, SetOptions(merge: true));
      }

      if (isStaff) {
        final id = staffSnap.docs.first.id;
        await _db.collection('staff').doc(id).set({
          'authUid': cred.user!.uid,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Please log in.'),
          ),
        );
      }

    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff3B82F6),
              Color(0xff60A5FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(24),

            child: Container(

              padding: const EdgeInsets.all(26),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 20,
                    offset: const Offset(0,10),
                  )
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  const Text(
                    "Create Account",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _name,
                    decoration: _inputStyle("Name", Icons.person),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: _email,
                    decoration: _inputStyle("Email", Icons.email),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: _inputStyle("Password", Icons.lock),
                  ),

                  const SizedBox(height: 14),

                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(height: 18),

                  SizedBox(
                    height: 48,

                    child: ElevatedButton(

                      onPressed: _submitting ? null : _onSubmit,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff3B82F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      child: _submitting
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Already have an account? Login"),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}