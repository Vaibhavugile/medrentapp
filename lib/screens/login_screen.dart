import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // <-- secure storage
import 'inactive_account_screen.dart';
import '../marketing/marketing_home.dart';
import 'home_shell.dart';
import 'signup_screen.dart';
import '../nurse/nurse_home_shell.dart';
import 'user_home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final _secureStorage = const FlutterSecureStorage();

  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;

  static const Color _navy = Color(0xFF101828);
  static const Color _primary = Color(0xFF3157D5);
  static const Color _indigo = Color(0xFF4F46E5);
  static const Color _background = Color(0xFFF7F9FC);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE4E7EC);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('rememberMe') ?? true;

      if (!mounted) return;
      setState(() => _remember = remember);

      if (remember) {
        final savedEmail = prefs.getString('savedEmail') ?? '';
        final savedPass =
            await _secureStorage.read(key: 'savedPassword') ?? '';

        if (!mounted) return;
        if (savedEmail.isNotEmpty) _email.text = savedEmail;
        if (savedPass.isNotEmpty) _pass.text = savedPass;
      }
    } catch (_) {
      // Persistence errors should never block login.
    }
  }

  Future<void> _syncDriverDeviceToken(String driverId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
        'lastFcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (newToken.isEmpty) return;
        FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
          'lastFcmToken': newToken,
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();

    final email = _email.text.trim();
    if (email.isEmpty) {
      _showMessage(
        'Enter your email address first.',
        success: false,
        icon: Icons.mail_outline_rounded,
      );
      _emailFocus.requestFocus();
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {
      // Keep the response generic for account privacy/security.
    }

    if (!mounted) return;

    _showMessage(
      'If an account exists for this email, a reset link has been sent.',
      success: true,
      icon: Icons.mark_email_read_outlined,
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
                    color: (success ? const Color(0xFF12B76A) : _primary)
                        .withOpacity(.18),
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

  Future<void> _routeAfterLogin(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    try {
      final userDoc = await db.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception("User profile not found.");
      }

      final userData = userDoc.data() ?? {};
      final role = (userData['role'] ?? '').toString().toLowerCase().trim();

      String? collectionName;
      String? profileId;
      Map<String, dynamic>? profileData;

      if (role == 'driver') {
        collectionName = 'drivers';
      } else if (role == 'marketing') {
        collectionName = 'marketing';
      } else if (role == 'staff') {
        collectionName = 'staff';
      } else {
        collectionName = 'users';
      }

      if (role == 'driver') {
        final driverDoc = await db
            .collection(collectionName!)
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (driverDoc.docs.isNotEmpty) {
          final doc = driverDoc.docs.first;
          profileId = doc.id;
          profileData = doc.data();
        }
      } else if (role == 'marketing') {
        final marketingDoc = await db
            .collection(collectionName!)
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (marketingDoc.docs.isNotEmpty) {
          final doc = marketingDoc.docs.first;
          profileId = doc.id;
          profileData = doc.data();
        }
      } else if (role == 'staff') {
        final staffDoc = await db
            .collection(collectionName!)
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (staffDoc.docs.isNotEmpty) {
          final doc = staffDoc.docs.first;
          profileId = doc.id;
          profileData = doc.data();
        }
      } else {
        profileId = uid;
        profileData = userData;
      }

      final isActive = profileData?['active'] == true;

      if (!isActive) {
        if (!mounted) return;
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const InactiveAccountScreen(),
          ),
        );
        return;
      }

      if (!mounted) return;

      if (role == 'driver') {
        if (profileId != null) {
          // Kept available without changing the existing routing contract.
          await _syncDriverDeviceToken(profileId);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
        return;
      }

      if (role == 'marketing') {
        final name = (profileData?['name'] ?? 'Marketing').toString();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MarketingHome(
              userId: profileId!,
              userName: name,
            ),
          ),
        );
        return;
      }

      if (role == 'staff') {
        final name = (profileData?['name'] ?? 'Nurse').toString();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NurseHomeShell(
              staffId: profileId!,
              staffName: name,
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserHomeShell()),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to verify your account. Please try again.',
        success: false,
        icon: Icons.cloud_off_rounded,
      );
    }
  }

  Future<void> _saveCredentials(
    bool remember,
    String email,
    String pass,
  ) async {
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
    } catch (_) {
      // Persistence errors should not block authentication.
    }
  }

  Future<void> _login() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    final email = _email.text.trim();
    final pass = _pass.text;

    if (email.isEmpty) {
      _showMessage(
        'Please enter your email address.',
        icon: Icons.mail_outline_rounded,
      );
      _emailFocus.requestFocus();
      return;
    }

    if (pass.isEmpty) {
      _showMessage(
        'Please enter your password.',
        icon: Icons.lock_outline_rounded,
      );
      _passwordFocus.requestFocus();
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      await _saveCredentials(_remember, email, pass);
      await _routeAfterLogin(context);
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'Incorrect email or password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please wait and try again.';
          break;
        case 'network-request-failed':
          message = 'Network unavailable. Check your connection.';
          break;
        default:
          message = e.message ?? 'Login failed. Please try again.';
      }

      _showMessage(
        message,
        icon: Icons.lock_person_outlined,
      );
    } catch (_) {
      _showMessage(
        'Login failed. Please try again.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration({
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
        borderSide: const BorderSide(color: _primary, width: 1.6),
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
            child: _blurCircle(310, const Color(0xFF4F46E5).withOpacity(.13)),
          ),
          Positioned(
            top: 170,
            left: -160,
            child: _blurCircle(280, const Color(0xFF3157D5).withOpacity(.08)),
          ),
          Positioned(
            bottom: -180,
            right: -120,
            child: _blurCircle(340, const Color(0xFF0EA5E9).withOpacity(.07)),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(22, 28, 22, 28 + bottom),
                  child: Column(
                    children: [
                      _buildBrand(),
                      const SizedBox(height: 28),
                      _buildLoginCard(context),
                      const SizedBox(height: 22),
                      const Text(
                        'Secure access • Healthcare management platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: .15,
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

  Widget _blurCircle(double size, Color color) {
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

  Widget _buildBrand() {
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
          'Welcome back',
          style: TextStyle(
            color: _navy,
            fontSize: 29,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Sign in to continue to your workspace',
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

  Widget _buildLoginCard(BuildContext context) {
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
                    Icons.lock_open_rounded,
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
                        'Sign in',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Use your registered account',
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
              controller: _email,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: _inputDecoration(
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _pass,
              focusNode: _passwordFocus,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: _inputDecoration(
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 21,
                  ),
                  color: _muted,
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),

            const SizedBox(height: 5),

            Row(
              children: [
                Transform.translate(
                  offset: const Offset(-9, 0),
                  child: Checkbox(
                    value: _remember,
                    activeColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (value) async {
                      final newValue = value ?? false;
                      setState(() => _remember = newValue);

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('rememberMe', newValue);

                      if (!newValue) {
                        await prefs.remove('savedEmail');
                        await _secureStorage.delete(key: 'savedPassword');
                      } else {
                        final email = _email.text.trim();
                        final pass = _pass.text;
                        if (email.isNotEmpty && pass.isNotEmpty) {
                          await prefs.setString('savedEmail', email);
                          await _secureStorage.write(
                            key: 'savedPassword',
                            value: pass,
                          );
                        }
                      }
                    },
                  ),
                ),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

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
                  onPressed: _loading ? null : _login,
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
                    child: _loading
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            height: 21,
                            width: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            key: ValueKey('login'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sign in securely',
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
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _border, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, size: 19),
                    SizedBox(width: 9),
                    Text(
                      'Create a new account',
                      style: TextStyle(
                        fontSize: 14,
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
                border: Border.all(color: const Color(0xFFF0F2F5)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF12B76A),
                    size: 18,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Your login is protected with Firebase authentication.',
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
}
