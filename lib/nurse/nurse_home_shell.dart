import 'package:flutter/material.dart';

import 'nurse_home_screen.dart';
import '../screens/attendance_screen.dart';

class NurseHomeShell extends StatefulWidget {
  final String staffId;    // ✅ STAFF DOC ID
  final String staffName;  // ✅ STAFF NAME

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

    _pages = [
      const NurseHomeScreen(),

      // ✅ REUSED attendance screen (CORRECT ID)
      AttendanceScreen(
        userId: widget.staffId,      // ✅ STAFF DOC ID
        userName: widget.staffName,  // ✅ REAL NAME
        collectionRoot: 'staff',
      ),

      const _Placeholder(title: 'Salary'),
      const _Placeholder(title: 'Profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
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

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
