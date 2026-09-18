import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'nurse_home_screen.dart';
import 'nurse_orders_screen.dart';
import '../screens/attendance_screen.dart';
import 'nurse_profile_screen.dart';

class NurseHomeShell extends StatefulWidget {
  final String staffId; // STAFF DOC ID
  final String staffName; // STAFF NAME

  const NurseHomeShell({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<NurseHomeShell> createState() => _NurseHomeShellState();
}

class _NurseHomeShellState extends State<NurseHomeShell> {
  int _index = 0;

  late final List<Widget> _pages;

  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  void initState() {
    super.initState();

    _pages = [
      // ============================================================
      // HOME
      // ============================================================

      NurseOrdersScreen(
        staffId: widget.staffId,
      ),

      // ============================================================
      // ATTENDANCE
      // ============================================================

      AttendanceScreen(
        userId: widget.staffId,
        userName: widget.staffName,
        collectionRoot: 'staff',
      ),

      // ============================================================
      // SALARY
      // ============================================================

      const _Placeholder(
        title: 'Salary',
        icon: Icons.payments_outlined,
      ),

      // ============================================================
      // PROFILE
      // ============================================================

      NurseProfileScreen(
        staffId: widget.staffId,
      ),
    ];

    // FCM token sync should never block the UI.
    _syncNurseDeviceToken(widget.staffId);
  }

  // ================================================================
  // FCM TOKEN SYNC
  // ================================================================

  Future<void> _syncNurseDeviceToken(String staffId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permission.
      // Safe to call on Android as well.
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await messaging.getToken();

      if (token != null && token.isNotEmpty) {
        await _saveFcmToken(
          staffId: staffId,
          token: token,
        );
      }

      // Avoid creating duplicate listeners if this method is called again.
      await _tokenRefreshSubscription?.cancel();

      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          if (newToken.isEmpty) return;

          await _saveFcmToken(
            staffId: staffId,
            token: newToken,
          );
        },
        onError: (error) {
          debugPrint(
            'Nurse FCM token refresh error: $error',
          );
        },
      );
    } catch (e) {
      // FCM must NEVER block the nurse UI.
      debugPrint(
        'Nurse FCM sync skipped: $e',
      );
    }
  }

  Future<void> _saveFcmToken({
    required String staffId,
    required String token,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .set(
        {
          // Latest logged-in device.
          'lastFcmToken': token,

          // Keep all known tokens.
          'fcmTokens': FieldValue.arrayUnion([token]),

          // Useful for online/device activity tracking.
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint(
        'Save nurse FCM token error: $e',
      );
    }
  }

  // ================================================================
  // PROFILE
  // ================================================================

  void _openProfile() {
    if (!mounted) return;

    setState(() {
      _index = 3;
    });
  }

  // ================================================================
  // PROFILE AVATAR
  // ================================================================

  Widget _profileAvatar() {
    final initial = widget.staffName.trim().isNotEmpty
        ? widget.staffName.trim()[0].toUpperCase()
        : 'N';

    return GestureDetector(
      onTap: _openProfile,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.white.withOpacity(.90),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 4),
              color: Colors.black.withOpacity(.16),
            ),
          ],
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // APPBAR USER INFO
  // ================================================================

  Widget _appBarUserInfo() {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.staffName.trim().isEmpty
                    ? 'Nurse'
                    : widget.staffName.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'Nurse',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // PROFILE ARROW
  // ================================================================

  Widget _profileArrow() {
    return GestureDetector(
      onTap: _openProfile,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(.10),
          ),
        ),
        child: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white,
          size: 21,
        ),
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      // ============================================================
      // BODY
      // ============================================================

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _pages[_index],
        ),
      ),

      // ============================================================
      // PREMIUM APPBAR
      // ============================================================

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF172A3A),
                Color(0xFF2C3E50),
                Color(0xFF4CA1AF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        titleSpacing: 16,

        title: Row(
          children: [
            // --------------------------------------------------------
            // PROFILE AVATAR
            // --------------------------------------------------------

            _profileAvatar(),

            const SizedBox(width: 10),

            // --------------------------------------------------------
            // NAME + ROLE
            // --------------------------------------------------------

            _appBarUserInfo(),

            const SizedBox(width: 6),

            // --------------------------------------------------------
            // OPEN PROFILE
            // --------------------------------------------------------

            _profileArrow(),
          ],
        ),
      ),

      // ============================================================
      // BOTTOM NAVIGATION
      // ============================================================

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withOpacity(.08),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BottomNavigationBar(
              currentIndex: _index,

              onTap: (i) {
                if (_index == i) return;

                setState(() {
                  _index = i;
                });
              },

              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,

              selectedItemColor: const Color(0xFF4CA1AF),
              unselectedItemColor: const Color(0xFF8A94A6),

              selectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),

              unselectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),

              items: const [
                // ----------------------------------------------------
                // HOME
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.home_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.home_rounded,
                  ),
                  label: 'Home',
                ),

                // ----------------------------------------------------
                // ATTENDANCE
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.fingerprint,
                  ),
                  activeIcon: Icon(
                    Icons.fingerprint_rounded,
                  ),
                  label: 'Attendance',
                ),

                // ----------------------------------------------------
                // SALARY
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.payments_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.payments_rounded,
                  ),
                  label: 'Salary',
                ),

                // ----------------------------------------------------
                // PROFILE
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.person_outline_rounded,
                  ),
                  activeIcon: Icon(
                    Icons.person_rounded,
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}

// ==================================================================
// PLACEHOLDER
// ==================================================================

class _Placeholder extends StatelessWidget {
  final String title;
  final IconData icon;

  const _Placeholder({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE9EEF5),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(.06),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F8),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF4CA1AF),
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'This section will be available here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8A94A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
