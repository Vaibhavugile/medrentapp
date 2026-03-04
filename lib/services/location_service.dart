import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'attendance_service.dart';
import 'location_task_handler.dart';

class LocationService {
  final AttendanceService _att;
  final String userId;          // was driverId
  final String collectionRoot;  // NEW

  LocationService(this._att, this.userId, this.collectionRoot);

  bool _enabled = false;
  bool get isTracking => _enabled;

  Future<bool> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    // Try to escalate if only while-in-use
    if (perm == LocationPermission.whileInUse) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<bool> requestBgPermission() async {
  // STEP 1: Ensure location services are enabled
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    await Geolocator.openLocationSettings();
    return false;
  }

  // STEP 2: Request foreground location first
  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return false;
  }

  // If already always, we are good
  if (permission == LocationPermission.always) {
    return true;
  }

  // STEP 3: If only whileInUse, redirect to app settings
  if (permission == LocationPermission.whileInUse) {
    await Geolocator.openAppSettings();
    return false;
  }

  return false;
}
  Future<void> _startForegroundAndroid() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'medrent_driver_location',
        channelName: 'Location Tracking',
        channelDescription:'Tracks location during active work sessions for attendance.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [const NotificationButton(id: 'stop', text: 'Stop')],
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 60000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Pass identity + role to background isolate
    await FlutterForegroundTask.saveData(key: 'userId', value: userId);
    await FlutterForegroundTask.saveData(key: 'collectionRoot', value: collectionRoot);

    final running = await FlutterForegroundTask.isRunningService;
    if (!running) {
      await FlutterForegroundTask.startService(
  notificationTitle: 'Workforce Tracking Active',
  notificationText:
      'Location tracking is active during your work session.',
  callback: startCallback,
);
    } else {
      // If it was already running, just refresh data
      await FlutterForegroundTask.restartService();
    }
  }

  Future<void> _stopForegroundAndroid() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (running) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Call on check-in
  Future<void> start() async {
    if (_enabled) return; // idempotent
    if (!await ensurePermissions()) return;

    _enabled = true;

    // One-shot save at start (for the check-in location)
    try {
      final cur = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 8),
      );
      await _att.savePoint(
        userId,
        cur.latitude,
        cur.longitude,
        accuracy: cur.accuracy,
        speed: cur.speed,
        heading: cur.heading,
      );
    } catch (_) {
      // ignore one-shot failures
    }

    await _startForegroundAndroid();
  }

  /// Call on check-out
  Future<void> stop() async {
    if (!_enabled) {
      // Still ensure foreground is off just in case
      await _stopForegroundAndroid();
      return;
    }
    _enabled = false;

    // IMPORTANT: do NOT fetch/save a location here.
    await _stopForegroundAndroid();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}
