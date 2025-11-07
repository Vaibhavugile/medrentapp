import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'attendance_service.dart';
import 'location_task_handler.dart';

class LocationService {
  final AttendanceService _att;
  final String driverId;

  LocationService(this._att, this.driverId);

  Future<bool> ensurePermissions() async {
    // GPS on?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Foreground → Background
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse) {
      // Try to escalate to "Allow all the time" (Android 10+)
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  // Call this from your check-in flow to explicitly push for background permission
  Future<bool> requestBgPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse) {
      perm = await Geolocator.requestPermission(); // escalate if possible
    }
    return perm == LocationPermission.always;
  }

  Future<void> _startForegroundAndroid() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    // v6.5+: init() returns void — do NOT await
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'medrent_driver_location',
        channelName: 'Location Tracking',
        channelDescription: 'Tracking your route during duty.',
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
        interval: 60000, // onRepeatEvent every 60s
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Pass data to the background isolate (read via getData(key: ...))
    await FlutterForegroundTask.saveData(key: 'driverId', value: driverId);

    final running = await FlutterForegroundTask.isRunningService;
    if (!running) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Tracking in progress',
        notificationText: 'Your trip is being recorded.',
        callback: startCallback, // register handler entry
      );
    } else {
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
    if (!await ensurePermissions()) return;

    // Optional: capture one immediate point for a snappy first breadcrumb
    try {
      final cur = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 8),
      );
      await _att.savePoint(
        driverId,
        cur.latitude,
        cur.longitude,
        accuracy: cur.accuracy,
        speed: cur.speed,
        heading: cur.heading,
      );
    } catch (_) {
      // ignore — background handler will take over
    }

    await _startForegroundAndroid();
  }

  /// Call on checkout
  Future<void> stop() async {
    await _stopForegroundAndroid();
  }
}

/// Top-level entry point for the foreground task isolate
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}
