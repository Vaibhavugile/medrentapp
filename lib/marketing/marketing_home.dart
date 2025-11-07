import 'package:flutter/material.dart';
import '../screens/attendance_screen.dart';
// reuse your existing attendance screen
import 'screens/marketing_visits_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/today_screen.dart';

class MarketingHome extends StatefulWidget {
  final String userId;
  final String userName;
  const MarketingHome({super.key, required this.userId, required this.userName});

  @override
  State<MarketingHome> createState() => _MarketingHomeState();
}

class _MarketingHomeState extends State<MarketingHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(userId: widget.userId, userName: widget.userName),
      MarketingVisitsScreen(userId: widget.userId, userName: widget.userName),
      LeadsScreen(userId: widget.userId, userName: widget.userName),
      AttendanceScreen(driverId: widget.userId, driverName: widget.userName), // reuse
    ];

    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.place_outlined), label: 'Visits'),
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), label: 'Leads'),
          NavigationDestination(icon: Icon(Icons.access_time), label: 'Attendance'),
        ],
      ),
    );
  }
}
