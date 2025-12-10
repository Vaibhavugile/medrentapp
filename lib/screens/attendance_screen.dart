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
    if (widget.collectionRoot != 'marketing') return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final db = FirebaseFirestore.instance;
      // First try marketing/{uid} if it exists and active
      final byId = await db.collection('marketing').doc(uid).get();
      String? resolved;
      if (byId.exists && (byId.data()?['active'] == true)) {
        resolved = byId.id;
      } else {
        // Else find by authUid
        final q = await db
            .collection('marketing')
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty && (q.docs.first.data()['active'] == true)) {
          resolved = q.docs.first.id;
        }
      }

      if (resolved != null &&
          resolved.isNotEmpty &&
          resolved != _effectiveUserId) {
        // Update effective id and restart location service with the correct id
        _effectiveUserId = resolved;
        // Recreate the LocationService with the resolved id
        _loc = LocationService(_att, _effectiveUserId, widget.collectionRoot);
        // If we were already tracking, restart so the isolate gets the new id
        if (tracking) {
          try {
            await _loc?.stop();
          } catch (_) {}
          await _loc?.start();
        }
      }
    } catch (_) {
      // ignore resolution errors; we’ll keep using widget.userId
    }
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
      try {
        await Permission.notification.request();
      } catch (_) {}

      try {
        final bgGranted = await _loc!.requestBgPermission();
        if (!bgGranted && mounted) {
          showSnack(context,
              "Please allow 'Location • Always' for continuous tracking.");
        }
      } catch (_) {}

      final now = DateTime.now();

      debugPrint('[checkIn] Compressing image...');
      final compressed = await _compressAttendanceImage(_attendanceImage!);

      debugPrint('[checkIn] Uploading image...');
      final url = await _att.uploadAttendanceImage(
        imageFile: compressed,
        driverId: _effectiveUserId,
        timestamp: now,
        type: 'check-in',
        // date not needed here; now maps to todayISO()
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
    final theme = Theme.of(context);
    final date = _att.todayISO();

    if (loading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final shifts = _getShiftsSorted(att);
    final latestOpen = _latestOpenShiftNumber(att);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _Chip(
                label: tracking ? 'Tracking ON' : 'Tracking OFF',
                color: tracking
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceVariant,
                icon: tracking ? Icons.fmd_good : Icons.fmd_bad_outlined,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(
                              label: 'Date: $date',
                              icon: Icons.calendar_today),
                          _Chip(
                            label:
                                'Status: ${(att?['status'] ?? '—').toString()}',
                            icon: Icons.verified_user_outlined,
                          ),
                          _Chip(
                            label: 'Shifts: ${shifts.length}',
                            icon: Icons.schedule,
                          ),
                          _Chip(
                            label:
                                'Check-in: ${timeFromMs(att?['checkInMs'])}',
                            icon: Icons.login,
                          ),
                          _Chip(
                            label:
                                'Check-out: ${timeFromMs(att?['checkOutMs'])}',
                            icon: Icons.logout,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        minLines: 2,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: 'Note for today',
                          hintText: 'Add a short note…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tracking saves every ~90s or when moved ≥50m.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ✅ Camera capture card (tap to open in-app camera, preview image)
              GestureDetector(
                onTap: saving ? null : _captureAttendanceImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _attendanceImage == null
                          ? theme.colorScheme.error.withOpacity(0.7)
                          : theme.colorScheme.outline,
                    ),
                    color: theme.colorScheme.surfaceVariant,
                  ),
                  child: _attendanceImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to capture photo (required for check-in / check-out)',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _attendanceImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              if (_openShiftDate != null && _openShiftDate != date)
                Card(
                  color: theme.colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Open shift from ${_openShiftDate}',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Shift #${_openShiftNumberAcrossDates ?? '—'} — still open. Tap Checkout to close this shift.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: (saving || _attendanceImage == null)
                              ? null
                              : () => checkOut(
                                  shiftNumber:
                                      _openShiftNumberAcrossDates),
                          child: const Text('Checkout'),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              if (shifts.isEmpty)
                Card(
                  child: ListTile(
                    title: const Text('No shifts yet today'),
                    subtitle: const Text('Tap Check-in to start a shift.'),
                  ),
                )
              else
                ...shifts.map((e) {
                  final number = e.key;
                  final data = e.value;
                  final checkInMs = data['checkInMs'] as int?;
                  final checkOutMs = data['checkOutMs'] as int?;
                  final status = (data['status'] ?? '').toString();
                  final noteText = (data['note'] ?? '').toString();
                  final checkInTime =
                      checkInMs != null ? timeFromMs(checkInMs) : '—';
                  final checkOutTime =
                      checkOutMs != null ? timeFromMs(checkOutMs) : '—';
                  final isOpen = checkOutMs == null;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(number.toString())),
                      title: Text(
                          'Shift $number — ${status.isNotEmpty ? status : '—'}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('In: $checkInTime — Out: $checkOutTime'),
                          if (noteText.isNotEmpty) Text('Note: $noteText'),
                        ],
                      ),
                      trailing: isOpen
                          ? PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'checkout') {
                                  if (_attendanceImage == null) {
                                    showSnack(context,
                                        'Please capture a photo before checking out');
                                  } else {
                                    checkOut(shiftNumber: number);
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'checkout',
                                  child: Text('Check out this shift'),
                                ),
                              ],
                              icon: const Icon(Icons.more_vert),
                            )
                          : null,
                    ),
                  );
                }).toList(),

              const SizedBox(height: 24),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionTile(
                    label: canCheckIn ? 'Check-in' : 'Checked-in',
                    icon: Icons.login,
                    onTap: (!saving &&
                            canCheckIn &&
                            _attendanceImage != null)
                        ? checkIn
                        : null,
                    tone: _ActionTone.primary,
                  ),
                  _ActionTile(
                    label: canCheckOut ? 'Check-out' : 'Checked-out',
                    icon: Icons.logout,
                    onTap: (!saving &&
                            canCheckOut &&
                            _attendanceImage != null)
                        ? () => checkOut(shiftNumber: latestOpen)
                        : null,
                    tone: _ActionTone.secondary,
                  ),
                  _ActionTile(
                    label: 'More',
                    icon: Icons.more_horiz,
                    onTap: saving ? null : _showMoreSheet,
                    tone: _ActionTone.neutral,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: saving
                  ? null
                  : (canCheckOut && _attendanceImage != null)
                      ? () => checkOut(shiftNumber: latestOpen)
                      : (canCheckIn && _attendanceImage != null)
                          ? checkIn
                          : null,
              icon: Icon(canCheckOut ? Icons.logout : Icons.login),
              label: Text(
                canCheckOut
                    ? 'Check-out'
                    : (canCheckIn ? 'Check-in' : 'Done for today'),
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
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

// ---------- small UI helpers ----------

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
