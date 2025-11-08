import 'dart:async';
import 'dart:isolate'; // for SendPort
import 'dart:math' show sin, cos, asin, sqrt, pi;

import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';

import 'attendance_service.dart';

class LocationTaskHandler extends TaskHandler {
  AttendanceService? _att;
  String? _userId;                 // was _driverId
  String _collectionRoot = 'drivers'; // default; will be overwritten by saved data

  Position? _lastSaved;
  int _lastSavedMs = 0;

  static const int minIntervalMs = 90000; // ~90s
  static const double minMoveMeters = 50; // ≥50 m

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // Initialize Firebase inside the background isolate
    try {
      await Firebase.initializeApp();
    } catch (_) {}

    // Receive identity + role from LocationService.start()
    _userId = await FlutterForegroundTask.getData<String>(key: 'userId');
    final root = await FlutterForegroundTask.getData<String>(key: 'collectionRoot');
    if (root != null && root.isNotEmpty) {
      _collectionRoot = root;
    }

    // Recreate role-aware AttendanceService
    _att = AttendanceService(collectionRoot: _collectionRoot);

    FlutterForegroundTask.updateService(
      notificationTitle: 'Tracking in progress',
      notificationText: 'Recording your route… ($_collectionRoot)',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    if (_userId == null || _att == null) return;

    // 1) Preconditions with gentle nudges
    final gpsOn = await Geolocator.isLocationServiceEnabled();
    if (!gpsOn) {
      FlutterForegroundTask.updateService(
        notificationText: 'GPS is OFF — turn it on to continue tracking',
      );
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      FlutterForegroundTask.updateService(
        notificationText: 'Location permission missing — enable to continue',
      );
      return;
    }

    // 2) Get a fix quickly; fallback to last known
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      final fallback = await Geolocator.getLastKnownPosition();
      if (fallback == null) return;
      pos = fallback;
    }

    // 3) Throttle saves by distance/time
    final now = DateTime.now().millisecondsSinceEpoch;
    final moved = (_lastSaved == null)
        ? double.infinity
        : _haversineMeters(
            _lastSaved!.latitude, _lastSaved!.longitude, pos.latitude, pos.longitude);

    final since = now - _lastSavedMs;
    if (_lastSaved == null || moved >= minMoveMeters || since >= minIntervalMs) {
      await _att!.savePoint(
        _userId!,                // role-agnostic id
        pos.latitude,
        pos.longitude,
        accuracy: pos.accuracy,
        speed: pos.speed,
        heading: pos.heading,
      );
      _lastSaved = pos;
      _lastSavedMs = now;

      FlutterForegroundTask.updateService(
        notificationText:
            'Tracking… ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} ($_collectionRoot)',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Nothing to clean up; UI calls stop() on checkout
  }

  @override
  void onButtonPressed(String id) async {
    if (id == 'stop') {
      await FlutterForegroundTask.stopService();
    }
  }
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  double toRad(double x) => x * pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = (sin(dLat / 2) * sin(dLat / 2)) +
      (cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2));
  return 2 * R * asin(sqrt(a));
}
