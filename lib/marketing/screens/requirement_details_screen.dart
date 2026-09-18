import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Premium read-only Requirement Details screen.
///
/// Usage:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => RequirementDetailsScreen(
///       requirement: requirementMap,
///     ),
///   ),
/// );
///
/// The [requirement] map can come directly from:
/// requirements/{requirementId}
class RequirementDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> requirement;

  /// Optional callback for the future quotation screen.
  /// Keep this null until quotation_details_screen.dart is connected.
  final VoidCallback? onCreateQuotation;

  const RequirementDetailsScreen({
    super.key,
    required this.requirement,
    this.onCreateQuotation,
  });

  @override
  State<RequirementDetailsScreen> createState() =>
      _RequirementDetailsScreenState();
}

class _RequirementDetailsScreenState extends State<RequirementDetailsScreen> {
  static const Color bg = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;

  static const Color ink = Color(0xFF111827);
  static const Color ink2 = Color(0xFF374151);
  static const Color muted = Color(0xFF6B7280);
  static const Color lightMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);

  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoSoft = Color(0xFFEEF2FF);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);

  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF5);

  static const Color orange = Color(0xFFD97706);
  static const Color orangeSoft = Color(0xFFFFF7ED);

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF5F3FF);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);

  final Set<String> _collapsedSections = <String>{};
  bool _updating = false;

  Map<String, dynamic> get requirement => widget.requirement;

  String text(dynamic value, {String fallback = 'Not available'}) {
    if (value == null) return fallback;

    final valueText = value.toString().trim();

    if (valueText.isEmpty || valueText == 'null') {
      return fallback;
    }

    return valueText;
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
      final dynamic converted = timestamp.toDate();
      if (converted is DateTime) return converted;
    } catch (_) {}

    return null;
  }

  String date(dynamic value) {
    final parsed = parseDate(value);
    if (parsed == null) return text(value, fallback: 'Not available');
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  String dateTime(dynamic value) {
    final parsed = parseDate(value);
    if (parsed == null) return text(value, fallback: 'Not available');
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
  }

  String money(dynamic value) {
    final amount = number(value);
    return '₹${NumberFormat('#,##0.00', 'en_IN').format(amount)}';
  }

  String _serviceType() {
    final type = text(
      requirement['serviceType'],
      fallback: 'rental',
    ).toLowerCase();

    if (type == 'nursing') return 'Nursing';
    if (type == 'caretaker') return 'Caretaker';
    return 'Equipment Rental';
  }

  bool get _isNursing =>
      text(requirement['serviceType'], fallback: 'rental').toLowerCase() ==
      'nursing';

  bool get _isCaretaker =>
      text(requirement['serviceType'], fallback: 'rental').toLowerCase() ==
      'caretaker';

  bool get _isCareService => _isNursing || _isCaretaker;

  String _status() {
    final status = text(requirement['status'], fallback: 'Draft');
    return status.replaceAll('_', ' ');
  }

  Color _statusColor() {
    final status = _status().toLowerCase();

    if (status.contains('quotation shared')) return purple;
    if (status.contains('order created')) return green;
    if (status.contains('ready')) return blue;
    if (status.contains('cancel') || status.contains('reject')) return red;
    if (status.contains('pending')) return orange;

    return indigo;
  }

  Color _statusSoftColor() {
    final status = _status().toLowerCase();

    if (status.contains('quotation shared')) return purpleSoft;
    if (status.contains('order created')) return greenSoft;
    if (status.contains('ready')) return blueSoft;
    if (status.contains('cancel') || status.contains('reject')) return redSoft;
    if (status.contains('pending')) return orangeSoft;

    return indigoSoft;
  }

  String _customerName() {
    final lead = map(
      requirement['leadSnapshot'] ?? requirement['leadssnapshop'],
    );

    final delivery = map(requirement['deliveryContact']);

    return text(
      requirement['customerName'] ??
          requirement['name'] ??
          delivery['name'],
      fallback: text(
        lead['customerName'],
        fallback: text(
          requirement['contactPerson'],
          fallback: 'Customer',
        ),
      ),
    );
  }

  String _contactName() {
    final lead = map(
      requirement['leadSnapshot'] ?? requirement['leadssnapshop'],
    );

    return text(
      requirement['contactPerson'],
      fallback: text(
        lead['contactPerson'],
        fallback: text(
          requirement['name'],
          fallback: 'Not available',
        ),
      ),
    );
  }

  String _phone() {
    final lead = map(
      requirement['leadSnapshot'] ?? requirement['leadssnapshop'],
    );

    return text(
      requirement['phone'],
      fallback: text(
        requirement['customerPhone'],
        fallback: text(
          requirement['contactPhone'],
          fallback: text(
            lead['phone'],
            fallback: text(lead['mobile']),
          ),
        ),
      ),
    );
  }

  String _email() {
    final lead = map(
      requirement['leadSnapshot'] ?? requirement['leadssnapshop'],
    );

    return text(
      requirement['email'],
      fallback: text(
        requirement['customerEmail'],
        fallback: text(lead['email']),
      ),
    );
  }

  String _address() {
    final delivery = map(requirement['deliveryContact']);

    return text(
      requirement['deliveryAddress'],
      fallback: text(
        requirement['address'],
        fallback: text(
          requirement['deliveryCity'],
          fallback: text(
            delivery['address'],
            fallback: delivery['city']?.toString() ?? 'Not available',
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _equipmentItems() {
    final raw = requirement['equipment'] ?? requirement['requirementItems'];

    return list(raw)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _nursingServices() {
    final raw = requirement['nursing'];

    if (raw is Map) {
      return <Map<String, dynamic>>[Map<String, dynamic>.from(raw)];
    }

    return list(raw)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _history() {
    return list(requirement['history'])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
        .reversed
        .toList();
  }

  bool _hasQuotation() {
    final status = text(requirement['status']).toLowerCase();
    return status == 'quotation shared' || status == 'order_created';
  }

  void _toggle(String key) {
    setState(() {
      if (_collapsedSections.contains(key)) {
        _collapsedSections.remove(key);
      } else {
        _collapsedSections.add(key);
      }
    });
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
                    child: Icon(icon, color: color, size: 21),
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
                    const SizedBox(width: 8),
                    trailing,
                  ],
                  const SizedBox(width: 4),
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
    Color color = indigo,
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
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 11),
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
                    fontSize: 13,
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

  Widget _twoColumnInfo(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
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
          childAspectRatio: 2.9,
          children: children,
        );
      },
    );
  }

  Widget _serviceBadge() {
    final Color color = _isNursing
        ? green
        : _isCaretaker
            ? orange
            : blue;

    final Color soft = _isNursing
        ? greenSoft
        : _isCaretaker
            ? orangeSoft
            : blueSoft;

    final IconData icon = _isNursing
        ? Icons.medical_services_rounded
        : _isCaretaker
            ? Icons.volunteer_activism_rounded
            : Icons.inventory_2_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            _serviceType(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    final reqNo = text(
      requirement['requirementNumber'] ??
          requirement['requirementId'] ??
          requirement['id'],
      fallback: 'Requirement',
    );

    final statusColor = _statusColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF312E81),
            Color(0xFF4F46E5),
            Color(0xFF6366F1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: indigo.withOpacity(.20),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(.13),
                  ),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Requirement Details',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reqNo,
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
              _heroStatus(statusColor),
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
                    Icons.calendar_month_rounded,
                    date(requirement['createdAt']),
                    'Created',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStatus(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withOpacity(.14),
        ),
      ),
      child: Text(
        _status().toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
        ),
      ),
    );
  }

  Widget _heroMetric(IconData icon, String value, String label) {
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

  Widget _customerSection() {
    return _section(
      key: 'customer',
      icon: Icons.person_outline_rounded,
      color: blue,
      title: 'Customer Information',
      subtitle: 'Customer and contact information linked to this requirement',
      child: _twoColumnInfo([
        _infoTile(
          icon: Icons.person_rounded,
          label: 'Customer',
          value: _customerName(),
          color: blue,
        ),
        _infoTile(
          icon: Icons.badge_outlined,
          label: 'Contact Person',
          value: _contactName(),
          color: blue,
        ),
        _infoTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: _phone(),
          color: blue,
        ),
        _infoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: _email(),
          color: blue,
        ),
        _infoTile(
          icon: Icons.location_on_outlined,
          label: 'Delivery Address',
          value: _address(),
          color: blue,
        ),
        _infoTile(
          icon: Icons.link_rounded,
          label: 'Lead Reference',
          value: text(
            requirement['leadId'],
            fallback: 'Not linked',
          ),
          color: indigo,
        ),
      ]),
    );
  }

  Widget _requirementInfoSection() {
    final urgency = text(
      requirement['urgency'],
      fallback: 'normal',
    );

    return _section(
      key: 'information',
      icon: Icons.info_outline_rounded,
      color: indigo,
      title: 'Requirement Information',
      subtitle: 'Core requirement identifiers, ownership and timing',
      child: _twoColumnInfo([
        _infoTile(
          icon: Icons.tag_rounded,
          label: 'Requirement No.',
          value: text(
            requirement['requirementNumber'] ??
                requirement['requirementId'] ??
                requirement['id'],
          ),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.category_outlined,
          label: 'Service Type',
          value: _serviceType(),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.priority_high_rounded,
          label: 'Urgency',
          value: urgency,
          color: urgency.toLowerCase() == 'high' ? red : orange,
        ),
        _infoTile(
          icon: Icons.person_pin_outlined,
          label: 'Assigned To',
          value: text(
            requirement['assignedToName'] ?? requirement['assignedTo'],
            fallback: 'Unassigned',
          ),
          color: purple,
        ),
        _infoTile(
          icon: Icons.calendar_today_outlined,
          label: 'Created',
          value: dateTime(requirement['createdAt']),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.edit_calendar_outlined,
          label: 'Last Updated',
          value: dateTime(requirement['updatedAt']),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Created By',
          value: text(
            requirement['createdByName'] ?? requirement['createdBy'],
          ),
          color: indigo,
        ),
        _infoTile(
          icon: Icons.update_rounded,
          label: 'Updated By',
          value: text(
            requirement['updatedByName'] ?? requirement['updatedBy'],
          ),
          color: indigo,
        ),
      ]),
    );
  }

  Widget _careServiceSection() {
    final services = _nursingServices();

    final root = map(requirement['nursing']);

    final staffType = text(
      root['staffType'],
      fallback: services.isNotEmpty
          ? text(services.first['staffType'], fallback: 'Care Staff')
          : 'Care Staff',
    );

    final count = root['count'] ??
        (services.isNotEmpty ? services.first['count'] : null) ??
        1;

    final shift = text(
      root['shift'],
      fallback: services.isNotEmpty
          ? text(services.first['shift'], fallback: '—')
          : '—',
    );

    return _section(
      key: 'care',
      icon: _isNursing
          ? Icons.medical_services_outlined
          : Icons.volunteer_activism_outlined,
      color: _isNursing ? green : orange,
      title: _isNursing ? 'Nursing Details' : 'Caretaker Details',
      subtitle: 'Staff requirement, shift and service duration',
      child: Column(
        children: [
          _twoColumnInfo([
            _infoTile(
              icon: Icons.badge_outlined,
              label: 'Staff Type',
              value: staffType,
              color: _isNursing ? green : orange,
            ),
            _infoTile(
              icon: Icons.groups_2_outlined,
              label: 'Staff Count',
              value: text(count),
              color: _isNursing ? green : orange,
            ),
            _infoTile(
              icon: Icons.schedule_rounded,
              label: 'Shift',
              value: shift,
              color: _isNursing ? green : orange,
            ),
            _infoTile(
              icon: Icons.timelapse_rounded,
              label: 'Duration',
              value:
                  '${text(requirement['expectedDurationDays'], fallback: '—')} days',
              color: _isNursing ? green : orange,
            ),
            _infoTile(
              icon: Icons.event_available_outlined,
              label: 'Start Date',
              value: date(requirement['expectedStartDate']),
              color: _isNursing ? green : orange,
            ),
            _infoTile(
              icon: Icons.event_busy_outlined,
              label: 'End Date',
              value: date(requirement['expectedEndDate']),
              color: _isNursing ? green : orange,
            ),
          ]),
          if (services.isNotEmpty) ...[
            const SizedBox(height: 11),
            _subheading('Requested Care Services'),
            const SizedBox(height: 8),
            ...services.asMap().entries.map(
              (entry) => _careServiceCard(
                entry.key,
                entry.value,
              ),
            ),
          ],
          if (text(root['notes'], fallback: '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _notesBox(
              title: 'Service Notes',
              value: text(root['notes']),
              color: _isNursing ? green : orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _careServiceCard(int index, Map<String, dynamic> service) {
    final staffType = text(
      service['staffType'],
      fallback: 'Care Staff',
    );

    final shift = text(
      service['shift'],
      fallback: '—',
    );

    final count = text(
      service['count'],
      fallback: '1',
    );

    final notes = text(
      service['notes'],
      fallback: '',
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (_isNursing ? green : orange).withOpacity(.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: _isNursing ? green : orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staffType,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count staff  •  $shift shift',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.35,
                      color: ink2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _equipmentSection() {
    final items = _equipmentItems();

    return _section(
      key: 'equipment',
      icon: Icons.inventory_2_outlined,
      color: blue,
      title: 'Equipment / Items Requested',
      subtitle:
          '${items.length} item${items.length == 1 ? '' : 's'} requested for this requirement',
      trailing: _countBadge(items.length, blue),
      child: items.isEmpty
          ? _emptyInside(
              Icons.inventory_2_outlined,
              'No equipment items listed',
            )
          : Column(
              children: [
                ...items.asMap().entries.map(
                  (entry) => _equipmentItemCard(
                    entry.key,
                    entry.value,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _equipmentItemCard(
    int index,
    Map<String, dynamic> item,
  ) {
    final name = text(
      item['name'] ??
          item['itemName'] ??
          item['productName'] ??
          item['productId'],
      fallback: 'Equipment Item',
    );

    final qty = text(
      item['qty'] ?? item['quantity'],
      fallback: '1',
    );

    final days = text(
      item['expectedDurationDays'] ??
          item['days'] ??
          requirement['expectedDurationDays'],
      fallback: '—',
    );

    final start = item['expectedStartDate'] ?? item['startDate'];
    final end = item['expectedEndDate'] ?? item['endDate'];

    final notes = text(
      item['unitNotes'] ??
          item['notes'] ??
          item['specialInstructions'],
      fallback: '',
    );

    final productId = text(
      item['productId'],
      fallback: '',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(19),
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
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              _miniPill(
                'Qty $qty',
                blue,
                blueSoft,
              ),
            ],
          ),
          const SizedBox(height: 11),
          _twoColumnInfo([
            _infoTile(
              icon: Icons.inventory_outlined,
              label: 'Product ID',
              value: productId.isEmpty ? 'Not available' : productId,
              color: blue,
            ),
            _infoTile(
              icon: Icons.timelapse_outlined,
              label: 'Duration',
              value: '$days days',
              color: blue,
            ),
            _infoTile(
              icon: Icons.event_available_outlined,
              label: 'Start Date',
              value: date(start),
              color: blue,
            ),
            _infoTile(
              icon: Icons.event_busy_outlined,
              label: 'End Date',
              value: date(end),
              color: blue,
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

  Widget _detailsSection() {
    final details = text(
      requirement['requirementDetails'],
      fallback: text(
        requirement['specialInstructions'],
        fallback: '',
      ),
    );

    final notes = text(
      requirement['notes'],
      fallback: '',
    );

    return _section(
      key: 'notes',
      icon: Icons.notes_rounded,
      color: purple,
      title: 'Instructions & Notes',
      subtitle: 'Special instructions and operational notes',
      child: Column(
        children: [
          if (details.isNotEmpty)
            _notesBox(
              title: 'Requirement Details',
              value: details,
              color: purple,
            ),
          if (details.isNotEmpty && notes.isNotEmpty)
            const SizedBox(height: 10),
          if (notes.isNotEmpty)
            _notesBox(
              title: 'Internal Notes',
              value: notes,
              color: purple,
            ),
          if (details.isEmpty && notes.isEmpty)
            _emptyInside(
              Icons.notes_outlined,
              'No additional notes available',
            ),
        ],
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

  Widget _statusSection() {
    final current = _status();
    final statusColor = _statusColor();

    const steps = <String>[
      'created',
      'ready_for_quotation',
      'quotation shared',
      'order_created',
    ];

    final normalizedCurrent = current.toLowerCase();

    int activeIndex = 0;

    for (var i = 0; i < steps.length; i++) {
      if (normalizedCurrent == steps[i].toLowerCase()) {
        activeIndex = i;
      }
    }

    if (normalizedCurrent.contains('quotation')) activeIndex = 2;
    if (normalizedCurrent.contains('order')) activeIndex = 3;

    return _section(
      key: 'status',
      icon: Icons.timeline_rounded,
      color: statusColor,
      title: 'Requirement Status',
      subtitle: 'Current progress through the requirement lifecycle',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _statusSoftColor(),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: statusColor.withOpacity(.13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    color: statusColor,
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
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        current,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...steps.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final label = entry.value;
              final completed = index <= activeIndex;
              final isLast = index == steps.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: completed
                              ? statusColor
                              : const Color(0xFFF1F3F5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          completed
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 16,
                          color: completed ? Colors.white : lightMuted,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 34,
                          color: index < activeIndex
                              ? statusColor.withOpacity(.35)
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
                          fontWeight: completed
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: completed ? ink : muted,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    final history = _history();

    return _section(
      key: 'history',
      icon: Icons.history_rounded,
      color: ink2,
      title: 'Activity History',
      subtitle:
          '${history.length} recorded change${history.length == 1 ? '' : 's'}',
      trailing: _countBadge(history.length, ink2),
      child: history.isEmpty
          ? _emptyInside(
              Icons.history_rounded,
              'No history available',
            )
          : Column(
              children: history.asMap().entries.map(
                (entry) {
                  return _historyItem(
                    entry.key,
                    entry.value,
                    entry.key == history.length - 1,
                  );
                },
              ).toList(),
            ),
    );
  }

  Widget _historyItem(
    int index,
    Map<String, dynamic> item,
    bool last,
  ) {
    final type = text(
      item['type'],
      fallback: 'activity',
    );

    final field = text(
      item['field'],
      fallback: '',
    );

    final changedBy = text(
      item['changedByName'] ?? item['changedBy'],
      fallback: 'System',
    );

    final note = text(
      item['note'],
      fallback: '',
    );

    final oldValue = text(
      item['oldValue'],
      fallback: '',
    );

    final newValue = text(
      item['newValue'],
      fallback: '',
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: indigoSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: indigo,
                  size: 17,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 11),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFC),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${type.toUpperCase()}${field.isNotEmpty ? ' • $field' : ''}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                      ),
                      Text(
                        dateTime(item['ts']),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: lightMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    changedBy,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: ink2,
                      ),
                    ),
                  ],
                  if (oldValue.isNotEmpty || newValue.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _changeChip(
                          oldValue.isEmpty ? '—' : oldValue,
                          red,
                          redSoft,
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: lightMuted,
                        ),
                        _changeChip(
                          newValue.isEmpty ? '—' : newValue,
                          green,
                          greenSoft,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeChip(
    String value,
    Color color,
    Color soft,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _countBadge(int count, Color color) {
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

  Widget _miniPill(
    String value,
    Color color,
    Color soft,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _subheading(String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: ink,
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

  Widget _bottomActions() {
    final status = text(requirement['status']).toLowerCase();
    final canCreate = status != 'quotation shared' &&
        status != 'order_created' &&
        widget.onCreateQuotation != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.97),
        border: const Border(
          top: BorderSide(color: border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                ),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink2,
                  side: const BorderSide(color: border),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (canCreate) ...[
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _updating
                      ? null
                      : widget.onCreateQuotation,
                  icon: _updating
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.request_quote_rounded,
                          size: 18,
                        ),
                  label: const Text('Create Quotation'),
                  style: FilledButton.styleFrom(
                    backgroundColor: indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
          'Requirement',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh data',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: ink2,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: _bottomActions(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _hero(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _customerSection(),
                  _requirementInfoSection(),
                  if (_isCareService)
                    _careServiceSection()
                  else
                    _equipmentSection(),
                  _detailsSection(),
                  _statusSection(),
                  _historySection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
