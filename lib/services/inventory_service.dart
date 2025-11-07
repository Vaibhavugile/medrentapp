import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryService {
  final _db = FirebaseFirestore.instance;

  /// Mirror of web inventory.checkoutAsset
  Future<void> checkoutAsset(String assetDocId, {String note = ''}) async {
    final ref = _db.doc('assets/$assetDocId');
    final entry = {
      'type': 'checkout',
      'note': note,
      'at': DateTime.now().toIso8601String(),
    };
    await ref.update({
      'status': 'out_for_rental',
      'history': FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
