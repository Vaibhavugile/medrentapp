import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'user_profile_screen.dart';

class UserHomeShell extends StatefulWidget {
  const UserHomeShell({super.key});

  @override
  State<UserHomeShell> createState() => _UserHomeShellState();
}

class _UserHomeShellState extends State<UserHomeShell> {
  final _auth = FirebaseAuth.instance;

  int _index = 0;

  String? name;
  String? role;
  String? profilePhotoUrl;

  bool loading = true;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        if (!mounted) return;

        setState(() {
          loading = false;
        });

        return;
      }

      final uid = currentUser.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data() ?? {};

      final userName = (data['name'] ?? 'User').toString().trim();
      final userRole = (data['role'] ?? 'Staff').toString().trim();

      final photoValue = (data['profilePhotoUrl'] ??
              data['photoUrl'] ??
              data['profilePhoto'] ??
              data['photo'] ??
              data['avatarUrl'] ??
              data['imageUrl'] ??
              '')
          .toString()
          .trim();

      if (!mounted) return;

      setState(() {
        name = userName.isEmpty ? 'User' : userName;
        role = userRole.isEmpty ? 'Staff' : userRole;
        profilePhotoUrl = photoValue;
        loading = false;

        _pages = [
          AttendanceScreen(
            userId: uid,
            userName: name!,
            collectionRoot: 'users',
          ),
          AttendanceHistoryScreen(
            userId: uid,
            collectionRoot: 'users',
          ),
          UserProfileScreen(
            userId: uid,
          ),
        ];
      });
    } catch (e) {
      debugPrint('Load user error: $e');

      if (!mounted) return;

      setState(() {
        name = 'User';
        role = 'Staff';
        profilePhotoUrl = '';
        loading = false;

        final uid = _auth.currentUser?.uid ?? '';

        _pages = [
          AttendanceScreen(
            userId: uid,
            userName: 'User',
            collectionRoot: 'users',
          ),
          AttendanceHistoryScreen(
            userId: uid,
            collectionRoot: 'users',
          ),
          UserProfileScreen(
            userId: uid,
          ),
        ];
      });
    }
  }

  String _initial(String? value) {
    final clean = (value ?? '').trim();

    if (clean.isEmpty) return 'U';

    return clean.substring(0, 1).toUpperCase();
  }

  void _goToProfile() {
    if (!mounted) return;

    setState(() {
      _index = 2;
    });
  }

  Widget _appBarProfileAvatar() {
    final photo = profilePhotoUrl?.trim() ?? '';
    final hasPhoto = photo.isNotEmpty;

    return GestureDetector(
      onTap: _goToProfile,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.white.withOpacity(.9),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 3),
              color: Colors.black.withOpacity(.15),
            ),
          ],
          image: hasPhoto
              ? DecorationImage(
                  image: NetworkImage(photo),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: hasPhoto
            ? null
            : Center(
                child: Text(
                  _initial(name),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _appBarUserInfo() {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goToProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name ?? 'User',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                role ?? 'Staff',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4CA1AF),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

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
            // PROFILE PHOTO / INITIAL
            _appBarProfileAvatar(),

            const SizedBox(width: 10),

            // NAME + ROLE
            _appBarUserInfo(),

            const SizedBox(width: 6),

            // PROFILE ARROW
            GestureDetector(
              onTap: _goToProfile,
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
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
            ),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    title: const Text(
                      'Logout?',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
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
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  );
                },
              );

              if (shouldLogout != true) return;

              try {
                await _auth.signOut();

                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (_) => false,
                  );
                }
              } catch (e) {
                debugPrint('Logout error: $e');

                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Unable to logout. Please try again.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                }
              }
            },
          ),
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _pages[_index],
        ),
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withOpacity(.08),
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
              selectedItemColor: const Color(0xFF4CA1AF),
              unselectedItemColor: const Color(0xFF8A94A6),
              selectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.fingerprint),
                  activeIcon: Icon(Icons.fingerprint_rounded),
                  label: 'Attendance',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history_rounded),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
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
