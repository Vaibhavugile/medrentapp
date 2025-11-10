import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';

class AttendanceScreen extends StatefulWidget {
  final String userId;          // may be authUid or docId (we’ll resolve)
  final String userName;
  final String collectionRoot;  // 'drivers' or 'marketing'

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

  // persistent controller for the note field (prevents rebuild issues)
  final TextEditingController _noteController = TextEditingController();

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

      if (resolved != null && resolved.isNotEmpty && resolved != _effectiveUserId) {
        // Update effective id and restart location service with the correct id
        _effectiveUserId = resolved;
        // Recreate the LocationService with the resolved id
        _loc = LocationService(_att, _effectiveUserId, widget.collectionRoot);
        // If we were already tracking, restart so the isolate gets the new id
        if (tracking) {
          try { await _loc?.stop(); } catch (_) {}
          await _loc?.start();
        }
      }
    } catch (_) {
      // ignore resolution errors; we’ll keep using widget.userId
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await _att.load(_effectiveUserId, _att.todayISO());
    setState(() {
      att = data;
      loading = false;
      tracking = data != null && data['checkInMs'] != null && data['checkOutMs'] == null;
      note = (data != null ? (data['note'] ?? '') : '') as String;
      // keep controller in sync after load
      _noteController.text = note;
    });
    if (tracking) {
      await _loc?.start();
    }
  }

  bool get canCheckIn => att == null || att?['checkInMs'] == null;
  bool get canCheckOut => att != null && att?['checkInMs'] != null && att?['checkOutMs'] == null;

  Future<void> checkIn() async {
    if (!canCheckIn || !mounted) return;

    final ok = await showConfirm(context, 'Confirm check-in now?');
    if (!ok) return;

    setState(() => saving = true);
    try {
      try { await Permission.notification.request(); } catch (_) {}

      try {
        final bgGranted = await _loc!.requestBgPermission();
        if (!bgGranted && mounted) {
          showSnack(context, "Please allow 'Location • Always' for continuous tracking.");
        }
      } catch (_) {}

      await _att.checkIn(
        _effectiveUserId,
        widget.userName,
        note: note,
        uid: FirebaseAuth.instance.currentUser?.uid,
      );

      // Start tracking only after successful check-in
      await _loc?.start();
      await _load();
      setState(() => tracking = true);
      if (mounted) showSnack(context, 'Checked-in.');
    } finally {
      setState(() => saving = false);
    }
  }

  Future<void> checkOut() async {
    if (!canCheckOut) return;
    final ok = await showConfirm(context, 'Confirm check-out now?');
    if (!ok) return;

    setState(() => saving = true);
    try {
      // ✅ CRITICAL ORDER: stop tracking FIRST to avoid saving a point at checkout
      await _loc?.stop();

      // Then call checkout (no lat/lng should be sent by the service)
      await _att.checkOut(
        _effectiveUserId,
        uid: FirebaseAuth.instance.currentUser?.uid,
      );

      await _load();
      setState(() => tracking = false);
      if (mounted) showSnack(context, 'Checked-out.');
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

  // --------- MOBILE-FRIENDLY UI BELOW ---------

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(label: 'Date: $date', icon: Icons.calendar_today),
                          _Chip(
                            label: 'Status: ${(att?['status'] ?? '—').toString()}',
                            icon: Icons.verified_user_outlined,
                          ),
                          _Chip(
                            label: 'Check-in: ${timeFromMs(att?['checkInMs'])}',
                            icon: Icons.login,
                          ),
                          _Chip(
                            label: 'Check-out: ${timeFromMs(att?['checkOutMs'])}',
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

              const SizedBox(height: 24),

              // Quick actions grid for larger phones (will wrap on small screens)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionTile(
                    label: canCheckIn ? 'Check-in' : 'Checked-in',
                    icon: Icons.login,
                    onTap: (!saving && canCheckIn) ? checkIn : null,
                    tone: _ActionTone.primary,
                  ),
                  _ActionTile(
                    label: canCheckOut ? 'Check-out' : 'Checked-out',
                    icon: Icons.logout,
                    onTap: (!saving && canCheckOut) ? checkOut : null,
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

      // Sticky bottom call-to-action bar
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: saving
                  ? null
                  : canCheckOut
                      ? checkOut
                      : (canCheckIn ? checkIn : null),
              icon: Icon(canCheckOut ? Icons.logout : Icons.login),
              label: Text(
                canCheckOut ? 'Check-out' : (canCheckIn ? 'Check-in' : 'Done for today'),
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
        ),
      ),
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetAction(
                  icon: Icons.beach_access_outlined,
                  label: 'Leave',
                  onTap: () { Navigator.pop(ctx); markStatus('leave'); },
                ),
                _SheetAction(
                  icon: Icons.block_outlined,
                  label: 'Absent',
                  onTap: () { Navigator.pop(ctx); markStatus('absent'); },
                ),
                _SheetAction(
                  icon: Icons.timelapse_outlined,
                  label: 'Half-day',
                  onTap: () { Navigator.pop(ctx); markStatus('half_day'); },
                ),
                _SheetAction(
                  icon: Icons.schedule_outlined,
                  label: 'Late',
                  onTap: () { Navigator.pop(ctx); markStatus('late'); },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
      _ActionTone.secondary => theme.colorScheme.onSecondaryContainer,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Opacity(
      opacity: onTap == null ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
  const _SheetAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      minLeadingWidth: 24,
    );
  }
}

String timeFromMs(dynamic ms) {
  if (ms == null) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Future<bool> showConfirm(BuildContext ctx, String msg) async {
  return await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
          ],
        ),
      ) ?? false;
}

void showSnack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}
