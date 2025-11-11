import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryService {
  final _db = FirebaseFirestore.instance;

  /// Stages copied 1:1 from web
  static const stages = [
    'assigned', 'accepted', 'in_transit', 'delivered', 'completed', 'rejected'
  ];

  static String label(String s) => const {
    'assigned': 'Assigned',
    'accepted': 'Accepted',
    'in_transit': 'Pickup / In transit',
    'delivered': 'Delivered',
    'completed': 'Completed',
    'rejected': 'Rejected',
  }[s] ?? s;

  // -------------------- helpers (new) --------------------

  /// Normalize various timestamp-like values to millisecondsSinceEpoch.
  int? _toMillis(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is int) return v;
    if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch;
    return null;
    }

  /// Extract the earliest expectedStartDate from delivery.items.
  /// Supports: List<Map> or single Map; flexible key spellings.
  dynamic _extractExpectedStartDateFromItems(dynamic items) {
    int? bestMs;

    void consider(dynamic val) {
      final ms = _toMillis(val);
      if (ms == null) return;
      if (bestMs == null || ms < bestMs!) bestMs = ms;
    }

    if (items is List) {
      for (final it in items) {
        if (it is! Map) continue;
        consider(it['expectedStartDate']);
        consider(it['expectedstartdate']);
        consider(it['expected_start_date']);
        // sometimes nested under schedule/scheduling objects
        final sched = it['schedule'] ?? it['scheduling'];
        if (sched is Map) {
          consider(sched['expectedStartDate']);
          consider(sched['expected_start_date']);
        }
      }
    } else if (items is Map) {
      consider(items['expectedStartDate']);
      consider(items['expectedstartdate']);
      consider(items['expected_start_date']);
    }

    // Return milliseconds (int) so UI formatters can handle it easily.
    return bestMs;
  }

  // -------------------- streams & mutations --------------------

  /// Stream deliveries for a driver + hydrate order + merge histories (same as web)
  Stream<List<Map<String, dynamic>>> streamDriverDeliveries(String driverId) {
    final q = _db.collection('deliveries').where('driverId', isEqualTo: driverId);
    return q.snapshots().asyncMap((snap) async {
      final out = <Map<String, dynamic>>[];

      // NOTE: simple sequential hydration is clear; you can parallelize later with Future.wait
      for (final doc in snap.docs) {
        final data = {'id': doc.id, ...?doc.data()};
        final orderId = (data['orderId'] ?? data['order']?['id'])?.toString();

        // attach order (best-effort)
        if (orderId != null && orderId.isNotEmpty) {
          try {
            final o = await _db.doc('orders/$orderId').get();
            data['order'] = {'id': orderId, ...?o.data()};
          } catch (_) {
            data['order'] = {'id': orderId};
          }
        } else {
          data['order'] = data['order'] ?? {};
        }

        // --- NEW: pull expectedStartDate from delivery.items and expose at root ---
        final expectedStart = _extractExpectedStartDateFromItems(data['items']);
        if (expectedStart != null) {
          data['expectedStartDate'] = expectedStart; // int (ms since epoch)
        }
        // --- END NEW ---

        // merge histories (order.deliveryHistory + delivery.history)
        List<Map<String, dynamic>> canon(dynamic arr) {
          if (arr is! List) return const <Map<String, dynamic>>[];
          return arr.map<Map<String, dynamic>>((h) {
            final m = (h is Map) ? h : <String, dynamic>{};
            return {
              'stage': (m['stage'] ?? m['name'] ?? m['note'] ?? '').toString(),
              'at': m['at'] ?? m['createdAt'] ?? m['timestamp'],
              'by': (m['by'] ?? m['byId'] ?? m['createdBy'] ?? '').toString(),
              'note': (m['note'] ?? '').toString(),
            };
          }).toList();
        }

        final merged = [
          ...canon(data['order']?['deliveryHistory']),
          ...canon(data['history']),
        ]..sort((a, b) {
            int toMs(x) {
              final v = x['at'];
              if (v is Timestamp) return v.millisecondsSinceEpoch;
              if (v is int) return v;
              if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
              return 0;
            }
            return toMs(a).compareTo(toMs(b));
          });

        data['combinedHistory'] = merged;
        out.add(data);
      }
      return out;
    });
  }

  /// Write stage to both delivery + order with a single batch (same as web)
  Future<void> updateStage({
    required String deliveryId,
    required String newStage,
    String? driverName,
    String? byUid,
  }) async {
    final ref = _db.doc('deliveries/$deliveryId');
    final before = await ref.get();
    final payload = before.data() ?? {};
    final orderId = (payload['orderId'] ?? payload['order']?['id'])?.toString();

    final entry = {
      'stage': newStage,
      'at': DateTime.now().toIso8601String(),
      'by': byUid ?? '',
      'note': 'Driver ${driverName ?? ''} set $newStage',
    };

    final batch = _db.batch();
    batch.update(ref, {
      'status': newStage,
      'history': FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': byUid ?? '',
    });

    if (orderId != null && orderId.isNotEmpty) {
      final oref = _db.doc('orders/$orderId');
      batch.update(oref, {
        'deliveryStatus': newStage,
        'deliveryHistory': FieldValue.arrayUnion([entry]),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': byUid ?? '',
      });
    }
    await batch.commit();
  }

  /// Build expected assets in this precedence:
  /// 1) delivery.items[].assignedAssets
  /// 2) else order.items[].assignedAssets
  /// 3) else delivery.expectedAssetIds
  /// Then resolve each asset doc to human assetId, skipping assets already 'out_for_rental'
  Future<List<Map<String, String>>> loadExpectedAssets(Map<String, dynamic> delivery) async {
    final order = (delivery['order'] ?? {}) as Map<String, dynamic>;
    final List dItems = (delivery['items'] is List) ? delivery['items'] : const [];
    final List oItems = (order['items'] is List) ? order['items'] : const [];

    final Map<String, String> assetDocIdToItemName = {};

    // A) delivery items
    for (final it in dItems) {
      final List arr = (it is Map && it['assignedAssets'] is List) ? it['assignedAssets'] : const [];
      for (final a in arr) {
        assetDocIdToItemName[a.toString()] = (it['name'] ?? 'Item').toString();
      }
    }

    // B) order items
    if (assetDocIdToItemName.isEmpty) {
      for (final it in oItems) {
        final List arr = (it is Map && it['assignedAssets'] is List) ? it['assignedAssets'] : const [];
        for (final a in arr) {
          assetDocIdToItemName[a.toString()] = (it['name'] ?? 'Item').toString();
        }
      }
    }

    // C) delivery.expectedAssetIds
    if (assetDocIdToItemName.isEmpty) {
      final List exp = (delivery['expectedAssetIds'] is List) ? delivery['expectedAssetIds'] : const [];
      for (final a in exp) {
        assetDocIdToItemName[a.toString()] = 'Item';
      }
    }

    if (assetDocIdToItemName.isEmpty) return const [];

    final expected = <Map<String, String>>[];
    for (final e in assetDocIdToItemName.entries) {
      try {
        final snap = await _db.doc('assets/${e.key}').get();
        if (!snap.exists) continue;
        final a = snap.data()!;
        final status = (a['status'] ?? '').toString().toLowerCase();
        if (status == 'out_for_rental') continue;
        expected.add({
          'assetDocId': e.key,
          'assetId': (a['assetId'] ?? '').toString(),
          'itemName': e.value,
        });
      } catch (_) {}
    }
    return expected;
  }
}
