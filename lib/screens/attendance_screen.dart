import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart'; // <-- ADDED
import '../services/attendance_service.dart';
import '../services/location_service.dart';

class AttendanceScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  const AttendanceScreen({super.key, required this.driverId, required this.driverName});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _att = AttendanceService();
  LocationService? _loc;
  Map<String, dynamic>? att;
  bool loading = true;
  bool saving = false;
  String note = '';
  bool tracking = false;

  @override
  void initState() {
    super.initState();
    _loc = LocationService(_att, widget.driverId);
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await _att.load(widget.driverId, _att.todayISO());
    setState(() {
      att = data;
      loading = false;
      tracking = data != null && data['checkInMs'] != null && data['checkOutMs'] == null;
      note = (data != null ? (data['note'] ?? '') : '') as String;
    });
    // If already checked-in, ensure background tracking is running.
    if (tracking) {
      await _loc?.start();
    }
  }

  bool get canCheckIn => att == null || att?['checkInMs'] == null;
  bool get canCheckOut => att != null && att?['checkInMs'] != null && att?['checkOutMs'] == null;

  Future<void> checkIn() async {
    if (!canCheckIn) return;
    if (!mounted) return;

    final ok = await showConfirm(context, 'Confirm check-in now?');
    if (!ok) return;

    setState(() => saving = true);
    try {
      // 1) Android 13+ notification permission (safe to call on all Android)
      try {
        await Permission.notification.request();
      } catch (_) {
        // ignore if platform doesn’t support it
      }

      // 2) Request background location (“Allow all the time”) if available
      try {
        final bgGranted = await _loc!.requestBgPermission();
        if (!bgGranted && mounted) {
          showSnack(context, "Please allow 'Location • Always' for continuous tracking.");
        }
      } catch (_) {
        // If requestBgPermission isn't supported on platform, continue
      }

      // 3) Record check-in
      await _att.checkIn(
        widget.driverId,
        widget.driverName,
        note: note,
        uid: FirebaseAuth.instance.currentUser?.uid,
      );

      // 4) Start unstoppable background tracking (foreground service)
      await _loc?.start();

      // 5) Refresh UI
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
      await _att.checkOut(
        widget.driverId,
        uid: FirebaseAuth.instance.currentUser?.uid,
      );
      // Stop foreground tracking only on checkout
      await _loc?.stop();
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
        widget.driverId,
        status,
        note: note,
        uid: FirebaseAuth.instance.currentUser?.uid,
      );
      // If not present, stop tracking
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
  void dispose() {
    // IMPORTANT: Do NOT stop tracking here — it should continue after leaving screen.
    // _loc?.stop();  <-- removed on purpose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final date = _att.todayISO();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: $date', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: InfoTile('Status', (att?['status'] ?? '—').toString())),
                Expanded(child: InfoTile('Check-in', timeFromMs(att?['checkInMs']))),
                Expanded(child: InfoTile('Check-out', timeFromMs(att?['checkOutMs']))),
                Expanded(child: InfoTile('Tracking', tracking ? 'On' : 'Off')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Note'),
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (v) => note = v,
                    controller: TextEditingController(text: note),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton(
                  onPressed: (!saving && canCheckIn) ? checkIn : null,
                  child: Text(canCheckIn ? 'Check-in' : 'Checked-in'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: (!saving && canCheckOut) ? checkOut : null,
                  child: Text(canCheckOut ? 'Check-out' : 'Checked-out'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: saving ? null : () => markStatus('leave'),
                  child: const Text('Leave'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: saving ? null : () => markStatus('absent'),
                  child: const Text('Absent'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: saving ? null : () => markStatus('half_day'),
                  child: const Text('Half-day'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: saving ? null : () => markStatus('late'),
                  child: const Text('Late'),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                '• Tracking saves every ~90s or when moved ≥50m (Android background via service; iOS significant changes).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const InfoTile(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
      ) ??
      false;
}

void showSnack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}
