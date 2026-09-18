import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Premium Quotation Details screen.
///
/// Reads directly from a quotation map from:
/// quotations/{quotationId}
///
/// Main fields supported from the existing web quotation flow:
/// - quoNo / quotationId
/// - requirementId / requirementNumber
/// - serviceType: rental / nursing / caretaker
/// - customerName / customerPhone
/// - createdBy / createdByName / createdAt
/// - items[]
/// - discount
/// - taxes[]
/// - totals{subtotal, discountAmount, taxBreakdown, totalTax, total}
/// - notes
/// - status
/// - versions subcollection
///
/// Firestore writes are intentionally included for status changes and
/// version reverts so this screen can become the mobile operational view.
class QuotationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> quotation;

  /// Optional callback for your existing order creation screen.
  ///
  /// Pass your existing Equipment/Nursing order creation navigation here.
  final void Function(Map<String, dynamic> quotation)? onConvertToOrder;

  /// Optional callback to open the requirement detail screen.
  final VoidCallback? onOpenRequirement;

  const QuotationDetailsScreen({
    super.key,
    required this.quotation,
    this.onConvertToOrder,
    this.onOpenRequirement,
  });

  @override
  State<QuotationDetailsScreen> createState() =>
      _QuotationDetailsScreenState();
}

class _QuotationDetailsScreenState extends State<QuotationDetailsScreen> {
  // ============================================================
  // PREMIUM LIGHT PALETTE
  // ============================================================

  static const Color bg = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;

  static const Color ink = Color(0xFF111827);
  static const Color ink2 = Color(0xFF374151);
  static const Color muted = Color(0xFF6B7280);
  static const Color lightMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);

  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoSoft = Color(0xFFEEF2FF);

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF5F3FF);

  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF5);

  static const Color orange = Color(0xFFD97706);
  static const Color orangeSoft = Color(0xFFFFF7ED);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);

  Map<String, dynamic> _details = <String, dynamic>{};

  final Set<String> _collapsedSections = <String>{};

  List<Map<String, dynamic>> _versions = <Map<String, dynamic>>[];

  bool _loadingVersions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _details = Map<String, dynamic>.from(widget.quotation);
    _loadVersions();
  }

  // ============================================================
  // BASIC HELPERS
  // ============================================================

  String text(
    dynamic value, {
    String fallback = 'Not available',
  }) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    if (result.isEmpty || result == 'null') {
      return fallback;
    }

    return result;
  }

  double number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<dynamic> list(dynamic value) {
    if (value is List) {
      return List<dynamic>.from(value);
    }

    return <dynamic>[];
  }

  Map<String, dynamic> map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is Timestamp) return value.toDate();

    if (value is String) return DateTime.tryParse(value);

    if (value is num) {
      final millis = value.toInt();

      if (millis > 0) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    try {
      final dynamic timestamp = value;
      final dynamic result = timestamp.toDate();

      if (result is DateTime) {
        return result;
      }
    } catch (_) {}

    return null;
  }

  String date(dynamic value) {
    final d = parseDate(value);

    if (d == null) {
      return text(value, fallback: 'Not available');
    }

    return DateFormat('dd MMM yyyy').format(d);
  }

  String dateTime(dynamic value) {
    final d = parseDate(value);

    if (d == null) {
      return text(value, fallback: 'Not available');
    }

    return DateFormat('dd MMM yyyy, hh:mm a').format(d);
  }

  String money(dynamic value) {
    final amount = number(value);

    return '₹${NumberFormat('#,##0.00', 'en_IN').format(amount)}';
  }

  String _serviceType() {
    final service = text(
      _details['serviceType'],
      fallback: 'rental',
    ).toLowerCase();

    if (service == 'nursing') return 'Nursing';
    if (service == 'caretaker') return 'Caretaker';

    return 'Equipment Rental';
  }

  bool get _isNursing =>
      text(_details['serviceType'], fallback: 'rental').toLowerCase() ==
      'nursing';

  bool get _isCaretaker =>
      text(_details['serviceType'], fallback: 'rental').toLowerCase() ==
      'caretaker';

  String _status() {
    return text(
      _details['status'],
      fallback: 'draft',
    ).replaceAll('_', ' ');
  }

  String _statusKey() {
    return text(
      _details['status'],
      fallback: 'draft',
    ).toLowerCase();
  }

  Color _statusColor() {
    switch (_statusKey()) {
      case 'accepted':
        return green;
      case 'sent':
      case 'pending':
        return blue;
      case 'rejected':
        return red;
      case 'order_created':
      case 'order created':
        return purple;
      case 'expired':
        return orange;
      default:
        return muted;
    }
  }

  Color _statusSoft() {
    switch (_statusKey()) {
      case 'accepted':
        return greenSoft;
      case 'sent':
      case 'pending':
        return blueSoft;
      case 'rejected':
        return redSoft;
      case 'order_created':
      case 'order created':
        return purpleSoft;
      case 'expired':
        return orangeSoft;
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String _customerName() {
    return text(
      _details['customerName'],
      fallback: text(
        _details['customer'],
        fallback: 'Customer',
      ),
    );
  }

  String _customerPhone() {
    return text(
      _details['customerPhone'],
      fallback: text(
        _details['phone'],
        fallback: '',
      ),
    );
  }

  String _requirementNumber() {
    return text(
      _details['requirementNumber'],
      fallback: text(
        _details['requirementId'],
        fallback: 'Not linked',
      ),
    );
  }

  List<Map<String, dynamic>> _items() {
    return list(_details['items'])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _taxes() {
    return list(_details['taxes'])
        .whereType<Map>()
        .map((tax) => Map<String, dynamic>.from(tax))
        .toList();
  }

  Map<String, dynamic> _totals() {
    return map(_details['totals']);
  }

  double _subtotal() {
    final totals = _totals();

    final explicit = totals['subtotal'];

    if (explicit != null) return number(explicit);

    return _items().fold<double>(
      0,
      (sum, item) {
        final amount = item['amount'];

        if (amount != null) {
          return sum + number(amount);
        }

        return sum +
            (number(item['qty'] ?? item['quantity']) *
                number(item['rate']));
      },
    );
  }

  double _discountAmount() {
    final totals = _totals();

    if (totals['discountAmount'] != null) {
      return number(totals['discountAmount']);
    }

    final discount = map(_details['discount']);

    final value = number(discount['value']);

    if (text(discount['type']).toLowerCase() == 'percent') {
      return _subtotal() * value / 100;
    }

    return value;
  }

  double _taxTotal() {
    final totals = _totals();

    if (totals['totalTax'] != null) {
      return number(totals['totalTax']);
    }

    return _taxes().fold<double>(
      0,
      (sum, tax) => sum + number(tax['amount']),
    );
  }

  double _grandTotal() {
    final totals = _totals();

    if (totals['total'] != null) {
      return number(totals['total']);
    }

    return (_subtotal() - _discountAmount()).clamp(0, double.infinity) +
        _taxTotal();
  }

  // ============================================================
  // FIRESTORE VERSIONS
  // ============================================================

  Future<void> _loadVersions() async {
    final quotationId = text(_details['id'], fallback: '');

    if (quotationId.isEmpty) {
      if (mounted) {
        setState(() => _loadingVersions = false);
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('quotations')
          .doc(quotationId)
          .collection('versions')
          .orderBy('createdAt', descending: true)
          .get();

      final versions = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());

        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _versions = versions;
        _loadingVersions = false;
      });
    } catch (e) {
      debugPrint('Quotation versions error: $e');

      if (!mounted) return;

      setState(() {
        _versions = <Map<String, dynamic>>[];
        _loadingVersions = false;
      });
    }
  }

  Future<void> _updateStatus(
    String newStatus,
    String note,
  ) async {
    final quotationId = text(_details['id'], fallback: '');

    if (quotationId.isEmpty || _statusKey() == newStatus) {
      return;
    }

    setState(() => _saving = true);

    try {
      final user = FirebaseFirestore.instance;
      final authUser = await _currentUserData();

      await user.collection('quotations').doc(quotationId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': authUser['uid'] ?? '',
        'updatedByName': authUser['name'] ?? '',
      });

      if (newStatus == 'accepted' &&
          text(_details['requirementId'], fallback: '').isNotEmpty) {
        await _updateRequirementStatus(
          'order_created',
          'Quotation ${text(_details['quoNo'], fallback: quotationId)} accepted.',
        );
      }

      if (mounted) {
        setState(() {
          _details = <String, dynamic>{
            ..._details,
            'status': newStatus,
            'updatedBy': authUser['uid'] ?? '',
            'updatedByName': authUser['name'] ?? '',
            'updatedAt': DateTime.now(),
          };
        });

        _showSnack(
          'Quotation marked ${newStatus.replaceAll('_', ' ')}.',
          green,
        );
      }
    } catch (e) {
      _showSnack(
        'Failed to update quotation: $e',
        red,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _updateRequirementStatus(
    String status,
    String note,
  ) async {
    final requirementId = text(
      _details['requirementId'],
      fallback: '',
    );

    if (requirementId.isEmpty) return;

    try {
      final user = await _currentUserData();

      await FirebaseFirestore.instance
          .collection('requirements')
          .doc(requirementId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user['uid'] ?? '',
        'updatedByName': user['name'] ?? '',
        'history': FieldValue.arrayUnion([
          {
            'type': 'quotation',
            'field': 'status',
            'oldValue': _status(),
            'newValue': status,
            'note': note,
            'changedBy': user['uid'] ?? '',
            'changedByName': user['name'] ?? '',
            'ts': Timestamp.now(),
          },
        ]),
      });
    } catch (e) {
      debugPrint('Requirement status update error: $e');
    }
  }

  Future<Map<String, String>> _currentUserData() async {
    // Avoid depending on FirebaseAuth here; use the quotation's current
    // updater if no auth package is configured in this file.
    return <String, String>{
      'uid': text(
        _details['updatedBy'],
        fallback: _details['createdBy']?.toString() ?? '',
      ),
      'name': text(
        _details['updatedByName'],
        fallback: _details['createdByName']?.toString() ?? 'Mobile User',
      ),
    };
  }

  Future<void> _revertVersion(
    Map<String, dynamic> version,
  ) async {
    final quotationId = text(_details['id'], fallback: '');

    if (quotationId.isEmpty) return;

    final snapshot = map(version['snapshot']);

    if (snapshot.isEmpty) {
      _showSnack(
        'This version does not contain a quotation snapshot.',
        orange,
      );
      return;
    }

    final shouldRevert = await _confirm(
      title: 'Revert quotation?',
      message:
          'The current quotation will be replaced by this saved version. '
          'A snapshot of the current quotation will be retained first.',
      confirmText: 'Revert',
      color: purple,
    );

    if (!shouldRevert) return;

    setState(() => _saving = true);

    try {
      final quotationRef = FirebaseFirestore.instance
          .collection('quotations')
          .doc(quotationId);

      await quotationRef.collection('versions').add({
        'snapshot': _details,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': text(_details['updatedBy']),
        'createdByName': text(_details['updatedByName']),
        'note': 'Snapshot before mobile revert to ${version['id']}',
      });

      final items = list(snapshot['items']);
      final discount = map(snapshot['discount']);
      final taxes = list(snapshot['taxes']);

      final amounts = _calculateAmounts(
        items,
        discount,
        taxes,
      );

      final payload = <String, dynamic>{
        'quoNo': snapshot['quoNo'],
        'quotationId': snapshot['quotationId'],
        'items': items,
        'discount': discount,
        'taxes': amounts['taxBreakdown'],
        'notes': snapshot['notes'] ?? '',
        'totals': {
          'subtotal': amounts['subtotal'],
          'discountAmount': amounts['discountAmount'],
          'taxBreakdown': amounts['taxBreakdown'],
          'totalTax': amounts['totalTax'],
          'total': amounts['total'],
        },
        'status': snapshot['status'] ?? 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': text(_details['updatedBy']),
        'updatedByName': text(_details['updatedByName']),
      };

      await quotationRef.update(payload);

      if (mounted) {
        setState(() {
          _details = <String, dynamic>{
            ..._details,
            ...payload,
            'updatedAt': DateTime.now(),
          };
        });

        _showSnack(
          'Quotation reverted successfully.',
          purple,
        );
      }

      await _loadVersions();
    } catch (e) {
      _showSnack(
        'Failed to revert quotation: $e',
        red,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Map<String, dynamic> _calculateAmounts(
    List<dynamic> items,
    Map<String, dynamic> discount,
    List<dynamic> taxes,
  ) {
    double subtotal = 0;

    for (final raw in items) {
      final item = map(raw);

      final amount = item['amount'];

      if (amount != null) {
        subtotal += number(amount);
      } else {
        subtotal += number(item['qty'] ?? item['quantity']) *
            number(item['rate']);
      }
    }

    double discountAmount = 0;

    final discountType = text(
      discount['type'],
      fallback: 'percent',
    ).toLowerCase();

    final discountValue = number(discount['value']);

    if (discountType == 'percent') {
      discountAmount = subtotal * discountValue / 100;
    } else {
      discountAmount = discountValue;
    }

    final taxable = (subtotal - discountAmount).clamp(0, double.infinity);

    final breakdown = <Map<String, dynamic>>[];

    for (final raw in taxes) {
      final tax = map(raw);

      final type = text(
        tax['type'],
        fallback: 'percent',
      ).toLowerCase();

      final value = number(
        tax['value'] ?? tax['rate'],
      );

      final amount = type == 'fixed'
          ? value
          : taxable * value / 100;

      breakdown.add({
        ...tax,
        'value': value,
        'amount': double.parse(amount.toStringAsFixed(2)),
        'locked': true,
      });
    }

    final totalTax = breakdown.fold<double>(
      0,
      (sum, tax) => sum + number(tax['amount']),
    );

    final total = taxable + totalTax;

    return {
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxBreakdown': breakdown,
      'totalTax': totalTax,
      'total': total,
    };
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  void _toggle(String key) {
    setState(() {
      if (_collapsedSections.contains(key)) {
        _collapsedSections.remove(key);
      } else {
        _collapsedSections.add(key);
      }
    });
  }

  void _showSnack(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                color == red
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Widget _section({
    required String key,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final collapsed = _collapsedSections.contains(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggle(key),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 13, 16),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.09),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 7),
                    trailing,
                  ],
                  const SizedBox(width: 3),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: muted,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Color color = blue,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: lightMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: ink2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 570;

        if (!wide) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.0,
          children: children,
        );
      },
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    final quotationNo = text(
      _details['quoNo'],
      fallback: text(
        _details['quotationId'],
        fallback: text(_details['id'], fallback: 'Quotation'),
      ),
    );

    final statusColor = _statusColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF172554),
            Color(0xFF1D4ED8),
            Color(0xFF2563EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: blue.withOpacity(.20),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(.12),
                  ),
                ),
                child: const Icon(
                  Icons.request_quote_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quotation Details',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      quotationNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(
                _status(),
                statusColor,
                hero: true,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(.09),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _heroMetric(
                    Icons.person_rounded,
                    _customerName(),
                    'Customer',
                  ),
                ),
                _heroDivider(),
                Expanded(
                  child: _heroMetric(
                    Icons.category_rounded,
                    _serviceType(),
                    'Service',
                  ),
                ),
                _heroDivider(),
                Expanded(
                  child: _heroMetric(
                    Icons.payments_rounded,
                    money(_grandTotal()),
                    'Final Total',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(.78),
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 31,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(.12),
    );
  }

  Widget _statusPill(
    String value,
    Color color, {
    bool hero = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: hero ? Colors.white.withOpacity(.13) : color.withOpacity(.09),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: hero
              ? Colors.white.withOpacity(.14)
              : color.withOpacity(.14),
        ),
      ),
      child: Text(
        value.toUpperCase(),
        style: TextStyle(
          color: hero ? Colors.white : color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOMER
  // ============================================================

  Widget _customerSection() {
    return _section(
      key: 'customer',
      icon: Icons.person_outline_rounded,
      color: blue,
      title: 'Customer Information',
      subtitle: 'Customer and contact details for this quotation',
      child: _grid([
        _infoTile(
          icon: Icons.person_rounded,
          label: 'Customer',
          value: _customerName(),
          color: blue,
        ),
        _infoTile(
          icon: Icons.phone_outlined,
          label: 'Mobile',
          value: text(
            _customerPhone(),
            fallback: 'Not available',
          ),
          color: blue,
        ),
        _infoTile(
          icon: Icons.link_rounded,
          label: 'Requirement',
          value: _requirementNumber(),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.category_outlined,
          label: 'Service',
          value: _serviceType(),
          color: blue,
        ),
      ]),
    );
  }

  // ============================================================
  // QUOTATION META
  // ============================================================

  Widget _metaSection() {
    return _section(
      key: 'meta',
      icon: Icons.description_outlined,
      color: indigo,
      title: 'Quotation Information',
      subtitle: 'Reference, ownership, status and timestamps',
      child: _grid([
        _infoTile(
          icon: Icons.tag_rounded,
          label: 'Quotation No.',
          value: text(
            _details['quoNo'],
            fallback: text(_details['quotationId']),
          ),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.assignment_outlined,
          label: 'Requirement No.',
          value: _requirementNumber(),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.info_outline_rounded,
          label: 'Status',
          value: _status(),
          color: _statusColor(),
        ),
        _infoTile(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Created By',
          value: text(
            _details['createdByName'],
            fallback: text(_details['createdBy']),
          ),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.calendar_today_outlined,
          label: 'Created',
          value: dateTime(_details['createdAt']),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.update_rounded,
          label: 'Last Updated',
          value: dateTime(_details['updatedAt']),
          color: indigo,
        ),
      ]),
    );
  }

  // ============================================================
  // ITEMS
  // ============================================================

  Widget _itemsSection() {
    final items = _items();

    return _section(
      key: 'items',
      icon: Icons.shopping_bag_outlined,
      color: blue,
      title: 'Quotation Items',
      subtitle:
          '${items.length} item${items.length == 1 ? '' : 's'} included in this quotation',
      trailing: _countBadge(items.length, blue),
      child: items.isEmpty
          ? _emptyInside(
              Icons.shopping_bag_outlined,
              'No quotation items available',
            )
          : Column(
              children: items.asMap().entries.map(
                (entry) {
                  return _itemCard(
                    entry.key,
                    entry.value,
                  );
                },
              ).toList(),
            ),
    );
  }

  Widget _itemCard(
    int index,
    Map<String, dynamic> item,
  ) {
    final name = text(
      item['name'],
      fallback: text(
        item['itemName'],
        fallback: text(
          item['productName'],
          fallback: text(
            item['productId'],
            fallback: 'Quotation Item',
          ),
        ),
      ),
    );

    final qty = number(
      item['qty'] ?? item['quantity'],
    );

    final rate = number(item['rate']);

    final amount = item['amount'] != null
        ? number(item['amount'])
        : qty * rate;

    final days = text(
      item['days'],
      fallback: '',
    );

    final productId = text(
      item['productId'],
      fallback: '',
    );

    final notes = text(
      item['notes'],
      fallback: '',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: blue,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                    if (productId.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Product ID: $productId',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: lightMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                money(amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _grid([
            _infoTile(
              icon: Icons.numbers_rounded,
              label: 'Quantity',
              value: qty == qty.roundToDouble()
                  ? qty.toInt().toString()
                  : qty.toStringAsFixed(2),
              color: blue,
            ),
            _infoTile(
              icon: Icons.currency_rupee_rounded,
              label: 'Rate',
              value: money(rate),
              color: blue,
            ),
            _infoTile(
              icon: Icons.timelapse_outlined,
              label: 'Days',
              value: days.isEmpty ? 'Not specified' : days,
              color: blue,
            ),
            _infoTile(
              icon: Icons.event_available_outlined,
              label: 'Start Date',
              value: date(item['expectedStartDate']),
              color: blue,
            ),
            _infoTile(
              icon: Icons.event_busy_outlined,
              label: 'End Date',
              value: date(item['expectedEndDate']),
              color: blue,
            ),
            _infoTile(
              icon: Icons.payments_outlined,
              label: 'Amount',
              value: money(amount),
              color: green,
            ),
          ]),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _notesBox(
              title: 'Item Notes',
              value: notes,
              color: blue,
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // PRICE SUMMARY
  // ============================================================

  Widget _pricingSection() {
    final discount = map(_details['discount']);

    return _section(
      key: 'pricing',
      icon: Icons.calculate_outlined,
      color: green,
      title: 'Price Summary',
      subtitle: 'Subtotal, discount, applicable taxes and final amount',
      child: Column(
        children: [
          _amountRow(
            'Subtotal',
            _subtotal(),
            color: ink2,
          ),
          const SizedBox(height: 9),
          _amountRow(
            'Discount',
            _discountAmount(),
            color: red,
            prefix: '-',
            suffix: text(
              discount['type'],
              fallback: '',
            ).isNotEmpty
                ? '  (${text(discount['value'])}${text(discount['type']).toLowerCase() == 'percent' ? '%' : ''})'
                : '',
          ),
          const SizedBox(height: 9),
          _amountRow(
            'Tax',
            _taxTotal(),
            color: orange,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: border,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFECFDF5),
                  Color(0xFFF0FDFA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: green.withOpacity(.14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: green.withOpacity(.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Final Quotation Amount',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Total payable amount',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ink2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  money(_grandTotal()),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: green,
                  ),
                ),
              ],
            ),
          ),
          if (_taxes().isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tax Breakdown',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._taxes().map(
              (tax) => _taxRow(tax),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountRow(
    String label,
    double value, {
    required Color color,
    String prefix = '',
    String suffix = '',
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ),
        Text(
          '$prefix${money(value)}$suffix',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _taxRow(Map<String, dynamic> tax) {
    final name = text(
      tax['name'],
      fallback: text(
        tax['label'],
        fallback: 'Tax',
      ),
    );

    final amount = number(tax['amount']);

    final type = text(
      tax['type'],
      fallback: 'percent',
    ).toLowerCase();

    final value = number(
      tax['value'] ?? tax['rate'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 17,
            color: orange,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: ink2,
              ),
            ),
          ),
          Text(
            type == 'fixed'
                ? money(value)
                : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}%',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            money(amount),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: orange,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTES
  // ============================================================

  Widget _notesSection() {
    final notes = text(
      _details['notes'],
      fallback: '',
    );

    return _section(
      key: 'notes',
      icon: Icons.notes_rounded,
      color: purple,
      title: 'Terms & Notes',
      subtitle: 'Quotation notes and additional information',
      child: notes.isEmpty
          ? _emptyInside(
              Icons.notes_outlined,
              'No notes have been added.',
            )
          : _notesBox(
              title: 'Quotation Notes',
              value: notes,
              color: purple,
            ),
    );
  }

  Widget _notesBox({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.045),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: color.withOpacity(.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.subject_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: ink2,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS TIMELINE
  // ============================================================

  Widget _statusSection() {
    final current = _statusKey();

    const steps = <String>[
      'draft',
      'sent',
      'accepted',
      'order_created',
    ];

    int active = 0;

    if (current == 'sent' || current == 'pending') {
      active = 1;
    } else if (current == 'accepted') {
      active = 2;
    } else if (current == 'order_created' ||
        current == 'order created') {
      active = 3;
    }

    final rejected = current == 'rejected';
    final expired = current == 'expired';

    return _section(
      key: 'status',
      icon: Icons.timeline_rounded,
      color: _statusColor(),
      title: 'Quotation Lifecycle',
      subtitle: 'Track the quotation from draft to order',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _statusSoft(),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _statusColor().withOpacity(.13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rejected
                        ? Icons.cancel_outlined
                        : expired
                            ? Icons.timer_off_outlined
                            : Icons.flag_rounded,
                    color: _statusColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _status(),
                        style: TextStyle(
                          fontSize: 15,
                          color: _statusColor(),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (rejected || expired) ...[
            const SizedBox(height: 13),
            _specialStatusMessage(
              rejected ? 'Quotation rejected' : 'Quotation expired',
              rejected ? red : orange,
            ),
          ],
          if (!rejected && !expired) ...[
            const SizedBox(height: 18),
            ...steps.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final label = entry.value;
                final done = index <= active;
                final last = index == steps.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: done
                                ? _statusColor()
                                : const Color(0xFFF1F3F5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            done
                                ? Icons.check_rounded
                                : Icons.circle_outlined,
                            color: done
                                ? Colors.white
                                : lightMuted,
                            size: 16,
                          ),
                        ),
                        if (!last)
                          Container(
                            width: 2,
                            height: 34,
                            color: index < active
                                ? _statusColor().withOpacity(.35)
                                : border,
                          ),
                      ],
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          label.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                done ? FontWeight.w900 : FontWeight.w600,
                            color: done ? ink : muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _specialStatusMessage(
    String title,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VERSION HISTORY
  // ============================================================

  Widget _versionsSection() {
    return _section(
      key: 'versions',
      icon: Icons.history_rounded,
      color: purple,
      title: 'Revision History',
      subtitle:
          _loadingVersions
              ? 'Loading saved quotation revisions…'
              : '${_versions.length} saved revision${_versions.length == 1 ? '' : 's'}',
      trailing: _loadingVersions
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: purple,
              ),
            )
          : _countBadge(
              _versions.length,
              purple,
            ),
      child: _loadingVersions
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: purple,
                ),
              ),
            )
          : _versions.isEmpty
              ? _emptyInside(
                  Icons.history_rounded,
                  'No quotation revisions have been saved yet.',
                )
              : Column(
                  children: _versions.asMap().entries.map(
                    (entry) {
                      return _versionCard(
                        entry.key,
                        entry.value,
                      );
                    },
                  ).toList(),
                ),
    );
  }

  Widget _versionCard(
    int index,
    Map<String, dynamic> version,
  ) {
    final snapshot = map(version['snapshot']);

    final versionNo = _versions.length - index;

    final status = text(
      snapshot['status'],
      fallback: 'draft',
    );

    final total = number(
      map(snapshot['totals'])['total'],
    );

    final by = text(
      version['createdByName'],
      fallback: text(
        version['createdBy'],
        fallback: 'System',
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: purpleSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                'V$versionNo',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: purple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text(
                          snapshot['quoNo'],
                          fallback: 'Quotation Revision',
                        ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                    ),
                    _statusPill(
                      status.replaceAll('_', ' '),
                      status == 'accepted'
                          ? green
                          : status == 'rejected'
                              ? red
                              : purple,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '$by  •  ${dateTime(version['createdAt'])}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: lightMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ${money(total)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          PopupMenuButton<String>(
            tooltip: 'Revision actions',
            onSelected: (value) {
              if (value == 'view') {
                _showVersion(version, versionNo);
              } else if (value == 'revert') {
                _revertVersion(version);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'view',
                child: Text('View Revision'),
              ),
              PopupMenuItem(
                value: 'revert',
                child: Text('Revert to Revision'),
              ),
            ],
            child: const Icon(
              Icons.more_vert_rounded,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVersion(
    Map<String, dynamic> version,
    int versionNo,
  ) async {
    final snapshot = map(version['snapshot']);

    if (snapshot.isEmpty) {
      _showSnack(
        'No snapshot found for this revision.',
        orange,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * .84,
          decoration: const BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 10, 14),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: purpleSoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revision V$versionNo',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            text(
                              version['note'],
                              fallback: 'Saved quotation revision',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                color: border,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _snapshotTile(
                      'Quotation',
                      text(
                        snapshot['quoNo'],
                        fallback: text(snapshot['quotationId']),
                      ),
                    ),
                    _snapshotTile(
                      'Status',
                      text(snapshot['status']),
                    ),
                    _snapshotTile(
                      'Customer',
                      text(snapshot['customerName']),
                    ),
                    _snapshotTile(
                      'Items',
                      '${list(snapshot['items']).length}',
                    ),
                    _snapshotTile(
                      'Total',
                      money(map(snapshot['totals'])['total']),
                    ),
                    if (text(snapshot['notes'], fallback: '').isNotEmpty)
                      _notesBox(
                        title: 'Notes',
                        value: text(snapshot['notes']),
                        color: purple,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _snapshotTile(
    String label,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _actionsSection() {
    final status = _statusKey();

    return _section(
      key: 'actions',
      icon: Icons.bolt_rounded,
      color: blue,
      title: 'Quotation Actions',
      subtitle: 'Available operational actions for this quotation',
      child: Column(
        children: [
          if (status == 'draft')
            _actionButton(
              icon: Icons.send_rounded,
              title: 'Mark as Sent',
              subtitle: 'Move the quotation to customer review',
              color: blue,
              onPressed: _saving
                  ? null
                  : () => _updateStatus(
                        'sent',
                        'Quotation sent to customer.',
                      ),
            ),
          if (status == 'sent' || status == 'pending') ...[
            _actionButton(
              icon: Icons.check_circle_outline_rounded,
              title: 'Accept Quotation',
              subtitle: 'Record customer acceptance',
              color: green,
              onPressed: _saving
                  ? null
                  : () => _updateStatus(
                        'accepted',
                        'Accepted by customer.',
                      ),
            ),
            const SizedBox(height: 9),
            _actionButton(
              icon: Icons.cancel_outlined,
              title: 'Reject Quotation',
              subtitle: 'Record customer rejection',
              color: red,
              onPressed: _saving
                  ? null
                  : () => _updateStatus(
                        'rejected',
                        'Rejected by customer.',
                      ),
            ),
          ],
          if (status == 'accepted' && _details['orderId'] == null)
            ...[
              if (status == 'accepted') const SizedBox(height: 9),
              _actionButton(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Convert to Order',
                subtitle:
                    'Create the operational order from this accepted quotation',
                color: purple,
                onPressed: _saving || widget.onConvertToOrder == null
                    ? null
                    : () => widget.onConvertToOrder!(
                          Map<String, dynamic>.from(_details),
                        ),
              ),
            ],
          if (status == 'accepted' &&
              text(_details['orderId'], fallback: '').isNotEmpty)
            _actionButton(
              icon: Icons.check_circle_rounded,
              title: 'Order Created',
              subtitle:
                  'Order ID: ${text(_details['orderId'])}',
              color: purple,
              onPressed: null,
            ),
          if (widget.onOpenRequirement != null) ...[
            const SizedBox(height: 9),
            _actionButton(
              icon: Icons.assignment_outlined,
              title: 'Open Requirement',
              subtitle:
                  'View the original customer requirement',
              color: indigo,
              onPressed: widget.onOpenRequirement,
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: disabled
                ? const Color(0xFFFAFBFC)
                : color.withOpacity(.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: disabled
                  ? border
                  : color.withOpacity(.13),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: disabled
                      ? const Color(0xFFF1F3F5)
                      : color.withOpacity(.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: disabled ? lightMuted : color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: disabled ? muted : ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WHATSAPP
  // ============================================================

  Future<void> _openWhatsApp() async {
    final phone = _normalizePhone(_customerPhone());

    if (phone.isEmpty) {
      _showSnack(
        'Customer WhatsApp number is not available.',
        orange,
      );
      return;
    }

    final quotationNo = text(
      _details['quoNo'],
      fallback: text(_details['quotationId']),
    );

    final message = 'Hello ${_customerName()},\n\n'
        'Sharing quotation $quotationNo.\n'
        'Service: ${_serviceType()}\n'
        'Total: ${money(_grandTotal())}\n\n'
        'Thank you.';

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        _showSnack(
          'Unable to open WhatsApp.',
          red,
        );
      }
    } catch (e) {
      _showSnack(
        'Unable to open WhatsApp: $e',
        red,
      );
    }
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length == 10) {
      return '91$digits';
    }

    return digits;
  }

  Widget _shareSection() {
    return _section(
      key: 'share',
      icon: Icons.share_outlined,
      color: green,
      title: 'Share Quotation',
      subtitle: 'Quickly send quotation information to the customer',
      child: _actionButton(
        icon: Icons.chat_rounded,
        title: 'Open WhatsApp',
        subtitle: 'Create a WhatsApp message with quotation summary',
        color: green,
        onPressed: _customerPhone().isEmpty ? null : _openWhatsApp,
      ),
    );
  }

  // ============================================================
  // SMALL UI
  // ============================================================

  Widget _countBadge(
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _emptyInside(
    IconData icon,
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 27,
            color: lightMuted,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: ink,
          ),
        ),
        title: const Text(
          'Quotation Details',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh revisions',
            onPressed: _saving
                ? null
                : () {
                    setState(() {});
                    _loadVersions();
                  },
            icon: const Icon(
              Icons.refresh_rounded,
              color: ink2,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _hero(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _customerSection(),
                _metaSection(),
                _itemsSection(),
                _pricingSection(),
                _notesSection(),
                _statusSection(),
                _versionsSection(),
                _actionsSection(),
                _shareSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
