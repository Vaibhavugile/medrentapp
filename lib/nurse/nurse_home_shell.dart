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

  @override
  void initState() {
    super.initState();

    // 🔔 Sync FCM token for LAST LOGGED-IN DEVICE
    _syncNurseDeviceToken(widget.staffId);

    _pages = [
      // =====================================================
      // HOME
      // =====================================================
      NurseOrdersScreen(
        staffId: widget.staffId,
      ),

      // =====================================================
      // ATTENDANCE
      // =====================================================
      AttendanceScreen(
        userId: widget.staffId,
        userName: widget.staffName,
        collectionRoot: 'staff',
      ),

      // =====================================================
      // SALARY
      // =====================================================
      const _Placeholder(title: 'Salary'),

      // =====================================================
      // PROFILE
      // =====================================================
      NurseProfileScreen(
        staffId: widget.staffId,
      ),
    ];
  }

  /// =======================================================
  /// 🔔 FCM TOKEN SYNC
  /// =======================================================
  Future<void> _syncNurseDeviceToken(String staffId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS permission (safe on Android too)
      await messaging.requestPermission();

      final token = await messaging.getToken();

      if (token == null || token.isEmpty) return;

      // Save LAST LOGGED-IN DEVICE
      await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .set({
            'lastFcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastActiveAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Handle token refresh automatically
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          if (newToken.isEmpty) return;

          await FirebaseFirestore.instance
              .collection('staff')
              .doc(staffId)
              .set({
            'lastFcmToken': newToken,
            'fcmTokens': FieldValue.arrayUnion([newToken]),
            'lastActiveAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        },
      );
    } catch (_) {
      // Silent fail – NEVER block UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,

        onTap: (i) {
          setState(() {
            _index = i;
          });
        },

        type: BottomNavigationBarType.fixed,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint),
            label: 'Attendance',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.payments),
            label: 'Salary',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// PLACEHOLDER PAGES
/// =======================================================

class _Placeholder extends StatelessWidget {
  final String title;

  const _Placeholder({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),

      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}