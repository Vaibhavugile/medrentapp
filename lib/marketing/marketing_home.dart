import 'package:flutter/material.dart';

import '../screens/attendance_screen.dart';
import 'screens/marketing_visits_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/today_screen.dart';
import '../screens/attendance_history_screen.dart';
import 'screens/marketing_profile_screen.dart';

class MarketingHome extends StatefulWidget {
  final String userId; // marketing DOC ID
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
      // ============================================================
      // TODAY
      // ============================================================
      TodayScreen(
        userId: widget.userId,
        userName: widget.userName,
      ),

      // ============================================================
      // VISITS
      // ============================================================
      MarketingVisitsScreen(
        userId: widget.userId,
        userName: widget.userName,
      ),

      // ============================================================
      // LEADS
      // ============================================================
      LeadsScreen(
        userId: widget.userId,
        userName: widget.userName,
      ),

      // ============================================================
      // ATTENDANCE
      // ============================================================
      AttendanceScreen(
        userId: widget.userId,
        userName: widget.userName,
        collectionRoot: 'marketing',
      ),

      // ============================================================
      // HISTORY
      // ============================================================
      AttendanceHistoryScreen(
        userId: widget.userId,
        collectionRoot: 'marketing',
      ),

      // ============================================================
      // PROFILE
      // ============================================================
      MarketingProfileScreen(
        marketingId: widget.userId,
      ),
    ];
  }

  // ================================================================
  // PROFILE TAB
  // ================================================================

  void _openProfile() {
    if (!mounted) return;

    setState(() {
      _tab = 5;
    });
  }

  // ================================================================
  // AVATAR
  // ================================================================

  Widget _profileAvatar() {
    final firstLetter = widget.userName.trim().isNotEmpty
        ? widget.userName.trim()[0].toUpperCase()
        : 'M';

    return GestureDetector(
      onTap: _openProfile,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.white.withOpacity(.90),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 3),
              color: Colors.black.withOpacity(.15),
            ),
          ],
        ),
        child: Center(
          child: Text(
            firstLetter,
            style: const TextStyle(
              color: Color(0xFF0F4C75),
              fontSize: 16,
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
                widget.userName.trim().isEmpty
                    ? 'Marketing Executive'
                    : widget.userName.trim(),
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
                'Marketing Executive',
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
        width: 32,
        height: 32,
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
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

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
                Color(0xFF0F4C75),
                Color(0xFF3282B8),
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
            // PROFILE ARROW
            // --------------------------------------------------------

            _profileArrow(),
          ],
        ),
      ),

      // ============================================================
      // PAGE BODY
      // ============================================================

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_tab),
          child: _pages[_tab],
        ),
      ),

      // ============================================================
      // PREMIUM BOTTOM NAVIGATION
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
                blurRadius: 18,
                color: Colors.black.withOpacity(.08),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BottomNavigationBar(
              currentIndex: _tab,

              onTap: (index) {
                if (_tab == index) return;

                setState(() {
                  _tab = index;
                });
              },

              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,

              selectedItemColor: const Color(0xFF0F4C75),
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
                // TODAY
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.today_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.today_rounded,
                  ),
                  label: 'Today',
                ),

                // ----------------------------------------------------
                // VISITS
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.place_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.place_rounded,
                  ),
                  label: 'Visits',
                ),

                // ----------------------------------------------------
                // LEADS
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.leaderboard_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.leaderboard_rounded,
                  ),
                  label: 'Leads',
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
                // HISTORY
                // ----------------------------------------------------

                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.history_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.history_rounded,
                  ),
                  label: 'History',
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
}
