import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../marketing/marketing_home.dart'; // <- path from /screens
import 'home_shell.dart';                  // driver shell
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _routeAfterLogin(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    // 1) Try marketing/{uid}
    final docById = await db.collection('marketing').doc(uid).get();
    if (docById.exists && (docById.data()?['active'] == true)) {
      final name = (docById.data()?['name'] ?? 'Marketing').toString();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MarketingHome(userId: uid, userName: name)),
      );
      return;
    }

    // 2) Try marketing where authUid == uid
    final q = await db
        .collection('marketing')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty && (q.docs.first.data()['active'] == true)) {
      final d = q.docs.first.data();
      final name = (d['name'] ?? 'Marketing').toString();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MarketingHome(userId: uid, userName: name)),
      );
      return;
    }

    // 3) Optional: users/{uid}.role == 'marketing'
    final userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists && (userDoc.data()?['role'] == 'marketing')) {
      final name = (userDoc.data()?['name'] ?? 'Marketing').toString();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MarketingHome(userId: uid, userName: name)),
      );
      return;
    }

    // 4) Fallback to driver shell
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
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
    // nice gradient backdrop
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
                      child: Icon(Icons.local_shipping_outlined,
                          size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome back',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to continue',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
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
                                prefixIcon:
                                    const Icon(Icons.email_outlined),
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
                                prefixIcon:
                                    const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(_obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
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
                                      content: Text(
                                          'Forgot password flow not implemented'),
                                    ),
                                  );
                                },
                                child: const Text('Forgot password?'),
                              ),
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
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'or',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                            color: theme
                                                .colorScheme.outline),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
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
                                    MaterialPageRoute(
                                      builder: (_) => SignupScreen(),
                                    ),
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
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
