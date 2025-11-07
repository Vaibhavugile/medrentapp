import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  String mode = 'phone'; // or 'email'
  String phone = '';
  String email = '';
  String pass = '';
  String smsCode = '';
  String? verificationId;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _auth.authChanges.listen((u) {
      if (u != null) Navigator.pushReplacementNamed(context, '/home');
    });
  }

  Future<void> sendOtp() async {
    if (!phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use +countrycode...')));
      return;
    }
    setState(() => loading = true);
    await _auth.verifyPhone(
      phone: phone,
      onVerified: (cred) async => FirebaseAuth.instance.signInWithCredential(cred),
      onCodeSent: (id, _) { setState(() { verificationId = id; loading = false; }); },
      onFailed: (e) { setState(() => loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'OTP failed'))); },
    );
  }

  Future<void> verifyOtp() async {
    if (verificationId == null) return;
    setState(() => loading = true);
    try {
      await _auth.signInWithSmsCode(verificationId!, smsCode);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code')));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> emailLogin() async {
    setState(() => loading = true);
    try { await _auth.signInWithEmail(email, pass); }
    catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed'))); }
    finally { setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                Text('Driver Login', style: TextStyle(fontWeight: FontWeight.w800, color: c.primary, fontSize: 22)),
                const SizedBox(height: 12),
                ToggleButtons(
                  isSelected: [mode == 'phone', mode == 'email'],
                  onPressed: (i) => setState(() => mode = i == 0 ? 'phone' : 'email'),
                  children: const [Padding(padding: EdgeInsets.all(8), child: Text('Phone')), Padding(padding: EdgeInsets.all(8), child: Text('Email'))],
                ),
                const SizedBox(height: 12),
                if (mode == 'phone') ...[
                  TextField(decoration: const InputDecoration(labelText: 'Phone (+91...)'), onChanged: (v) => phone = v),
                  const SizedBox(height: 8),
                  if (verificationId == null)
                    FilledButton(onPressed: loading ? null : sendOtp, child: Text(loading ? 'Sending…' : 'Send OTP'))
                  else ...[
                    TextField(decoration: const InputDecoration(labelText: 'OTP'), onChanged: (v) => smsCode = v),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: loading ? null : verifyOtp, child: Text(loading ? 'Verifying…' : 'Verify & Sign in')),
                  ],
                ] else ...[
                  TextField(decoration: const InputDecoration(labelText: 'Email'), onChanged: (v) => email = v),
                  const SizedBox(height: 8),
                  TextField(obscureText: true, decoration: const InputDecoration(labelText: 'Password'), onChanged: (v) => pass = v),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: loading ? null : emailLogin, child: Text(loading ? 'Signing in…' : 'Sign in')),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
