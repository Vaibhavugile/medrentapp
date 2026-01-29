// marketing_home.dart
import 'package:flutter/material.dart';
import '../screens/attendance_screen.dart';
import 'screens/marketing_visits_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/today_screen.dart';

class MarketingHome extends StatefulWidget {
  final String userId;   // this must be the marketing DOC ID, not auth UID
  final String userName;
  const MarketingHome({super.key, required this.userId, required this.userName});



  @override
  State<MarketingHome> createState() => _MarketingHomeState();
}

class _MarketingHomeState extends State<MarketingHome> {
  int _tab = 0;
  late final List<Widget> _pages;
@override
void initState() {
  super.initState();
  _pages = [
    TodayScreen(userId: widget.userId, userName: widget.userName),
    MarketingVisitsScreen(userId: widget.userId, userName: widget.userName),
    LeadsScreen(userId: widget.userId, userName: widget.userName),
    AttendanceScreen(
      userId: widget.userId,
      userName: widget.userName,
      collectionRoot: 'marketing',
    ),
  ];
}

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
  appBar: AppBar(
    title: const Text('Marketing Dashboard'),
  ),

  body: _pages[_tab],

 bottomNavigationBar: BottomNavigationBar(
  currentIndex: _tab,
  onTap: (i) => setState(() => _tab = i),
  type: BottomNavigationBarType.fixed,
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.today),
      label: 'Today',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.place),
      label: 'Visits',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.leaderboard),
      label: 'Leads',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.fingerprint),
      label: 'Attendance',
    ),
  ],
),

);

  }
}
