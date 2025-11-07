import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  DriverDoc? driver;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    resolve();
  }

  Future<void> resolve() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final d = await _drvSvc.findDriverForUser(user);
    setState(() { driver = d; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (driver == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver')),
        body: LinkProfileScreen(onLinked: resolve),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _auth.signOut();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              },
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Attendance'),
            Tab(text: 'Tasks'),
          ]),
        ),
        body: TabBarView(
          children: [
            AttendanceScreen(driverId: driver!.id, driverName: (driver!.data['name'] ?? 'NA').toString()),
            TasksScreen(driverId: driver!.id,driverName: (driver!.data['name'] ?? 'NA').toString(),),
          ],


        ),
      ),
    );
  }
}
