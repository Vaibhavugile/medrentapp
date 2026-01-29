import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../marketing/marketing_home.dart';

import '../services/driver_service.dart';
import 'attendance_screen.dart';
import 'link_profile_screen.dart';
import 'tasks_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _drvSvc = DriverService();
  final _auth = FirebaseAuth.instance;
int _index = 0;
late List<Widget> _pages;

  DriverDoc? driver;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    resolve();
  }

  Future<void> resolve() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    final db = FirebaseFirestore.instance;

    // 1) marketing/{uid}
    final byId = await db.collection('marketing').doc(user.uid).get();
    if (byId.exists && (byId.data()?['active'] == true)) {
      final marketingDocId = byId.id; // <-- USE DOC ID
      final name = (byId.data()?['name'] ?? 'Marketing').toString();

      try { await FlutterForegroundTask.stopService(); } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MarketingHome(userId: marketingDocId, userName: name),
        ),
      );
      return;
    }

    // 2) marketing where authUid == uid  (most common)
    final q = await db
        .collection('marketing')
        .where('authUid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty && (q.docs.first.data()['active'] == true)) {
      final doc = q.docs.first;
      final marketingDocId = doc.id; // <-- USE DOC ID
      final name = (doc.data()['name'] ?? 'Marketing').toString();

      try { await FlutterForegroundTask.stopService(); } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MarketingHome(userId: marketingDocId, userName: name),
        ),
      );
      return;
    }

    // 3) users/{uid}.role == 'marketing'  -> resolve real marketing doc id by authUid
    final userDoc = await db.collection('users').doc(user.uid).get();
    if (userDoc.exists && (userDoc.data()?['role'] == 'marketing')) {
      final q2 = await db
          .collection('marketing')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      final marketingDocId = q2.docs.isNotEmpty ? q2.docs.first.id : user.uid;
      final name = q2.docs.isNotEmpty
          ? (q2.docs.first.data()['name'] ?? 'Marketing').toString()
          : (userDoc.data()?['name'] ?? 'Marketing').toString();

      try { await FlutterForegroundTask.stopService(); } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MarketingHome(userId: marketingDocId, userName: name),
        ),
      );
      return;
    }

    // 4) Driver flow
    final d = await _drvSvc.findDriverForUser(user);
    if (!mounted) return;
    setState(() {
  driver = d;
  loading = false;

  final driverName = (d!.data['name'] ?? 'NA').toString();

  _pages = [
    TasksScreen(
      driverId: d.id,
      driverName: driverName,
    ),
    AttendanceScreen(
      userId: d.id,
      userName: driverName,
      collectionRoot: 'drivers',
    ),
    const _Placeholder(title: 'Profile'),
  ];
});

  }

 @override
Widget build(BuildContext context) {
  final premiumTheme = Theme.of(context).copyWith(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),

    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F4C75), // medical blue
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
Widget _buildContent(BuildContext context) {
  if (loading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  if (driver == null) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver')),
      body: LinkProfileScreen(onLinked: resolve),
    );
  }

  final driverName = (driver!.data['name'] ?? 'NA').toString();

  return Scaffold(
  appBar: AppBar(
    title: const Text('Driver Dashboard'),
    actions: [
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () async {
          try { await FlutterForegroundTask.stopService(); } catch (_) {}
          await _auth.signOut();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (_) => false,
            );
          }
        },
      ),
    ],
  ),

  body: _pages[_index],

  bottomNavigationBar: BottomNavigationBar(
    currentIndex: _index,
    onTap: (i) => setState(() => _index = i),
    type: BottomNavigationBarType.fixed,
    items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.local_shipping),
        label: 'Tasks',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.fingerprint),
        label: 'Attendance',
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
class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
