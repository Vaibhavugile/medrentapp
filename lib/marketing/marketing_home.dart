import 'package:flutter/material.dart';
import '../screens/attendance_screen.dart';
import 'screens/marketing_visits_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/today_screen.dart';
import '../screens/attendance_history_screen.dart';

class MarketingHome extends StatefulWidget {
  final String userId;   // marketing DOC ID
  final String userName;

  const MarketingHome({
    super.key,
    required this.userId,
    required this.userName,
  });

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
       AttendanceHistoryScreen(
    userId: widget.userId,
    collectionRoot: 'marketing',
  ),

    ];
  }

  @override
  Widget build(BuildContext context) {
    final firstLetter =
        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "M";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      /// PREMIUM APPBAR
      appBar: AppBar(
        elevation: 0,

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

        title: Row(
          children: [

            /// Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                firstLetter,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Marketing Executive",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                )
              ],
            )
          ],
        ),
      ),

      /// PAGE BODY
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_tab],
      ),

      /// PREMIUM BOTTOM NAV
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              color: Colors.black.withOpacity(.08),
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),

          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,

          selectedItemColor: const Color(0xFF0F4C75),
          unselectedItemColor: Colors.grey,

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
               BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),

          ],
        ),
      ),
    );
  }
}