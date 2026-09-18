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

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  static const Color _navy = Color(0xFF101828);
  static const Color _primary = Color(0xFF3157D5);
  static const Color _indigo = Color(0xFF4F46E5);
  static const Color _background = Color(0xFFF7F9FC);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE4E7EC);
  static const Color _success = Color(0xFF12B76A);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();

    setState(() => _error = null);

    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text;

    if (name.isEmpty) {
      _setError('Please enter your full name.');
      _nameFocus.requestFocus();
      return;
    }

    if (name.length < 2) {
      _setError('Please enter a valid name.');
      _nameFocus.requestFocus();
      return;
    }

    if (email.isEmpty) {
      _setError('Please enter your email address.');
      _emailFocus.requestFocus();
      return;
    }

    if (!_isValidEmail(email)) {
      _setError('Please enter a valid email address.');
      _emailFocus.requestFocus();
      return;
    }

    if (pass.length < 6) {
      _setError('Password must be at least 6 characters.');
      _passwordFocus.requestFocus();
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

      // The newly-created Firebase user is signed in automatically.
      // Sign out before returning to Login so the existing login flow remains
      // the single entry point after registration.
      await _auth.signOut();

      if (!mounted) return;

      Navigator.pop(context);

      _showMessage(
        'Account created successfully. You can now sign in.',
        success: true,
        icon: Icons.check_circle_outline_rounded,
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Please choose a stronger password.';
          break;
        case 'network-request-failed':
          message = 'Network unavailable. Check your connection.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password sign-up is currently unavailable.';
          break;
        default:
          message = e.message ?? 'Unable to create the account.';
      }

      _setError(message);
    } catch (e) {
      final raw = e.toString().replaceFirst('Exception: ', '').trim();
      _setError(
        raw.isEmpty ? 'Unable to create the account. Please try again.' : raw,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);

    _showMessage(
      message,
      icon: Icons.info_outline_rounded,
    );
  }

  void _showMessage(
    String message, {
    bool success = false,
    IconData? icon,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (success ? _success : _primary).withOpacity(.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon ??
                        (success
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded),
                    color: success
                        ? const Color(0xFF6CE9A6)
                        : const Color(0xFFA4BCFD),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  InputDecoration _inputStyle({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      labelStyle: const TextStyle(
        color: _muted,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontWeight: FontWeight.w400,
      ),
      prefixIconColor: _primary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFF04438),
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFF04438),
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -110,
            child: _decorativeCircle(
              310,
              const Color(0xFF4F46E5).withOpacity(.12),
            ),
          ),
          Positioned(
            top: 180,
            left: -165,
            child: _decorativeCircle(
              285,
              const Color(0xFF3157D5).withOpacity(.075),
            ),
          ),
          Positioned(
            bottom: -190,
            right: -120,
            child: _decorativeCircle(
              350,
              const Color(0xFF0EA5E9).withOpacity(.07),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    28,
                    22,
                    28 + bottom,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 27),
                      _buildSignupCard(context),
                      const SizedBox(height: 22),
                      const Text(
                        'Secure registration • Healthcare management platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: .12,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'By continuing, you agree to our Terms & Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF98A2B3),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary, _indigo],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x263157D5),
                blurRadius: 30,
                offset: Offset(0, 13),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: Colors.white.withOpacity(.85),
                width: 4,
              ),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: _primary,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 17),
        const Text(
          'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy,
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Set up your secure workspace access',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSignupCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 42,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registration',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Use your admin-provided email',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            TextField(
              controller: _name,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _inputStyle(
                label: 'Full name',
                hint: 'Enter your full name',
                icon: Icons.person_outline_rounded,
              ),
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _email,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _inputStyle(
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _pass,
              focusNode: _passwordFocus,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              decoration: _inputStyle(
                label: 'Password',
                hint: 'Minimum 6 characters',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscurePassword
                      ? 'Show password'
                      : 'Hide password',
                  color: _muted,
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 21,
                  ),
                  onPressed: () {
                    setState(
                      () => _obscurePassword = !_obscurePassword,
                    );
                  },
                ),
              ),
              onSubmitted: (_) => _onSubmit(),
            ),

            const SizedBox(height: 14),

            if (_error != null) ...[
              _buildErrorCard(),
              const SizedBox(height: 5),
            ],

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [_primary, _indigo],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x263157D5),
                      blurRadius: 20,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _submitting ? null : _onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _submitting
                        ? const SizedBox(
                            key: ValueKey('signup_loading'),
                            height: 21,
                            width: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Row(
                            key: ValueKey('signup_button'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Create account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 9),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 19),

            Row(
              children: [
                const Expanded(
                  child: Divider(
                    height: 1,
                    color: _border,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: const Text(
                      'OR',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(
                    height: 1,
                    color: _border,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                    color: _border,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login_rounded,
                      size: 19,
                    ),
                    SizedBox(width: 9),
                    Text(
                      'Already have an account? Sign in',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFF0F2F5),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: _success,
                    size: 18,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Registration is restricted to accounts already assigned by your administrator.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD92D20),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
