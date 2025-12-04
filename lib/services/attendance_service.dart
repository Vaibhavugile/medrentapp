
// attendance_service.dart
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

  /// Helper: read today's attendance doc and return raw shifts map (keys as strings)
  Future<Map<String, dynamic>> _rawShifts(String driverId, String date) async {
    final snap = await attRef(driverId, date).get();
    if (!snap.exists) return {};
    final data = snap.data();
    if (data == null) return {};
    final raw = data['shifts'];
    if (raw == null || raw is! Map<String, dynamic>) return {};
    return Map<String, dynamic>.from(raw);
  }

  /// Determine latest open shift number for today (or null)
  Future<int?> getLatestOpenShiftNumber(String driverId) async {
    final date = todayISO();
    final raw = await _rawShifts(driverId, date);
    if (raw.isEmpty) return null;
    // find entries where checkOutMs == null
    final open = raw.entries.where((e) {
      final m = e.value as Map<String, dynamic>;
      return m['checkOutMs'] == null;
    }).toList();
    if (open.isEmpty) return null;
    open.sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key)));
    return int.parse(open.first.key);
  }

  /// Transactional check-in. Creates shifts.<n> map for today.
  Future<void> checkIn(
    String driverId,
    String driverName, {
    String? note,
    String? uid,
  }) async {
    final date = todayISO();
    final ref = attRef(driverId, date);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final Map<String, dynamic> docData = snap.exists && snap.data() != null ? Map<String, dynamic>.from(snap.data()!) : {};
      final Map<String, dynamic> shifts = Map<String, dynamic>.from(docData['shifts'] ?? {});

      // determine next shift number (max key + 1)
      final nextShift = shifts.keys.isEmpty
          ? 1
          : (shifts.keys.map(int.parse).reduce((a, b) => a > b ? a : b) + 1);
      final shiftKey = nextShift.toString();
      final now = DateTime.now().millisecondsSinceEpoch;

      final payload = {
        'checkInMs': now,
        'checkInServer': FieldValue.serverTimestamp(),
        'checkOutMs': null,
        'checkOutServer': null,
        'status': 'present',
        // 'locations': [], // small cache; main points go to locations subcollection
        'note': note ?? '',
        'createdAt': docData['createdAt'] ?? FieldValue.serverTimestamp(),
      };

      // set nested shift and top-level quick fields for backward compatibility
      tx.set(ref, {
        'date': date,
        'driverId': driverId,
        'driverName': driverName,
        'status': 'present',
        // Keep a top-level quick pointer to latest checkIn for compatibility
        'checkInMs': now,
        'checkInServer': FieldValue.serverTimestamp(),
        'checkOutMs': null,
        'checkOutServer': null,
        'note': note ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid ?? '',
        'shifts': {shiftKey: payload}
      }, SetOptions(merge: true));
    });
  }

  /// Check out the latest open shift or specified shiftNumber.
  /// Also updates top-level checkOut fields for backward compatibility.
  Future<void> checkOut(String driverId, {int? shiftNumber, String? uid}) async {
    final date = todayISO();
    final ref = attRef(driverId, date);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('No attendance doc for today');
      }
      final docData = Map<String, dynamic>.from(snap.data()!);
      final rawShifts = Map<String, dynamic>.from(docData['shifts'] ?? {});

      if (rawShifts.isEmpty) {
        // nothing to checkout - still write top-level checkout for compatibility
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        tx.set(ref, {
          'date': date,
          'driverId': driverId,
          'checkOutMs': nowMs,
          'checkOutServer': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid ?? '',
        }, SetOptions(merge: true));
        // end live docs
        tx.set(liveTodayDoc(driverId, date), {'endedAtServer': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        tx.set(driverLiveDoc(driverId), {'endedAtServer': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        return;
      }

      String targetShiftKey;
      if (shiftNumber != null) {
        targetShiftKey = shiftNumber.toString();
        if (!rawShifts.containsKey(targetShiftKey)) {
          throw Exception('Shift $shiftNumber not found');
        }
      } else {
        // pick latest open shift (checkOutMs == null)
        final open = rawShifts.entries.where((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          return m['checkOutMs'] == null;
        }).toList();
        if (open.isEmpty) {
          throw Exception('No open shift found to checkout.');
        }
        open.sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key)));
        targetShiftKey = open.first.key;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final update = {
        // update nested shift
        'shifts.$targetShiftKey.checkOutMs': nowMs,
        'shifts.$targetShiftKey.checkOutServer': FieldValue.serverTimestamp(),
        'shifts.$targetShiftKey.status': 'completed',
        // update top-level quick pointer for compatibility
        'checkOutMs': nowMs,
        'checkOutServer': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid ?? '',
      };

      tx.update(ref, update);

      // Mark live docs ended
      tx.set(liveTodayDoc(driverId, date), {'endedAtServer': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(driverLiveDoc(driverId), {'endedAtServer': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  /// Mark a status on the day doc (absent/half_day/late/present).
  /// If marking present, clear top-level checkIn/checkOut to allow a fresh check-in.
  Future<void> markStatus(
    String driverId,
    String status, {
    String? note,
    String? uid,
  }) async {
    final date = todayISO();
    final ref = attRef(driverId, date);
    final Map<String, dynamic> payload = {
      'date': date,
      'driverId': driverId,
      'status': status, // leave | absent | half_day | late | present
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid ?? '',
    };

    if (status == 'present') {
      payload['checkInMs'] = FieldValue.delete();
      payload['checkOutMs'] = FieldValue.delete();
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  /// Save a location point. Writes into a locations subcollection (detailed points),
  /// updates liveToday and driverLive quick docs, and appends into the open shift's
  /// shifts.<n>.locations array for a small summary (arrayUnion).
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

  // write detailed point in subcollection (unchanged)
  await locsCol(driverId, date).add(payload);

  // update live docs (unchanged)
  await liveTodayDoc(driverId, date).set(payload, SetOptions(merge: true));
  await driverLiveDoc(driverId).set(payload, SetOptions(merge: true));

  // NO longer appending any lightweight point into shifts.<n>.locations
}

}
