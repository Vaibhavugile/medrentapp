// attendance_screen.dart
import 'dart:io';

import 'package:camera/camera.dart'; // ✅ in-app camera
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // ✅ compress
import 'package:path_provider/path_provider.dart'; // ✅ temp dir
import 'package:path/path.dart' as p; // ✅ file paths
import 'package:geolocator/geolocator.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';
import 'attendance_camera_screen.dart'; // ✅ new screen

class AttendanceScreen extends StatefulWidget {
  final String userId; // may be authUid or docId (we’ll resolve)
  final String userName;
  final String collectionRoot; // 'drivers' or 'marketing'

  const AttendanceScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.collectionRoot,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceService _att =
      AttendanceService(collectionRoot: widget.collectionRoot);

  LocationService? _loc;

  // The id we actually use for Firestore paths (resolved below)
  late String _effectiveUserId;

  Map<String, dynamic>? att;
  bool loading = true;
  bool saving = false;
  String note = '';
  bool tracking = false;

  // Cross-date open shift info (if a shift started on previous date and is still open)
  String? _openShiftDate; // 'yyyy-MM-dd' or null
  int? _openShiftNumberAcrossDates;

  // persistent controller for the note field (prevents rebuild issues)
  final TextEditingController _noteController = TextEditingController();

  // ✅ captured image (from in-app camera)
  File? _attendanceImage;

  @override
  void initState() {
    super.initState();
    _effectiveUserId = widget.userId; // default to passed value
    _loc = LocationService(_att, _effectiveUserId, widget.collectionRoot);
    _noteController.addListener(() => note = _noteController.text);
    _resolveMarketingIdIfNeeded().then((_) => _load());
  }

  @override
  void dispose() {
    _noteController.dispose();
    // Do not stop tracking here; should continue after leaving screen
    super.dispose();
  }

  /// If marketing, resolve the true docId by authUid. If it differs
  /// from what we received, switch to it and restart the location service.
Future<void> _resolveMarketingIdIfNeeded() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;
    String? resolved;

    // ================= MARKETING (EXISTING LOGIC, UNCHANGED) =================
    if (widget.collectionRoot == 'marketing') {
      final byId = await db.collection('marketing').doc(uid).get();
      if (byId.exists && (byId.data()?['active'] == true)) {
        resolved = byId.id;
      } else {
        final q = await db
            .collection('marketing')
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty && q.docs.first.data()['active'] == true) {
          resolved = q.docs.first.id;
        }
      }
    }

    // ================= STAFF / NURSE (NEW, SAME PATTERN) =================
    if (widget.collectionRoot == 'staff') {
      final q = await db
          .collection('staff')
          .where('authUid', isEqualTo: uid)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        resolved = q.docs.first.id;
      }
    }
    // ================= USERS (NEW — NO RESOLUTION NEEDED) =================
if (widget.collectionRoot == 'users') {
  // users collection uses auth UID directly
  _effectiveUserId = FirebaseAuth.instance.currentUser!.uid;

  // recreate LocationService
  _loc = LocationService(_att, _effectiveUserId, widget.collectionRoot);

  return;
}

    // ================= APPLY RESOLUTION =================
    if (resolved != null &&
        resolved.isNotEmpty &&
        resolved != _effectiveUserId) {
      _effectiveUserId = resolved;

      // recreate LocationService with correct docId
      _loc = LocationService(_att, _effectiveUserId, widget.collectionRoot);

      // restart tracking if already running
      if (tracking) {
        try {
          await _loc?.stop();
        } catch (_) {}
        await _loc?.start();
      }
    }
  } catch (_) {
    // silent fail → fallback keeps app working
  }
}
Future<bool> _showLocationDisclosure() async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Location Tracking Disclosure"),
          content: const Text(
            "This app collects and transmits your location data to your employer "
            "to enable workforce attendance monitoring and live job tracking "
            "during active work sessions.\n\n"
            "Location tracking starts only after you Check-in and continues even "
            "when the app is closed or not in use.\n\n"
            "Tracking stops automatically when you Check-out."
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Deny"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Allow"),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _showBackgroundPermissionGuide() async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text("Enable Background Location"),
      content: const Text(
        "To enable attendance tracking, please select "
        "'Allow all the time' in the next screen.\n\n"
        "This allows the app to track your location "
        "during active work sessions even when the app "
        "is closed."
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings(); // Opens app settings
          },
          child: const Text("Open Settings"),
        ),
      ],
    ),
  );
}

  Future<void> _load() async {
    setState(() => loading = true);
    // Load today's attendance doc into `att`
    final data = await _att.load(_effectiveUserId, _att.todayISO());
    // Also find any open shift across recent dates
    Map<String, dynamic>? found;
    try {
      final foundMap = await _att.findLatestOpenShiftAcrossDates(
        _effectiveUserId,
        maxDaysBack: 3,
        maxAgeHours: 72,
      );
      found = foundMap;
    } catch (_) {
      found = null;
    }

    setState(() {
      att = data;
      loading = false;
      note = (data != null ? (data['note'] ?? '') : '') as String;
      if (found != null) {
        _openShiftDate = (found['date'] as String?) ?? null;
        _openShiftNumberAcrossDates =
            (found['shiftNumber'] as int?) ?? null;
      } else {
        _openShiftDate = null;
        _openShiftNumberAcrossDates = null;
      }
    });

    // determine tracking based on open shift (shifts map) or fallback to top-level fields
    final hasOpenToday = _hasOpenShift(att);
    final topLevelOpen =
        att != null && att?['checkInMs'] != null && att?['checkOutMs'] == null;
    final crossDateOpen = _openShiftNumberAcrossDates != null;

    tracking = hasOpenToday || topLevelOpen || crossDateOpen;
    if (tracking) {
      await _loc?.start();
    } else {
      try {
        await _loc?.stop();
      } catch (_) {}
    }

    _noteController.text = note;
  }

  bool _hasOpenShift(Map<String, dynamic>? data) {
    if (data == null) return false;
    final raw = data['shifts'];
    if (raw == null || raw is! Map<String, dynamic>) return false;
    try {
      final entries = Map<String, dynamic>.from(raw).entries;
      for (final e in entries) {
        final m = e.value as Map<String, dynamic>;
        if (m['checkOutMs'] == null) return true;
      }
    } catch (_) {}
    return false;
  }

  List<MapEntry<int, Map<String, dynamic>>> _getShiftsSorted(
      Map<String, dynamic>? data) {
    if (data == null) return [];
    final raw = data['shifts'];
    if (raw == null || raw is! Map<String, dynamic>) return [];
    final parsed = <MapEntry<int, Map<String, dynamic>>>[];
    try {
      final mp = Map<String, dynamic>.from(raw);
      for (final e in mp.entries) {
        final key = int.tryParse(e.key) ?? 0;
        final value = Map<String, dynamic>.from(e.value as Map);
        parsed.add(MapEntry(key, value));
      }
      parsed.sort((a, b) => a.key.compareTo(b.key));
    } catch (_) {}
    return parsed;
  }

  int? _latestOpenShiftNumber(Map<String, dynamic>? data) {
    final list = _getShiftsSorted(data);
    final open = list.where((e) => e.value['checkOutMs'] == null).toList();
    if (open.isEmpty) return null;
    open.sort((a, b) => b.key.compareTo(a.key));
    return open.first.key;
  }

  bool get canCheckIn {
    return _latestOpenShiftNumber(att) == null &&
        _openShiftNumberAcrossDates == null;
  }

  bool get canCheckOut {
    return _latestOpenShiftNumber(att) != null ||
        _openShiftNumberAcrossDates != null;
  }

  // ✅ In-app camera: open our custom camera screen and get image back
  Future<void> _captureAttendanceImage() async {
    debugPrint('[_captureAttendanceImage] Opening in-app camera...');
    final XFile? pic = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(
        builder: (_) => const AttendanceCameraScreen(),
        fullscreenDialog: true,
      ),
    );

    if (pic != null) {
      debugPrint('[_captureAttendanceImage] Result: ${pic.path}');
      setState(() {
        _attendanceImage = File(pic.path);
      });
      debugPrint('[_captureAttendanceImage] Image set in state');
    } else {
      debugPrint('[_captureAttendanceImage] User cancelled camera');
    }
  }

  /// ✅ Compress image before upload to make check-in/out faster
  Future<File> _compressAttendanceImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          p.join(dir.path, 'att_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 60, // 0–100
        minWidth: 640,
        minHeight: 640,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        debugPrint('[compress] Compression returned null, using original');
        return file;
      }

      debugPrint('[compress] Original: ${file.lengthSync()} bytes, '
          'Compressed: ${File(result.path).lengthSync()} bytes');

      return File(result.path);
    } catch (e) {
      debugPrint('[compress] Failed: $e');
      return file; // fallback
    }
  }

  Future<void> checkIn() async {
  debugPrint('[checkIn] canCheckIn=$canCheckIn mounted=$mounted');
  if (!canCheckIn || !mounted) return;

  if (_attendanceImage == null) {
    showSnack(context, 'Please capture a photo before checking in');
    return;
  }

  final ok = await showConfirm(context, 'Confirm check-in now?');
  if (!ok) return;

  setState(() => saving = true);
  try {
    // 🔔 Request notification permission (Android 13+)
    try {
      await Permission.notification.request();
    } catch (_) {}

    // 🛑 STEP 1 — Show Prominent Disclosure (REQUIRED BY GOOGLE)
    final disclosureAccepted = await _showLocationDisclosure();
    if (!disclosureAccepted) {
      if (mounted) {
        showSnack(context, "Location permission required to check-in.");
      }
      setState(() => saving = false);
      return;
    }

    // 📍 STEP 2 — Request Background Location Permission
   try {
  final bgGranted = await _loc!.requestBgPermission();

  if (!bgGranted && mounted) {
    // 🔔 Show instruction dialog before opening settings
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Enable Background Location"),
        content: const Text(
          "To enable attendance tracking, please select "
          "'Allow all the time' in the next screen.\n\n"
          "This allows the app to track your location "
          "during active work sessions even when the app "
          "is closed."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );

    setState(() => saving = false);
    return;
  }
} catch (_) {
  setState(() => saving = false);
  return;
}

    final now = DateTime.now();

    debugPrint('[checkIn] Compressing image...');
    final compressed = await _compressAttendanceImage(_attendanceImage!);

    debugPrint('[checkIn] Uploading image...');
    final url = await _att.uploadAttendanceImage(
      imageFile: compressed,
      driverId: _effectiveUserId,
      timestamp: now,
      type: 'check-in',
    );
    debugPrint('[checkIn] Image uploaded. URL=$url');

    await _att.checkIn(
      _effectiveUserId,
      widget.userName,
      note: note,
      uid: FirebaseAuth.instance.currentUser?.uid,
    );
    debugPrint('[checkIn] Attendance doc updated');

    setState(() {
      _attendanceImage = null;
    });

    await _loc?.start();
    await _load();
    setState(() => tracking = true);

    if (mounted) showSnack(context, 'Checked-in.');
  } catch (e, st) {
    debugPrint('[checkIn] ERROR: $e');
    debugPrint('[checkIn] STACK: $st');
    if (mounted) showSnack(context, 'Failed to check-in: $e');
  } finally {
    setState(() => saving = false);
  }
}

  Future<void> checkOut({int? shiftNumber}) async {
    if (!canCheckOut) return;

    if (_attendanceImage == null) {
      showSnack(context, 'Please capture a photo before checking out');
      return;
    }

    final ok = await showConfirm(context, 'Confirm check-out now?');
    if (!ok) return;

    setState(() => saving = true);
    try {
      await _loc?.stop();

      // --- DETERMINE targetDate & targetShift BEFORE uploading image ---
      String targetDate = _att.todayISO();
      int? targetShift = shiftNumber;

      final todayOpen = _latestOpenShiftNumber(att);

      if (shiftNumber != null) {
        // If caller specified a shiftNumber, decide which date it belongs to
        if (todayOpen != null && shiftNumber == todayOpen) {
          // This shift is open in today's doc
          targetDate = _att.todayISO();
          targetShift = shiftNumber;
        } else if (_openShiftNumberAcrossDates != null &&
            _openShiftDate != null &&
            shiftNumber == _openShiftNumberAcrossDates) {
          // This is the cross-date open shift
          targetDate = _openShiftDate!;
          targetShift = shiftNumber;
        } else {
          // Fallback: try to discover via service
          final found = await _att.findLatestOpenShiftAcrossDates(
            _effectiveUserId,
            maxDaysBack: 3,
            maxAgeHours: 72,
          );
          if (found != null &&
              (found['shiftNumber'] as int?) == shiftNumber) {
            targetDate = found['date'] as String;
            targetShift = shiftNumber;
          } else {
            // Last fallback: assume today (keeps behavior predictable)
            targetDate = _att.todayISO();
            targetShift = shiftNumber;
          }
        }
      } else {
        // No explicit shiftNumber: choose open shift preferring today's doc
        if (todayOpen != null) {
          targetDate = _att.todayISO();
          targetShift = todayOpen;
        } else if (_openShiftNumberAcrossDates != null &&
            _openShiftDate != null) {
          targetDate = _openShiftDate!;
          targetShift = _openShiftNumberAcrossDates;
        } else {
          final found = await _att.findLatestOpenShiftAcrossDates(
            _effectiveUserId,
            maxDaysBack: 3,
            maxAgeHours: 72,
          );
          if (found != null) {
            targetDate = found['date'] as String;
            targetShift = found['shiftNumber'] as int?;
          }
        }
      }

      debugPrint(
          '[checkOut] Target date for checkout: $targetDate, shift: $targetShift');

      debugPrint('[checkOut] Compressing image...');
      final compressed = await _compressAttendanceImage(_attendanceImage!);

      // Use current time for filename; explicitly force the doc date via `date: targetDate`
      debugPrint('[checkOut] Uploading image tied to date $targetDate...');
      final url = await _att.uploadAttendanceImage(
        imageFile: compressed,
        driverId: _effectiveUserId,
        timestamp: DateTime.now(),
        type: 'check-out',
        date: targetDate, // ✅ ensure image is stored under the shift's date
      );
      debugPrint('[checkOut] Image uploaded. URL=$url');

      // Now perform the checkout against the correct date/shift
      if (targetShift != null) {
        await _att.checkOut(
          _effectiveUserId,
          shiftNumber: targetShift,
          uid: FirebaseAuth.instance.currentUser?.uid,
        );
      } else {
        // fallback to normal checkout discovery inside AttendanceService
        await _att.checkOut(
          _effectiveUserId,
          uid: FirebaseAuth.instance.currentUser?.uid,
        );
      }

      setState(() {
        _attendanceImage = null;
      });

      await _load();
      setState(() => tracking = false);
      if (mounted) showSnack(context, 'Checked-out.');
    } catch (e, st) {
      debugPrint('[checkOut] ERROR: $e');
      debugPrint('[checkOut] STACK: $st');
      if (mounted) showSnack(context, 'Failed to check-out: $e');
    } finally {
      setState(() => saving = false);
    }
  }

  Future<void> markStatus(String status) async {
    final ok = await showConfirm(context, 'Mark $status for today?');
    if (!ok) return;

    setState(() => saving = true);
    try {
      await _att.markStatus(
        _effectiveUserId,
        status,
        note: note,
        uid: FirebaseAuth.instance.currentUser?.uid,
      );
      if (status != 'present') {
        await _loc?.stop();
      }
      await _load();
      if (mounted) showSnack(context, 'Marked $status.');
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _att.todayISO();

    if (loading) {
      return const Scaffold(
        backgroundColor: _AttendanceTheme.background,
        body: Center(
          child: CircularProgressIndicator(
            color: _AttendanceTheme.primary,
            strokeWidth: 2.8,
          ),
        ),
      );
    }

    final shifts = _getShiftsSorted(att);
    final latestOpen = _latestOpenShiftNumber(att);
    final hasPhoto = _attendanceImage != null;
    final crossDateOpen = _openShiftDate != null && _openShiftDate != date;

    return Scaffold(
      backgroundColor: _AttendanceTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _AttendanceTheme.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _buildAttendanceHero(
                  date: date,
                  shifts: shifts.length,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildLiveStatusCard(),
                    const SizedBox(height: 14),
                    _buildTodaySummaryCard(
                      date: date,
                      shiftCount: shifts.length,
                    ),
                                        _buildCameraCard(hasPhoto),
                                                            const SizedBox(height: 14),


                    // _buildNoteCard(),
                    const SizedBox(height: 14),
                    if (crossDateOpen) ...[
                      const SizedBox(height: 14),
                      _buildCrossDateCard(),
                    ],
                    const SizedBox(height: 22),
                    _buildShiftSectionHeader(shifts.length),
                    const SizedBox(height: 10),
                    if (shifts.isEmpty)
                      _buildNoShiftCard()
                    else
                      ...shifts.map(_buildShiftTimelineItem),
                    const SizedBox(height: 20),
                    // _buildQuickActions(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAction(latestOpen: latestOpen),
    );
  }

  Widget _buildAttendanceHero({
    required String date,
    required int shifts,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_AttendanceTheme.heroDark, _AttendanceTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _heroIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Attendance",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Daily workforce attendance",
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _trackingBadge(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _heroMetric(
                  icon: Icons.calendar_today_rounded,
                  label: "TODAY",
                  value: date,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _heroMetric(
                  icon: Icons.layers_rounded,
                  label: "SHIFTS",
                  value: "$shifts",
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _heroMetric(
                  icon: Icons.access_time_rounded,
                  label: "STATUS",
                  value: tracking ? "ACTIVE" : "IDLE",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _trackingBadge() {
    final active = tracking;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? _AttendanceTheme.green.withOpacity(.16)
            : Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active
              ? _AttendanceTheme.green.withOpacity(.35)
              : Colors.white.withOpacity(.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active
                ? Icons.location_on_rounded
                : Icons.location_off_rounded,
            size: 15,
            color: active
                ? const Color(0xff86EFAC)
                : Colors.white.withOpacity(.70),
          ),
          const SizedBox(width: 5),
          Text(
            active ? "Tracking ON" : "Tracking OFF",
            style: TextStyle(
              color: active
                  ? const Color(0xffDCFCE7)
                  : Colors.white.withOpacity(.78),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(.70)),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.52),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    final status = (att?['status'] ?? 'Not marked').toString();
    final open = canCheckOut;

    return _premiumSectionCard(
      child: Row(
        children: [
          _iconBox(
            open ? Icons.radio_button_checked_rounded : Icons.verified_rounded,
            open ? _AttendanceTheme.green : _AttendanceTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open ? "Work session active" : "Attendance status",
                  style: const TextStyle(
                    color: _AttendanceTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  open
                      ? "A shift is currently open"
                      : "Current status: $status",
                  style: const TextStyle(
                    color: _AttendanceTheme.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          _statusPill(
            open ? "ACTIVE" : "READY",
            open ? _AttendanceTheme.green : _AttendanceTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummaryCard({
    required String date,
    required int shiftCount,
  }) {
    return _premiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.today_rounded,
            title: "Today's Summary",
            subtitle: "Quick overview of your attendance",
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  "Check-in",
                  timeFromTimestamp(att?['checkInServer']),
                  Icons.login_rounded,
                  _AttendanceTheme.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetric(
                  "Check-out",
                  timeFromTimestamp(att?['checkOutServer']),
                  Icons.logout_rounded,
                  _AttendanceTheme.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  "Shifts",
                  "$shiftCount",
                  Icons.layers_rounded,
                  _AttendanceTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetric(
                  "Date",
                  date,
                  Icons.calendar_month_rounded,
                  _AttendanceTheme.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _AttendanceTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AttendanceTheme.border),
        boxShadow: _AttendanceTheme.shadow,
      ),
      child: child,
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        _iconBox(icon, _AttendanceTheme.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _AttendanceTheme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _AttendanceTheme.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }

  Widget _summaryMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AttendanceTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _AttendanceTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AttendanceTheme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard() {
    return _premiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.sticky_note_2_rounded,
            title: "Today's Note",
            subtitle: "Add a note related to this attendance",
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: "Add a short note…",
              hintStyle: const TextStyle(
                color: _AttendanceTheme.muted,
                fontSize: 13,
              ),
              filled: true,
              fillColor: _AttendanceTheme.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _AttendanceTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: _AttendanceTheme.primary,
                  width: 1.3,
                ),
              ),
              contentPadding: const EdgeInsets.all(13),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: _AttendanceTheme.muted,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Location tracking saves approximately every 90 seconds or after 50m movement.",
                  style: TextStyle(
                    color: _AttendanceTheme.muted,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard(bool hasPhoto) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: saving ? null : _captureAttendanceImage,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: hasPhoto ? 210 : 174,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasPhoto
                ? _AttendanceTheme.surface
                : _AttendanceTheme.primarySoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasPhoto
                  ? _AttendanceTheme.border
                  : _AttendanceTheme.primary.withOpacity(.25),
              width: 1.2,
            ),
            boxShadow: _AttendanceTheme.shadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_attendanceImage!, fit: BoxFit.cover),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.94),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: _AttendanceTheme.green,
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                "Photo captured • Tap to retake",
                                style: TextStyle(
                                  color: _AttendanceTheme.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.camera_alt_rounded,
                              color: _AttendanceTheme.primary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _AttendanceTheme.shadow,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: _AttendanceTheme.primary,
                        size: 27,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Capture attendance photo",
                      style: TextStyle(
                        color: _AttendanceTheme.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Required before check-in / check-out",
                      style: TextStyle(
                        color: _AttendanceTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCrossDateCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _AttendanceTheme.orange.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _AttendanceTheme.orange.withOpacity(.25),
        ),
      ),
      child: Row(
        children: [
          _iconBox(Icons.warning_amber_rounded, _AttendanceTheme.orange),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Open shift from $_openShiftDate",
                  style: const TextStyle(
                    color: _AttendanceTheme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Shift #${_openShiftNumberAcrossDates ?? '—'} is still open. Use Checkout to close it.",
                  style: const TextStyle(
                    color: _AttendanceTheme.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _compactButton(
            label: "Checkout",
            icon: Icons.logout_rounded,
            color: _AttendanceTheme.orange,
            onTap: saving || _attendanceImage == null
                ? null
                : () => checkOut(
                      shiftNumber: _openShiftNumberAcrossDates,
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSectionHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Shift Timeline",
                style: TextStyle(
                  color: _AttendanceTheme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Today's attendance sessions",
                style: TextStyle(
                  color: _AttendanceTheme.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _AttendanceTheme.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count ${count == 1 ? 'shift' : 'shifts'}",
            style: const TextStyle(
              color: _AttendanceTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftTimelineItem(
    MapEntry<int, Map<String, dynamic>> entry,
  ) {
    final number = entry.key;
    final data = entry.value;
    final checkIn = data['checkInServer'];
    final checkOut = data['checkOutServer'];
    final status = (data['status'] ?? '').toString();
    final noteText = (data['note'] ?? '').toString();
    final open = checkOut == null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 20),
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: _AttendanceTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: open
                        ? _AttendanceTheme.green
                        : _AttendanceTheme.primary,
                    width: 4,
                  ),
                ),
              ),
              Container(
                width: 2,
                height: open ? 225 : 170,
                color: _AttendanceTheme.border,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _AttendanceTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: open
                    ? _AttendanceTheme.green.withOpacity(.30)
                    : _AttendanceTheme.border,
              ),
              boxShadow: _AttendanceTheme.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _numberBadge(number),
                          const SizedBox(width: 10),
                          const Text(
                            "Shift",
                            style: TextStyle(
                              color: _AttendanceTheme.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusPill(
                      open
                          ? "OPEN"
                          : (status.isEmpty ? "COMPLETED" : status),
                      open
                          ? _AttendanceTheme.green
                          : _AttendanceTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _shiftInfoRow(
                  Icons.login_rounded,
                  "Check In",
                  checkIn == null ? "—" : timeFromTimestamp(checkIn),
                  _AttendanceTheme.green,
                ),
                const SizedBox(height: 9),
                _shiftInfoRow(
                  Icons.logout_rounded,
                  "Check Out",
                  checkOut == null ? "Still open" : timeFromTimestamp(checkOut),
                  _AttendanceTheme.red,
                ),
                const SizedBox(height: 9),
                _shiftInfoRow(
                  Icons.location_on_outlined,
                  "Tracking",
                  open ? "Live" : "Stopped",
                  _AttendanceTheme.primary,
                ),
                if (noteText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _AttendanceTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      noteText,
                      style: const TextStyle(
                        color: _AttendanceTheme.textSoft,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                if (open) ...[
                  const SizedBox(height: 13),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving || _attendanceImage == null
                          ? null
                          : () => checkOut(shiftNumber: number),
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text("Check out this shift"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AttendanceTheme.red,
                        side: BorderSide(
                          color: _AttendanceTheme.red.withOpacity(.28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberBadge(int number) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _AttendanceTheme.primarySoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        child: Text(
          "$number",
          style: const TextStyle(
            color: _AttendanceTheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _shiftInfoRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _AttendanceTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _AttendanceTheme.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _numberedEmptyState() => const SizedBox.shrink();

  Widget _buildNoShiftCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: _AttendanceTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AttendanceTheme.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.schedule_rounded,
              color: _AttendanceTheme.muted, size: 42),
          SizedBox(height: 10),
          Text(
            "No shifts yet today",
            style: TextStyle(
              color: _AttendanceTheme.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Capture a photo and use Check-in to start your shift.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _AttendanceTheme.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            color: _AttendanceTheme.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.login_rounded,
                title: canCheckIn ? "Check-in" : "Checked-in",
                subtitle: "Start shift",
                color: _AttendanceTheme.primary,
                enabled: !saving && canCheckIn && _attendanceImage != null,
                onTap: checkIn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickAction(
                icon: Icons.logout_rounded,
                title: canCheckOut ? "Check-out" : "Checked-out",
                subtitle: "End shift",
                color: _AttendanceTheme.red,
                enabled: !saving && canCheckOut && _attendanceImage != null,
                onTap: () => checkOut(shiftNumber: latestOpen),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickAction(
                icon: Icons.more_horiz_rounded,
                title: "More",
                subtitle: "Other status",
                color: _AttendanceTheme.orange,
                enabled: !saving,
                onTap: _showMoreSheet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .48,
      child: Material(
        color: _AttendanceTheme.surface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _AttendanceTheme.border),
              boxShadow: _AttendanceTheme.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBox(icon, color),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AttendanceTheme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AttendanceTheme.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(.30)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({required int? latestOpen}) {
    final canAction = !saving &&
        ((canCheckOut && _attendanceImage != null) ||
            (canCheckIn && _attendanceImage != null));
    final checkout = canCheckOut;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 14),
      decoration: BoxDecoration(
        color: _AttendanceTheme.surface,
        border: const Border(
          top: BorderSide(color: _AttendanceTheme.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.07),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: canAction
              ? () {
                  if (checkout) {
                    checkOut(shiftNumber: latestOpen);
                  } else {
                    checkIn();
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                checkout ? _AttendanceTheme.red : _AttendanceTheme.primary,
            disabledBackgroundColor: _AttendanceTheme.surfaceAlt,
            foregroundColor: Colors.white,
            disabledForegroundColor: _AttendanceTheme.muted,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                checkout ? Icons.logout_rounded : Icons.login_rounded,
                size: 20,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  saving
                      ? "Processing..."
                      : checkout
                          ? "Check-out"
                          : canCheckIn
                              ? "Check-in"
                              : "Done for today",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? get latestOpen {
    final todayOpen = _latestOpenShiftNumber(att);
    if (todayOpen != null) return todayOpen;
    return _openShiftNumberAcrossDates;
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetAction(
                  icon: Icons.beach_access_outlined,
                  label: 'Leave',
                  onTap: () {
                    Navigator.pop(ctx);
                    markStatus('leave');
                  },
                ),
                _SheetAction(
                  icon: Icons.block_outlined,
                  label: 'Absent',
                  onTap: () {
                    Navigator.pop(ctx);
                    markStatus('absent');
                  },
                ),
                _SheetAction(
                  icon: Icons.timelapse_outlined,
                  label: 'Half-day',
                  onTap: () {
                    Navigator.pop(ctx);
                    markStatus('half_day');
                  },
                ),
                _SheetAction(
                  icon: Icons.schedule_outlined,
                  label: 'Late',
                  onTap: () {
                    Navigator.pop(ctx);
                    markStatus('late');
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------- premium UI helpers ----------


class _AttendanceTheme {
  static const background = Color(0xffF6F8FC);
  static const surface = Color(0xffFFFFFF);
  static const surfaceAlt = Color(0xffF1F4F9);

  static const text = Color(0xff101828);
  static const textSoft = Color(0xff344054);
  static const muted = Color(0xff667085);

  static const border = Color(0xffE4E7EC);
  static const borderStrong = Color(0xffD0D5DD);

  static const primary = Color(0xff3157D5);
  static const primarySoft = Color(0xffEEF2FF);
  static const heroDark = Color(0xff172554);

  static const green = Color(0xff059669);
  static const greenSoft = Color(0xffECFDF3);
  static const blue = Color(0xff2563EB);
  static const orange = Color(0xffD97706);
  static const red = Color(0xffDC2626);
  static const redSoft = Color(0xffFEF2F2);

  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ];
}



class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _Chip({required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionTone { primary, secondary, neutral }

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final _ActionTone tone;
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = switch (tone) {
      _ActionTone.primary => theme.colorScheme.primaryContainer,
      _ActionTone.secondary => theme.colorScheme.secondaryContainer,
      _ => theme.colorScheme.surfaceVariant,
    };
    final fg = switch (tone) {
      _ActionTone.primary => theme.colorScheme.onPrimaryContainer,
      _ActionTone.secondary =>
        theme.colorScheme.onSecondaryContainer,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Opacity(
      opacity: onTap == null ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: fg),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8),
      minLeadingWidth: 24,
    );
  }
}

String timeFromMs(dynamic ms) {
  if (ms == null) return '—';
  final d =
      DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Future<bool> showConfirm(BuildContext ctx, String msg) async {
  return await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes')),
          ],
        ),
      ) ??
      false;
}

void showSnack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx)
      .showSnackBar(SnackBar(content: Text(msg)));
}
String timeFromTimestamp(dynamic ts) {
  if (ts == null) return '—';

  final d = (ts as Timestamp).toDate();

  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}