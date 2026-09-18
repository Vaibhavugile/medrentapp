import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../marketing/marketing_home.dart';
import 'driver_profile_screen.dart';
import '../services/driver_service.dart';
import 'attendance_screen.dart';
import 'link_profile_screen.dart';
import 'tasks_screen.dart';
import 'attendance_history_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final DriverService _drvSvc = DriverService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _index = 0;

  late List<Widget> _pages;

  DriverDoc? driver;
  bool loading = true;

  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  void initState() {
    super.initState();
    resolve();
  }

  // ============================================================
  // FCM TOKEN SYNC
  // ============================================================

  Future<void> _syncDriverDeviceToken(String driverId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .set(
        {
          'lastFcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _tokenRefreshSubscription?.cancel();

      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          try {
            if (newToken.isEmpty) return;

            await FirebaseFirestore.instance
                .collection('drivers')
                .doc(driverId)
                .set(
              {
                'lastFcmToken': newToken,
                'fcmTokens': FieldValue.arrayUnion([newToken]),
                'lastActiveAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          } catch (_) {
            // Do not block the application if token sync fails.
          }
        },
      );
    } catch (_) {
      // FCM failure must never block the Driver UI.
    }
  }

  // ============================================================
  // RESOLVE LOGGED-IN USER
  // ============================================================

  Future<void> resolve() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          loading = false;
        });

        return;
      }

      final db = FirebaseFirestore.instance;

      // ========================================================
      // 1) MARKETING/{UID}
      // ========================================================

      final byId = await db.collection('marketing').doc(user.uid).get();

      if (byId.exists && (byId.data()?['active'] == true)) {
        final marketingDocId = byId.id;

        final name =
            (byId.data()?['name'] ?? 'Marketing').toString();

        try {
          await FlutterForegroundTask.stopService();
        } catch (_) {}

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MarketingHome(
              userId: marketingDocId,
              userName: name,
            ),
          ),
        );

        return;
      }

      // ========================================================
      // 2) MARKETING WHERE authUid == UID
      // ========================================================

      final q = await db
          .collection('marketing')
          .where(
            'authUid',
            isEqualTo: user.uid,
          )
          .limit(1)
          .get();

      if (q.docs.isNotEmpty &&
          (q.docs.first.data()['active'] == true)) {
        final doc = q.docs.first;

        final marketingDocId = doc.id;

        final name =
            (doc.data()['name'] ?? 'Marketing').toString();

        try {
          await FlutterForegroundTask.stopService();
        } catch (_) {}

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MarketingHome(
              userId: marketingDocId,
              userName: name,
            ),
          ),
        );

        return;
      }

      // ========================================================
      // 3) USERS/{UID}.ROLE == MARKETING
      // ========================================================

      final userDoc =
          await db.collection('users').doc(user.uid).get();

      if (userDoc.exists &&
          userDoc.data()?['role'] == 'marketing') {
        final q2 = await db
            .collection('marketing')
            .where(
              'authUid',
              isEqualTo: user.uid,
            )
            .limit(1)
            .get();

        final marketingDocId =
            q2.docs.isNotEmpty ? q2.docs.first.id : user.uid;

        final name = q2.docs.isNotEmpty
            ? (q2.docs.first.data()['name'] ?? 'Marketing')
                .toString()
            : (userDoc.data()?['name'] ?? 'Marketing')
                .toString();

        try {
          await FlutterForegroundTask.stopService();
        } catch (_) {}

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MarketingHome(
              userId: marketingDocId,
              userName: name,
            ),
          ),
        );

        return;
      }

      // ========================================================
      // 4) DRIVER FLOW
      // ========================================================

      final d = await _drvSvc.findDriverForUser(user);

      if (!mounted) return;

      if (d != null) {
        // Do not block UI while syncing FCM.
        unawaited(_syncDriverDeviceToken(d.id));
      }

      if (d == null) {
        setState(() {
          driver = null;
          loading = false;
        });

        return;
      }

      final driverName =
          (d.data['name'] ?? 'Driver').toString();

      final driverData =
          Map<String, dynamic>.from(d.data);

      setState(() {
        driver = d;
        loading = false;

        _pages = [
          // ====================================================
          // TASKS
          // ====================================================

          TasksScreen(
            driverId: d.id,
            driverName: driverName,
          ),

          // ====================================================
          // ATTENDANCE
          // ====================================================

          AttendanceScreen(
            userId: d.id,
            userName: driverName,
            collectionRoot: 'drivers',
          ),

          // ====================================================
          // ATTENDANCE HISTORY
          // ====================================================

          AttendanceHistoryScreen(
            userId: d.id,
            collectionRoot: 'drivers',
          ),

          // ====================================================
          // DRIVER PROFILE
          // ====================================================

          DriverProfileScreen(
            driverId: d.id,
            driverData: driverData,
          ),
        ];
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        driver = null;
        loading = false;
      });
    }
  }

  // ============================================================
  // PROFILE AVATAR
  // ============================================================

  Widget _buildProfileAvatar(
    Map<String, dynamic> data, {
    required double radius,
    required String fallbackLetter,
  }) {
    final possiblePhotoValues = [
      data['profilePhotoUrl'],
      data['photoUrl'],
      data['profilePhoto'],
      data['photo'],
      data['avatarUrl'],
      data['imageUrl'],
    ];

    String photoUrl = '';

    for (final value in possiblePhotoValues) {
      final valueString = value?.toString().trim() ?? '';

      if (valueString.isNotEmpty) {
        photoUrl = valueString;
        break;
      }
    }

    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Text(
        fallbackLetter,
        style: TextStyle(
          color: const Color(0xFF0F4C75),
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (_) => false,
    );
  }

  // ============================================================
  // DISPOSE
  //
  // IMPORTANT:
  // This MUST be inside _HomeShellState.
  // ============================================================

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final premiumTheme = Theme.of(context).copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),

      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F4C75),
        brightness: Brightness.light,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF3282B8),
            width: 1.2,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );

    return Theme(
      data: premiumTheme,
      child: _buildContent(context),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildContent(BuildContext context) {
    // ============================================================
    // LOADING
    // ============================================================

    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0F4C75),
          ),
        ),
      );
    }

    // ============================================================
    // DRIVER NOT LINKED
    // ============================================================

    if (driver == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0F4C75),
          foregroundColor: Colors.white,
          title: const Text(
            'Driver',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: LinkProfileScreen(
          onLinked: resolve,
        ),
      );
    }

    // ============================================================
    // DRIVER DATA
    // ============================================================

    final driverName =
        (driver!.data['name'] ?? 'Driver').toString().trim();

    final safeDriverName =
        driverName.isEmpty ? 'Driver' : driverName;

    final firstLetter = safeDriverName.isNotEmpty
        ? safeDriverName[0].toUpperCase()
        : 'D';

    // ============================================================
    // MAIN SCAFFOLD
    // ============================================================

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      // ========================================================
      // PREMIUM APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F4C75),
                Color(0xFF3282B8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        titleSpacing: 12,

        title: InkWell(
          borderRadius: BorderRadius.circular(30),

          onTap: () {
            if (!mounted) return;

            setState(() {
              _index = 3;
            });
          },

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==================================================
              // PROFILE PHOTO
              // ==================================================

              _buildProfileAvatar(
                driver!.data,
                radius: 19,
                fallbackLetter: firstLetter,
              ),

              const SizedBox(width: 10),

              // ==================================================
              // NAME + ROLE
              // ==================================================

              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeDriverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 1),

                    const Text(
                      'Driver',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
        ),

        // ========================================================
        // LOGOUT
        // ========================================================

        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
            ),
            onPressed: _logout,
          ),

          const SizedBox(width: 4),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,

        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _pages[_index],
        ),
      ),

      // ========================================================
      // PREMIUM BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            12,
            6,
            12,
            12,
          ),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),

            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                spreadRadius: 0,
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),

            child: BottomNavigationBar(
              currentIndex: _index,

              onTap: (index) {
                if (!mounted) return;

                setState(() {
                  _index = index;
                });
              },

              backgroundColor: Colors.transparent,
              elevation: 0,

              type: BottomNavigationBarType.fixed,

              selectedItemColor:
                  const Color(0xFF0F4C75),

              unselectedItemColor:
                  const Color(0xFF94A3B8),

              selectedFontSize: 12,
              unselectedFontSize: 11,

              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
              ),

              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
              ),

              showUnselectedLabels: true,

              items: const [
                // ==================================================
                // TASKS
                // ==================================================

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.local_shipping_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.local_shipping_rounded,
                  ),
                  label: 'Tasks',
                ),

                // ==================================================
                // ATTENDANCE
                // ==================================================

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.fingerprint_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.fingerprint_rounded,
                  ),
                  label: 'Attendance',
                ),

                // ==================================================
                // HISTORY
                // ==================================================

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.history_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.history_rounded,
                  ),
                  label: 'History',
                ),

                // ==================================================
                // PROFILE
                // ==================================================

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
}

// ================================================================
// PLACEHOLDER
// ================================================================
//
// IMPORTANT:
// There is NO dispose() here.
// _tokenRefreshSubscription belongs to _HomeShellState.
// ================================================================

class _Placeholder extends StatelessWidget {
  final String title;

  const _Placeholder({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}