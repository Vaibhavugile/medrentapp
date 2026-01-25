import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // <-- secure storage

import '../marketing/marketing_home.dart';
import 'home_shell.dart';
import 'signup_screen.dart';
import '../nurse/nurse_home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  bool _loading = false;
  bool _obscure = true;
  bool _remember = true; // default checked

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // load saved email/password if "remember me"
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('rememberMe') ?? true;
      setState(() => _remember = remember);

      if (_remember) {
        final savedEmail = prefs.getString('savedEmail') ?? '';
        final savedPass = await _secureStorage.read(key: 'savedPassword') ?? '';
        if (savedEmail.isNotEmpty) _email.text = savedEmail;
        if (savedPass.isNotEmpty) _pass.text = savedPass;
      }
    } catch (e) {
      // ignore load errors; don't block UI
    }
  }

  // === NEW: save this device's FCM token to drivers/{uid} ===
  Future<void> _syncDriverDeviceToken(String driverId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS permission prompt (safe on Android too)
      await messaging.requestPermission();

      // current token
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
        'lastFcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // keep updated on token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (newToken.isEmpty) return;
        FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
          'lastFcmToken': newToken,
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // non-fatal; don't block login flow
    }
  }

Future<void> _routeAfterLogin(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final db = FirebaseFirestore.instance;

  // ================= MARKETING =================

  // 1️⃣ Marketing by docId == uid
  final marketingById = await db.collection('marketing').doc(uid).get();
  if (marketingById.exists && marketingById.data()?['active'] == true) {
    final name = (marketingById.data()?['name'] ?? 'Marketing').toString();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingHome(
          userId: marketingById.id, // ✅ DOC ID
          userName: name,
        ),
      ),
    );
    return;
  }

  // 2️⃣ Marketing by authUid
  final marketingByAuth = await db
      .collection('marketing')
      .where('authUid', isEqualTo: uid)
      .where('active', isEqualTo: true)
      .limit(1)
      .get();

  if (marketingByAuth.docs.isNotEmpty) {
    final doc = marketingByAuth.docs.first;
    final name = (doc.data()['name'] ?? 'Marketing').toString();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingHome(
          userId: doc.id, // ✅ DOC ID
          userName: name,
        ),
      ),
    );
    return;
  }

  // ================= STAFF / NURSE =================

  // 3️⃣ Staff by authUid (CORRECT PATTERN)
  final staffByAuth = await db
      .collection('staff')
      .where('authUid', isEqualTo: uid)
      .where('active', isEqualTo: true)
      .limit(1)
      .get();

  if (staffByAuth.docs.isNotEmpty) {
    final doc = staffByAuth.docs.first;
    final name = (doc.data()['name'] ?? 'Nurse').toString();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NurseHomeShell(
          staffId: doc.id,     // ✅ STAFF DOC ID
          staffName: name,
        ),
      ),
    );
    return;
  }

  // ================= DRIVER (UNCHANGED) =================

  await _syncDriverDeviceToken(uid);

  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const HomeShell()),
  );
}



  Future<void> _saveCredentials(bool remember, String email, String pass) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', remember);
      if (remember) {
        await prefs.setString('savedEmail', email);
        await _secureStorage.write(key: 'savedPassword', value: pass);
      } else {
        await prefs.remove('savedEmail');
        await _secureStorage.delete(key: 'savedPassword');
      }
    } catch (e) {
      // ignore persistence errors
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    final email = _email.text.trim();
    final pass = _pass.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);

      // save or clear credentials based on remember flag
      await _saveCredentials(_remember, email, pass);

      await _routeAfterLogin(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // app mark
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Icon(Icons.health_and_safety, size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome back',
                        style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),

                      // card surface
                      Card(
                        elevation: 10,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // email
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'you@example.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // password
                              TextField(
                                controller: _pass,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure ? 'Show password' : 'Hide password',
                                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              // forgot password placeholder (UI only)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Forgot password flow not implemented'),
                                      ),
                                    );
                                  },
                                  child: const Text('Forgot password?'),
                                ),
                              ),

                              // REMEMBER ME checkbox
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _remember,
                                onChanged: (v) async {
                                  final newVal = v ?? false;
                                  setState(() => _remember = newVal);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('rememberMe', newVal);
                                  if (!newVal) {
                                    await prefs.remove('savedEmail');
                                    await _secureStorage.delete(key: 'savedPassword');
                                  } else {
                                    // if enabling remember and fields filled, save them
                                    final email = _email.text.trim();
                                    final pass = _pass.text.trim();
                                    if (email.isNotEmpty && pass.isNotEmpty) {
                                      await prefs.setString('savedEmail', email);
                                      await _secureStorage.write(key: 'savedPassword', value: pass);
                                    }
                                  }
                                },
                                title: const Text('Remember me'),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),

                              const SizedBox(height: 6),

                              // sign in
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: _loading ? null : _login,
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        )
                                      : const Text('Sign in'),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: theme.colorScheme.outlineVariant),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      'or',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: theme.colorScheme.outlineVariant),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // create account (keeps your existing navigation)
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Create account'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // tiny footer
                      Text(
                        'By continuing, you agree to our Terms & Privacy Policy.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
