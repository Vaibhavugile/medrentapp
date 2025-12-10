// attendance_service.dart
import 'dart:io'; // ✅ added for File
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // ✅ added for Firebase Storage
import 'package:intl/intl.dart';

class AttendanceService {
  final _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // ✅ storage instance

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

  /// 🔹 NEW: Upload an attendance photo to Firebase Storage and
  ///        store its URL on the day's attendance doc.
  ///
  /// - [type] can be 'check-in' or 'check-out' (or any label you like)
  /// - [timestamp] is when the photo was taken (usually DateTime.now())
  /// - [date] if provided (yyyy-MM-dd) forces the storage/att doc to that date.
  ///
  /// Firestore write:
  ///   collectionRoot/{driverId}/attendance/{date}:
  ///     { "<type>PhotoUrl": "...", "<type>PhotoStoragePath": "..." }
  Future<String> uploadAttendanceImage({
    required File imageFile,
    required String driverId,
    required DateTime timestamp,
    required String type, // e.g. 'check-in' or 'check-out'
    String? date, // optional override: 'yyyy-MM-dd'
  }) async {
    // If caller provided explicit date, use it. Otherwise derive date from timestamp (local).
    final String dateToUse = date ?? DateFormat('yyyy-MM-dd').format(timestamp.toLocal());

    // Build a unique file name + path in Storage
    final String fileName = '${timestamp.millisecondsSinceEpoch}.jpg';
    final String storagePath =
        'attendancePhotos/$collectionRoot/$driverId/$dateToUse/${type}_$fileName';

    final Reference ref = _storage.ref().child(storagePath);

    // Upload to Firebase Storage
    final UploadTask uploadTask = ref.putFile(imageFile);
    final TaskSnapshot snapshot = await uploadTask;

    // Get download URL
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    // Merge URL + storage path into that day's attendance doc
    await attRef(driverId, dateToUse).set({
      '${type}PhotoUrl': downloadUrl,
      '${type}PhotoStoragePath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return downloadUrl;
  }

  /// Helper: read attendance doc for a date and return raw shifts map (keys as strings)
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
  /// NOTE: this now searches across recent dates (today + previous days) to account for
  /// night-shift checkins that start on previous day and end after midnight.
  Future<int?> getLatestOpenShiftNumber(String driverId) async {
    final result = await findLatestOpenShiftAcrossDates(driverId);
    if (result == null) return null;
    return result['shiftNumber'] as int?;
  }

  /// Helper: check a single day's rawShifts map and return latest open shift key (string) or null.
  String? _latestOpenShiftKeyFromRaw(Map<String, dynamic> raw) {
    if (raw.isEmpty) return null;
    final open = raw.entries.where((e) {
      final m = e.value as Map<String, dynamic>;
      return m['checkOutMs'] == null;
    }).toList();
    if (open.isEmpty) return null;
    open.sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key)));
    return open.first.key;
  }

  /// Search recent dates (today, yesterday, ...) up to [maxDaysBack] for an open shift.
  /// Returns a map with keys: 'date' (String) and 'shiftNumber' (int) or null if none found.
  /// Uses LOCAL date arithmetic so strings match `todayISO()` which also uses local time.
  Future<Map<String, dynamic>?> findLatestOpenShiftAcrossDates(
    String driverId, {
    int maxDaysBack = 2, // search today + previous (maxDaysBack - 1) days
    int maxAgeHours = 48, // ignore checkins older than this
  }) async {
    final now = DateTime.now(); // <-- use local time so date strings align with todayISO()
    final maxAge = Duration(hours: maxAgeHours);

    for (int offset = 0; offset < maxDaysBack; offset++) {
      final date = DateFormat('yyyy-MM-dd')
          .format(now.subtract(Duration(days: offset)));
      final raw = await _rawShifts(driverId, date);
      if (raw.isEmpty) continue;
      final key = _latestOpenShiftKeyFromRaw(raw);
      if (key == null) continue;

      final shift = raw[key];
      if (shift == null || shift is! Map<String, dynamic>) continue;

      // Determine checkin DateTime in local timezone for safe comparisons
      DateTime? checkinDt;

      final checkInMs = shift['checkInMs'];
      if (checkInMs == null) {
        final checkInServer = shift['checkInServer'];
        if (checkInServer is Timestamp) {
          checkinDt = checkInServer.toDate().toLocal();
        } else if (checkInServer is DateTime) {
          checkinDt = (checkInServer as DateTime).toLocal();
        } else {
          // No reliable checkin time — skip this shift
          continue;
        }
      } else {
        if (checkInMs is int) {
          checkinDt = DateTime.fromMillisecondsSinceEpoch(checkInMs).toLocal();
        } else if (checkInMs is String) {
          final ms = int.tryParse(checkInMs) ?? 0;
          checkinDt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
        } else {
          final checkInServer = shift['checkInServer'];
          if (checkInServer is Timestamp) {
            checkinDt = checkInServer.toDate().toLocal();
          } else if (checkInServer is DateTime) {
            checkinDt = (checkInServer as DateTime).toLocal();
          } else {
            continue;
          }
        }
      }

      if (checkinDt == null) continue;
      if (checkinDt.isAfter(now)) continue; // future — ignore
      if (now.difference(checkinDt) > maxAge) continue; // too old

      return {
        'date': date,
        'shiftNumber': int.parse(key),
      };
    }

    return null;
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
      final Map<String, dynamic> docData = snap.exists && snap.data() != null
          ? Map<String, dynamic>.from(snap.data()!)
          : {};
      final Map<String, dynamic> shifts =
          Map<String, dynamic>.from(docData['shifts'] ?? {});

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
      tx.set(
        ref,
        {
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
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Check out the latest open shift or specified shiftNumber.
  /// Also updates top-level checkOut fields for backward compatibility.
  ///
  /// IMPORTANT: If no open shift is found in *today's* doc, this method will
  /// search previous date documents (up to 2 days back by default) and attempt
  /// to checkout the latest open shift it finds.
  Future<void> checkOut(String driverId, {int? shiftNumber, String? uid}) async {
    // First try today's document
    final dateToday = todayISO();
    final refToday = attRef(driverId, dateToday);

    // Try transaction on today's doc; if it fails to find an open shift and
    // shiftNumber is null, we'll search previous dates and checkout there.
    await _db.runTransaction((tx) async {
      final snap = await tx.get(refToday);
      if (!snap.exists) {
        // No today's doc -> we will search across dates below (outside this tx)
        return;
      }
      final docData = Map<String, dynamic>.from(snap.data() ?? {});
      final rawShifts = Map<String, dynamic>.from(docData['shifts'] ?? {});

      if (rawShifts.isEmpty) {
        // nothing to checkout in today's doc -> return and let outer logic search prev dates
        return;
      }

      String targetShiftKey;
      if (shiftNumber != null) {
        targetShiftKey = shiftNumber.toString();
        if (!rawShifts.containsKey(targetShiftKey)) {
          // specified shift not found in today's doc -> let outer logic handle searching other dates
          return;
        }
      } else {
        // pick latest open shift (checkOutMs == null)
        final open = rawShifts.entries.where((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          return m['checkOutMs'] == null;
        }).toList();
        if (open.isEmpty) {
          // no open shift in today's doc -> allow outer logic to search previous dates
          return;
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

      tx.update(refToday, update);

      // Mark live docs ended
      tx.set(
        liveTodayDoc(driverId, dateToday),
        {'endedAtServer': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      tx.set(
        driverLiveDoc(driverId),
        {'endedAtServer': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    });

    // After the above transaction, verify whether we actually checked out something in today's doc.
    // If not, and a specific shiftNumber was not provided (or provided but not in today's doc),
    // search previous dates for an open shift and checkout there.
    try {
      final todaySnap = await refToday.get();
      bool didCheckoutInToday = false;
      if (todaySnap.exists) {
        final docData = Map<String, dynamic>.from(todaySnap.data() ?? {});
        final rawShifts = Map<String, dynamic>.from(docData['shifts'] ?? {});
        if (rawShifts.isNotEmpty) {
          if (shiftNumber != null) {
            final key = shiftNumber.toString();
            final shiftMap = rawShifts[key];
            if (shiftMap is Map<String, dynamic> &&
                shiftMap['checkOutMs'] != null) {
              didCheckoutInToday = true;
            }
          } else {
            final open = rawShifts.entries.where((e) {
              final m = Map<String, dynamic>.from(e.value as Map);
              return m['checkOutMs'] == null;
            }).toList();
            if (open.isEmpty) {
              didCheckoutInToday = true;
            } else {
              didCheckoutInToday = false;
            }
          }
        } else {
          didCheckoutInToday = true;
        }
      } else {
        didCheckoutInToday = false;
      }

      if (!didCheckoutInToday) {
        final found = await findLatestOpenShiftAcrossDates(
          driverId,
          maxDaysBack: 3,
          maxAgeHours: 72,
        );
        if (found != null) {
          final targetDate = found['date'] as String;
          final targetShift = found['shiftNumber'] as int;
          await checkoutOnDate(
            driverId,
            targetDate,
            shiftNumber: targetShift,
            uid: uid,
          );
        } else {
          throw Exception('No open shift found to checkout.');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Transaction-safe checkout on a specific date's attendance doc.
  /// Writes `checkout` fields only if the targeted shift's checkout is null.
  Future<void> checkoutOnDate(
    String driverId,
    String date, {
    required int shiftNumber,
    String? uid,
  }) async {
    final ref = attRef(driverId, date);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Attendance doc for $date not found');
      }
      final docData = Map<String, dynamic>.from(snap.data() ?? {});
      final rawShifts = Map<String, dynamic>.from(docData['shifts'] ?? {});

      final key = shiftNumber.toString();
      if (!rawShifts.containsKey(key)) {
        throw Exception('Shift $shiftNumber not found on $date');
      }

      final shiftMap = rawShifts[key] as Map<String, dynamic>;
      if (shiftMap['checkOutMs'] != null) {
        // already checked out
        return;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final update = {
        'shifts.$key.checkOutMs': nowMs,
        'shifts.$key.checkOutServer': FieldValue.serverTimestamp(),
        'shifts.$key.status': 'completed',
        // Also update top-level quick pointers (use the date's doc for compatibility)
        'checkOutMs': nowMs,
        'checkOutServer': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid ?? '',
      };

      tx.update(ref, update);

      // Mark live docs ended for that date
      tx.set(
        liveTodayDoc(driverId, date),
        {'endedAtServer': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      tx.set(
        driverLiveDoc(driverId),
        {'endedAtServer': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
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
  ///
  /// NOTE: this always writes the point to today's doc (todayISO()). If you want
  /// points to be stored against the shift's original date instead, call a variant
  /// that accepts a `date` parameter and pass the shift date.
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
