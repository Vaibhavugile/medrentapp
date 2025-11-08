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

  Future<bool> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<bool> requestBgPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always;
  }

  Future<void> _startForegroundAndroid() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

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
        interval: 60000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    /// ✅ Pass correct identity + role to background isolate
    await FlutterForegroundTask.saveData(key: 'userId', value: userId);
    await FlutterForegroundTask.saveData(key: 'collectionRoot', value: collectionRoot);

    final running = await FlutterForegroundTask.isRunningService;
    if (!running) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Tracking in progress',
        notificationText: 'Your trip is being recorded.',
        callback: startCallback,
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
    } catch (_) {}

    await _startForegroundAndroid();
  }

  /// Call on check-out
  Future<void> stop() async {
    await _stopForegroundAndroid();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}
