import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final _db = FirebaseFirestore.instance;

  /// Root collection to write under: pass 'drivers' or 'marketing'
  final String collectionRoot;

  AttendanceService({required this.collectionRoot});

  String todayISO() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  DocumentReference<Map<String, dynamic>> attRef(String driverId, String date) =>
      _db.doc('$collectionRoot/$driverId/attendance/$date');

  CollectionReference<Map<String, dynamic>> locsCol(String driverId, String date) =>
      _db.collection('$collectionRoot/$driverId/attendance/$date/locations');

  DocumentReference<Map<String, dynamic>> liveTodayDoc(String driverId, String date) =>
      _db.doc('$collectionRoot/$driverId/attendance/$date/live/current');

  DocumentReference<Map<String, dynamic>> driverLiveDoc(String driverId) =>
      _db.doc('$collectionRoot/$driverId/liveToday/current');

  Future<Map<String, dynamic>?> load(String driverId, String date) async {
    final snap = await attRef(driverId, date).get();
    return snap.data();
  }

  Future<void> checkIn(
    String driverId,
    String driverName, {
    String? note,
    String? uid,
  }) async {
    final date = todayISO();
    final ref = attRef(driverId, date);
    final now = DateTime.now().millisecondsSinceEpoch;
    await ref.set({
      'date': date,
      'driverId': driverId,
      'driverName': driverName,
      'status': 'present',
      'checkInMs': now,
      'checkInServer': FieldValue.serverTimestamp(),
      'checkOutMs': null,
      'checkOutServer': null,
      'note': note ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid ?? '',
    }, SetOptions(merge: true));
  }

  /// Checkout DOES NOT include any location—only timestamps/markers.
  Future<void> checkOut(String driverId, {String? uid}) async {
    final date = todayISO();
    final ref = attRef(driverId, date);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Merge-safe (won’t throw if doc missing). Keeps existing status/fields intact.
    await ref.set({
      'date': date,
      'driverId': driverId,
      'checkOutMs': now,
      'checkOutServer': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid ?? '',
    }, SetOptions(merge: true));

    // Mark live docs ended
    await liveTodayDoc(driverId, date)
        .set({'endedAtServer': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await driverLiveDoc(driverId)
        .set({'endedAtServer': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> markStatus(
    String driverId,
    String status, {
    String? note,
    String? uid,
  }) async {
    final date = todayISO();
    final ref = attRef(driverId, date);
    await ref.set({
      'date': date,
      'driverId': driverId,
      'status': status, // leave | absent | half_day | late | present
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid ?? '',
      // If marking present, clear any stale check-in/out to let a fresh check-in happen.
      'checkInMs': status == 'present' ? FieldValue.delete() : null,
      'checkOutMs': status == 'present' ? FieldValue.delete() : null,
    }, SetOptions(merge: true));
  }

  Future<void> savePoint(
    String driverId,
    double lat,
    double lng, {
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    final date = todayISO();
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'capturedAtMs': now,
      'capturedAtServer': FieldValue.serverTimestamp(),
      'driverId': driverId,
      'date': date,
    };
    await locsCol(driverId, date).add(payload);
    await liveTodayDoc(driverId, date).set(payload, SetOptions(merge: true));
    await driverLiveDoc(driverId).set(payload, SetOptions(merge: true));
  }
}
