import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NursingOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const NursingOrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<NursingOrderDetailsScreen> createState() =>
      _NursingOrderDetailsScreenState();
}

class _NursingOrderDetailsScreenState
    extends State<NursingOrderDetailsScreen> {
  // ============================================================
  // PREMIUM LIGHT THEME
  // ============================================================

  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;

  static const Color primary = Color(0xFF111827);
  static const Color secondary = Color(0xFF4B5563);
  static const Color muted = Color(0xFF6B7280);
  static const Color lightMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);

  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF5);

  static const Color orange = Color(0xFFD97706);
  static const Color orangeSoft = Color(0xFFFFF7ED);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);

  // ============================================================
  // STATE
  // ============================================================

  final Set<String> collapsedSections = {};

  Map<String, dynamic> get order => widget.order;

  // ============================================================
  // HELPERS
  // ============================================================

  String text(
    dynamic value, {
    String fallback = "Not available",
  }) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    if (result.isEmpty || result == "null") {
      return fallback;
    }

    return result;
  }

  double number(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  List<dynamic> list(dynamic value) {
    if (value is List) {
      return List<dynamic>.from(value);
    }

    return [];
  }

  Map<String, dynamic> map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String date(dynamic value) {
    final d = parseDate(value);

    if (d == null) {
      return text(value);
    }

    return DateFormat("dd MMM yyyy").format(d);
  }

  String dateTime(dynamic value) {
    final d = parseDate(value);

    if (d == null) {
      return text(value);
    }

    return DateFormat("dd MMM yyyy, hh:mm a").format(d);
  }

  String money(dynamic value) {
    return "₹${NumberFormat("#,##0.00", "en_IN").format(number(value))}";
  }

  String moneyCompact(dynamic value) {
    return "₹${NumberFormat("#,##0", "en_IN").format(number(value))}";
  }

  String capitalize(dynamic value) {
    final raw = text(
      value,
      fallback: "Not available",
    );

    if (raw == "Not available") {
      return raw;
    }

    return raw
        .replaceAll("_", " ")
        .split(" ")
        .map(
          (word) {
            if (word.isEmpty) return word;

            return word[0].toUpperCase() +
                word.substring(1).toLowerCase();
          },
        )
        .join(" ");
  }

  Color statusColor(String status) {
    final value = status.toLowerCase();

    if (value.contains("complete") ||
        value.contains("active")) {
      return green;
    }

    if (value.contains("cancel") ||
        value.contains("reject")) {
      return red;
    }

    if (value.contains("assign") ||
        value.contains("pending")) {
      return orange;
    }

    return blue;
  }

  bool collapsed(String id) {
    return collapsedSections.contains(id);
  }

  void toggle(String id) {
    setState(() {
      if (collapsedSections.contains(id)) {
        collapsedSections.remove(id);
      } else {
        collapsedSections.add(id);
      }
    });
  }

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _hero(),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                40,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _financialOverview(),

                    const SizedBox(height: 14),

                    _customerSection(),

                    const SizedBox(height: 14),

                    _serviceOverview(),

                    const SizedBox(height: 14),

                    _servicesSection(),

                    const SizedBox(height: 14),

                    _staffSection(),

                    const SizedBox(height: 14),

                    _paymentSection(),

                    const SizedBox(height: 14),

                    _refundSection(),

                    const SizedBox(height: 14),

                    _serviceHistory(),

                    const SizedBox(height: 14),

                    _orderInformation(),

                    const SizedBox(height: 18),

                    _readOnlyNotice(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    final status = text(
      order["status"],
      fallback: "pending",
    );

    final serviceType = text(
      order["serviceType"],
      fallback: "nursing",
    );

    final orderNo = text(
      order["orderNo"],
      fallback: text(
        order["id"],
        fallback: "Order",
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        30,
      ),
      decoration: const BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Colors.white.withOpacity(.09),
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const SizedBox(
                    width: 43,
                    height: 43,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  "Nursing Service",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              _heroStatus(status),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            capitalize(serviceType),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            orderNo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -.8,
            ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 7),
              Text(
                "Placed ${date(order["createdAt"])}",
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStatus(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            capitalize(status),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FINANCIAL OVERVIEW
  // ============================================================

  Widget _financialOverview() {
    final totals = map(order["totals"]);

    final total = number(
      totals["total"],
    );

    final payments = list(order["payments"]);

    final paid = payments.fold<double>(
      0,
      (sum, raw) {
        return sum + number(
          map(raw)["amount"],
        );
      },
    );

    final refunds = list(order["refunds"]);

    final refunded = refunds.fold<double>(
      0,
      (sum, raw) {
        final refund = map(raw);

        if (text(
              refund["status"],
              fallback: "",
            ).toLowerCase() ==
            "paid") {
          return sum + number(
            refund["amount"],
          );
        }

        return sum;
      },
    );

    final netPaid = paid - refunded;

    final balance = (total - netPaid)
        .clamp(0, double.infinity)
        .toDouble();

    return Container(
      transform: Matrix4.translationValues(
        0,
        -8,
        0,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric(
              icon: Icons.receipt_long_outlined,
              title: "Total",
              value: moneyCompact(total),
              color: blue,
              background: blueSoft,
            ),
          ),

          _metricDivider(),

          Expanded(
            child: _metric(
              icon: Icons.check_circle_outline_rounded,
              title: "Paid",
              value: moneyCompact(paid),
              color: green,
              background: greenSoft,
            ),
          ),

          _metricDivider(),

          Expanded(
            child: _metric(
              icon: Icons.account_balance_wallet_outlined,
              title: "Balance",
              value: moneyCompact(balance),
              color:
                  balance > 0 ? orange : green,
              background:
                  balance > 0
                      ? orangeSoft
                      : greenSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color background,
  }) {
    return Column(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(
      width: 1,
      height: 48,
      color: border,
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _section({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Color color = blue,
  }) {
    final isCollapsed = collapsed(id);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
        boxShadow: cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => toggle(id),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.09),
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedRotation(
                    turns: isCollapsed ? -.25 : 0,
                    duration:
                        const Duration(milliseconds: 220),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            duration:
                const Duration(milliseconds: 220),
            crossFadeState: isCollapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox(
              height: 1,
              width: double.infinity,
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                17,
                0,
                17,
                17,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER
  // ============================================================

  Widget _customerSection() {
    final contact =
        map(order["deliveryContact"]);

    final name = text(
      order["customerName"],
      fallback: "Customer",
    );

    return _section(
      id: "customer",
      title: "Customer",
      subtitle:
          "Patient / customer and contact information",
      icon: Icons.person_outline_rounded,
      color: blue,
      child: Column(
        children: [
          Row(
            children: [
              _avatar(name),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text(
                        order["customerPhone"],
                        fallback:
                            "Phone not available",
                      ),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _info(
            Icons.phone_outlined,
            "Phone",
            order["customerPhone"],
          ),

          _info(
            Icons.email_outlined,
            "Email",
            order["customerEmail"],
          ),

          _info(
            Icons.location_on_outlined,
            "Service Address",
            order["deliveryAddress"],
            multiline: true,
          ),

          if (contact.isNotEmpty) ...[
            const SizedBox(height: 5),

            _subHeading(
              "Service Contact",
            ),

            const SizedBox(height: 8),

            _info(
              Icons.person_outline_rounded,
              "Name",
              contact["name"],
            ),

            _info(
              Icons.phone_outlined,
              "Phone",
              contact["phone"],
            ),

            _info(
              Icons.email_outlined,
              "Email",
              contact["email"],
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final initials = name
        .split(" ")
        .where(
          (x) => x.trim().isNotEmpty,
        )
        .take(2)
        .map(
          (x) => x[0].toUpperCase(),
        )
        .join();

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        initials.isEmpty ? "C" : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // SERVICE OVERVIEW
  // ============================================================

  Widget _serviceOverview() {
    final type = text(
      order["serviceType"],
      fallback: "nursing",
    );

    final items = list(
      order["items"],
    );

    DateTime? start;
    DateTime? end;

    for (final raw in items) {
      final item = map(raw);

      final s =
          parseDate(item["expectedStartDate"]);

      final e =
          parseDate(item["expectedEndDate"]);

      if (s != null &&
          (start == null || s.isBefore(start!))) {
        start = s;
      }

      if (e != null &&
          (end == null || e.isAfter(end!))) {
        end = e;
      }
    }

    return _section(
      id: "overview",
      title: "Service Overview",
      subtitle:
          "Your nursing / caretaker service",
      icon: Icons.medical_services_outlined,
      color: green,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF0FDF4),
                  Color(0xFFF8FAFC),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(15),
              border: Border.all(
                color: green.withOpacity(.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Icon(
                    type.toLowerCase() ==
                            "caretaker"
                        ? Icons.accessibility_new_rounded
                        : Icons.medical_services_outlined,
                    color: green,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Service Type",
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        capitalize(type),
                        style: const TextStyle(
                          color: primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          if (start != null || end != null)
            _serviceDateRange(
              start,
              end,
            ),

          _info(
            Icons.receipt_long_outlined,
            "Order Number",
            order["orderNo"] ??
                order["id"],
          ),

          _info(
            Icons.flag_outlined,
            "Order Status",
            capitalize(order["status"]),
          ),
        ],
      ),
    );
  }

  Widget _serviceDateRange(
    DateTime? start,
    DateTime? end,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(
        bottom: 13,
      ),
      decoration: BoxDecoration(
        color: blueSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _datePoint(
              "START",
              start == null
                  ? "—"
                  : DateFormat(
                      "dd MMM yyyy",
                    ).format(start),
              blue,
            ),
          ),

          Container(
            width: 42,
            height: 2,
            color: blue.withOpacity(.18),
          ),

          Expanded(
            child: _datePoint(
              "END",
              end == null
                  ? "—"
                  : DateFormat(
                      "dd MMM yyyy",
                    ).format(end),
              orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePoint(
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SERVICES
  // ============================================================

  Widget _servicesSection() {
    final items = list(order["items"]);

    return _section(
      id: "services",
      title: "Services",
      subtitle:
          "${items.length} ${items.length == 1 ? "service" : "services"} included",
      icon: Icons.list_alt_rounded,
      color: blue,
      child: items.isEmpty
          ? _empty(
              Icons.medical_information_outlined,
              "No service details available.",
            )
          : Column(
              children: List.generate(
                items.length,
                (index) {
                  return _serviceCard(
                    map(items[index]),
                    index,
                    items.length,
                  );
                },
              ),
            ),
    );
  }

  Widget _serviceCard(
    Map<String, dynamic> item,
    int index,
    int total,
  ) {
    final name = text(
      item["name"],
      fallback: "Service",
    );

    final qty = number(
      item["qty"],
    );

    final staffCount = number(
      item["staffCount"],
    );

    final amount = number(
      item["amount"],
    );

    final rate = number(
      item["rate"],
    );

    final days = number(
      item["days"],
    );

    final isStopped =
        item["stopped"] == true ||
        item["isStopped"] == true;

    return Container(
      margin: EdgeInsets.only(
        bottom: index == total - 1 ? 0 : 12,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: isStopped
                      ? redSoft
                      : blueSoft,
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  isStopped
                      ? Icons.stop_circle_outlined
                      : Icons.health_and_safety_outlined,
                  color:
                      isStopped ? red : blue,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 5),

                    if (item["serviceId"] != null)
                      Text(
                        "Service ID: ${text(item["serviceId"])}",
                        style: const TextStyle(
                          color: muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              if (isStopped)
                _badge(
                  "Stopped",
                  red,
                  redSoft,
                ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _mini(
                  "Required",
                  qty == 0
                      ? "—"
                      : qty.toStringAsFixed(
                          qty.truncateToDouble() == qty
                              ? 0
                              : 1,
                        ),
                ),
              ),
              Expanded(
                child: _mini(
                  "Staff",
                  staffCount == 0
                      ? "—"
                      : staffCount.toStringAsFixed(0),
                ),
              ),
              Expanded(
                child: _mini(
                  "Days",
                  days == 0
                      ? "—"
                      : days.toStringAsFixed(0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _dateRangeTile(
            item["expectedStartDate"],
            item["expectedEndDate"],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: _priceBox(
                  "Rate",
                  money(rate),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _priceBox(
                  "Service Total",
                  money(amount),
                  strong: true,
                ),
              ),
            ],
          ),

          if (item["shift"] != null)
            _info(
              Icons.schedule_outlined,
              "Shift",
              capitalize(item["shift"]),
            ),

          if (item["careType"] != null)
            _info(
              Icons.volunteer_activism_outlined,
              "Care Type",
              item["careType"],
            ),

          if (item["notes"] != null)
            _info(
              Icons.notes_outlined,
              "Notes",
              item["notes"],
              multiline: true,
            ),
        ],
      ),
    );
  }

  Widget _dateRangeTile(
    dynamic start,
    dynamic end,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blueSoft.withOpacity(.60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.date_range_rounded,
            color: blue,
            size: 18,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "Service Period",
                  style: TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${date(start)}  →  ${date(end)}",
                  style: const TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBox(
    String title,
    String value, {
    bool strong = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: primary,
              fontSize: strong ? 14 : 12,
              fontWeight:
                  strong
                      ? FontWeight.w900
                      : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(
    String title,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: primary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAFF
  // ============================================================

  Widget _staffSection() {
    final items = list(order["items"]);

    return _section(
      id: "staff",
      title: "Assigned Care Team",
      subtitle:
          "Nurse / caretaker assigned to your services",
      icon: Icons.groups_rounded,
      color: green,
      child: _staffContent(items),
    );
  }

  Widget _staffContent(
    List<dynamic> items,
  ) {
    final assignments =
        _localAssignments();

    if (assignments.isEmpty) {
      return _empty(
        Icons.person_search_outlined,
        "No care team has been assigned yet.",
      );
    }

    final grouped =
        <int, List<Map<String, dynamic>>>{};

    for (final assignment in assignments) {
      final index = number(
        assignment["serviceIndex"],
      ).toInt();

      grouped.putIfAbsent(
        index,
        () => [],
      );

      grouped[index]!.add(
        assignment,
      );
    }

    return Column(
      children: grouped.entries.map(
        (entry) {
          final serviceIndex =
              entry.key;

          final serviceName =
              serviceIndex < items.length
                  ? text(
                      map(items[serviceIndex])["name"],
                      fallback:
                          "Service ${serviceIndex + 1}",
                    )
                  : "Service ${serviceIndex + 1}";

          return _staffServiceGroup(
            serviceName,
            entry.value,
          );
        },
      ).toList(),
    );
  }

  List<Map<String, dynamic>> _localAssignments() {
    final raw =
        order["staffAssignments"];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (x) => Map<String, dynamic>.from(x),
        )
        .where(
          (x) =>
              text(
                x["status"],
                fallback: "assigned",
              ).toLowerCase() !=
              "cancelled",
        )
        .toList();
  }

  Widget _staffServiceGroup(
    String serviceName,
    List<Map<String, dynamic>> assignments,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_outlined,
                color: green,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  serviceName,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _badge(
                "${assignments.length} Assigned",
                green,
                greenSoft,
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...assignments.map(
            _staffCard,
          ),
        ],
      ),
    );
  }

  Widget _staffCard(
    Map<String, dynamic> staff,
  ) {
    final name = text(
      staff["staffName"] ??
          staff["name"],
      fallback: "Assigned Staff",
    );

    final role = text(
      staff["staffType"] ??
          staff["role"],
      fallback: "Care Staff",
    );

    final amount =
        number(staff["amount"]);

    final paid =
        number(staff["paidAmount"]);

    final balance =
        number(staff["balanceAmount"]);

    final isPaid =
        staff["paid"] == true ||
        balance <= 0;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: greenSoft,
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: green,
                  size: 19,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      capitalize(role),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              _badge(
                isPaid ? "Paid" : "Assigned",
                isPaid ? green : orange,
                isPaid
                    ? greenSoft
                    : orangeSoft,
              ),
            ],
          ),

          const SizedBox(height: 12),

          _info(
            Icons.date_range_outlined,
            "Assignment Period",
            "${dateTime(staff["startDate"])} → ${dateTime(staff["endDate"])}",
          ),

          _info(
            Icons.schedule_outlined,
            "Rate Type",
            capitalize(
              staff["rateType"],
            ),
          ),

          _info(
            Icons.currency_rupee_rounded,
            "Rate",
            money(staff["rate"]),
          ),

          Row(
            children: [
              Expanded(
                child: _staffMoney(
                  "Total",
                  amount,
                ),
              ),
              Expanded(
                child: _staffMoney(
                  "Paid",
                  paid,
                ),
              ),
              Expanded(
                child: _staffMoney(
                  "Balance",
                  balance,
                ),
              ),
            ],
          ),

          finalStaffPayments(staff),
        ],
      ),
    );
  }

  Widget _staffMoney(
    String title,
    double value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          money(value),
          style: const TextStyle(
            color: primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget finalStaffPayments(
    Map<String, dynamic> staff,
  ) {
    final payments =
        list(staff["payments"]);

    if (payments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        _subHeading(
          "Staff Payment History",
        ),

        const SizedBox(height: 7),

        ...payments.map(
          (raw) {
            final payment = map(raw);

            return Container(
              margin: const EdgeInsets.only(
                bottom: 6,
              ),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFB),
                borderRadius:
                    BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: green,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      money(
                        payment["amount"],
                      ),
                      style: const TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    date(
                      payment["date"],
                    ),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Widget _paymentSection() {
    final totals =
        map(order["totals"]);

    final subtotal =
        number(totals["subtotal"]);

    final discount =
        number(totals["discountAmount"]);

    final total =
        number(totals["total"]);

    final taxBreakdown =
        list(
          totals["taxBreakdown"] ??
              totals["taxes"],
        );

    final taxTotal =
        taxBreakdown.fold<double>(
      0,
      (sum, raw) {
        return sum + number(
          map(raw)["amount"],
        );
      },
    );

    final payments =
        list(order["payments"]);

    final paid =
        payments.fold<double>(
      0,
      (sum, raw) {
        return sum + number(
          map(raw)["amount"],
        );
      },
    );

    final refunds =
        list(order["refunds"]);

    final refundPaid =
        refunds.fold<double>(
      0,
      (sum, raw) {
        final r = map(raw);

        if (text(
              r["status"],
              fallback: "",
            ).toLowerCase() ==
            "paid") {
          return sum + number(
            r["amount"],
          );
        }

        return sum;
      },
    );

    final netPaid =
        paid - refundPaid;

    final balance =
        (total - netPaid)
            .clamp(
              0,
              double.infinity,
            )
            .toDouble();

    return _section(
      id: "payments",
      title: "Payment & Billing",
      subtitle:
          "Complete customer billing information",
      icon: Icons.account_balance_wallet_outlined,
      color: green,
      child: Column(
        children: [
          _moneyRow(
            "Subtotal",
            money(subtotal),
          ),

          if (discount > 0)
            _moneyRow(
              "Discount",
              "- ${money(discount)}",
              valueColor: green,
            ),

          if (taxBreakdown.isNotEmpty) ...[
            const SizedBox(height: 5),

            _subHeading("Taxes"),

            const SizedBox(height: 8),

            ...taxBreakdown.map(
              (raw) {
                final tax = map(raw);

                return _moneyRow(
                  text(
                    tax["name"],
                    fallback: "Tax",
                  ),
                  money(
                    tax["amount"],
                  ),
                  small: true,
                );
              },
            ),
          ],

          if (taxTotal > 0)
            _moneyRow(
              "Total Tax",
              money(taxTotal),
            ),

          const SizedBox(height: 5),

          const Divider(
            color: border,
          ),

          const SizedBox(height: 5),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Order Total",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  money(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _moneyRow(
            "Total Paid",
            money(paid),
            valueColor: green,
          ),

          _moneyRow(
            "Refunded",
            money(refundPaid),
            valueColor:
                refundPaid > 0
                    ? red
                    : muted,
          ),

          _moneyRow(
            "Net Paid",
            money(netPaid),
            valueColor: green,
          ),

          _moneyRow(
            "Balance Due",
            money(balance),
            valueColor:
                balance > 0
                    ? orange
                    : green,
          ),

          if (payments.isNotEmpty) ...[
            const SizedBox(height: 15),

            _subHeading(
              "Payment History",
            ),

            const SizedBox(height: 9),

            ...payments.map(
              (raw) => _customerPayment(
                map(raw),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moneyRow(
    String label,
    String value, {
    Color? valueColor,
    bool small = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:
                    small ? muted : secondary,
                fontSize:
                    small ? 10 : 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color:
                  valueColor ?? primary,
              fontSize:
                  small ? 10 : 12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerPayment(
    Map<String, dynamic> payment,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: greenSoft,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: green,
              size: 18,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  money(
                    payment["amount"],
                  ),
                  style: const TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  capitalize(
                    payment["method"],
                  ),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              if (payment["date"] != null)
                Text(
                  date(
                    payment["date"],
                  ),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

              if (payment["reference"] != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 3,
                  ),
                  child: Text(
                    "Ref: ${text(payment["reference"])}",
                    style: const TextStyle(
                      color: muted,
                      fontSize: 8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REFUNDS
  // ============================================================

  Widget _refundSection() {
    final refunds =
        list(order["refunds"]);

    if (refunds.isEmpty) {
      return const SizedBox.shrink();
    }

    return _section(
      id: "refunds",
      title: "Refunds",
      subtitle:
          "${refunds.length} refund ${refunds.length == 1 ? "record" : "records"}",
      icon: Icons.currency_exchange_rounded,
      color: orange,
      child: Column(
        children: refunds.map(
          (raw) {
            final refund = map(raw);

            final status = text(
              refund["status"],
              fallback: "pending",
            );

            final amount =
                number(refund["amount"]);

            final paid =
                number(refund["paidAmount"]);

            final pending =
                (amount - paid)
                    .clamp(
                      0,
                      double.infinity,
                    )
                    .toDouble();

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(
                bottom: 10,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: orangeSoft.withOpacity(.65),
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color:
                      orange.withOpacity(.12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: orangeSoft,
                          borderRadius:
                              BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.currency_exchange_rounded,
                          color: orange,
                          size: 18,
                        ),
                      ),

                      const SizedBox(width: 10),

                      const Expanded(
                        child: Text(
                          "Customer Refund",
                          style: TextStyle(
                            color: primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                      _badge(
                        capitalize(status),
                        status.toLowerCase() ==
                                "paid"
                            ? green
                            : orange,
                        status.toLowerCase() ==
                                "paid"
                            ? greenSoft
                            : orangeSoft,
                      ),
                    ],
                  ),

                  const SizedBox(height: 13),

                  _moneyRow(
                    "Refund Amount",
                    money(amount),
                  ),

                  _moneyRow(
                    "Paid",
                    money(paid),
                  ),

                  _moneyRow(
                    "Pending",
                    money(pending),
                  ),

                  if (refund["reason"] != null)
                    _info(
                      Icons.info_outline_rounded,
                      "Reason",
                      refund["reason"],
                      multiline: true,
                    ),

                  if (refund["note"] != null)
                    _info(
                      Icons.notes_outlined,
                      "Note",
                      refund["note"],
                      multiline: true,
                    ),

                  if (refund["createdAt"] != null)
                    _info(
                      Icons.calendar_today_outlined,
                      "Created",
                      dateTime(
                        refund["createdAt"],
                      ),
                    ),

                  if (refund["paidAt"] != null)
                    _info(
                      Icons.check_circle_outline,
                      "Paid At",
                      dateTime(
                        refund["paidAt"],
                      ),
                    ),
                ],
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ============================================================
  // SERVICE HISTORY
  // ============================================================

  Widget _serviceHistory() {
    final extensions =
        list(order["extensionHistory"]);

    final stops =
        list(order["stopHistory"]);

    if (extensions.isEmpty &&
        stops.isEmpty) {
      return const SizedBox.shrink();
    }

    return _section(
      id: "history",
      title: "Service History",
      subtitle:
          "Extensions and service changes",
      icon: Icons.history_rounded,
      color: blue,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (extensions.isNotEmpty) ...[
            _historyHeading(
              Icons.update_rounded,
              "Service Extensions",
              blue,
            ),

            const SizedBox(height: 9),

            ...extensions.map(
              (raw) {
                return _extensionHistoryCard(
                  map(raw),
                );
              },
            ),
          ],

          if (extensions.isNotEmpty &&
              stops.isNotEmpty)
            const SizedBox(height: 14),

          if (stops.isNotEmpty) ...[
            _historyHeading(
              Icons.stop_circle_outlined,
              "Service Stops",
              red,
            ),

            const SizedBox(height: 9),

            ...stops.map(
              (raw) {
                return _stopHistoryCard(
                  map(raw),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _extensionHistoryCard(
    Map<String, dynamic> item,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: blueSoft.withOpacity(.55),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: blue.withOpacity(.10),
        ),
      ),
      child: Column(
        children: [
          if (item["serviceName"] != null)
            _info(
              Icons.medical_services_outlined,
              "Service",
              item["serviceName"],
            ),

          _info(
            Icons.event_outlined,
            "Previous End",
            date(
              item["oldEndDate"] ??
                  item["previousEndDate"],
            ),
          ),

          _info(
            Icons.event_available_outlined,
            "New End",
            date(
              item["newEndDate"],
            ),
          ),

          _info(
            Icons.today_outlined,
            "Extra Days",
            item["extraDays"],
          ),

          _info(
            Icons.currency_rupee_rounded,
            "Additional Amount",
            money(
              item["extraAmount"] ??
                  item["extraPrice"],
            ),
          ),

          _info(
            Icons.schedule_outlined,
            "Extended At",
            dateTime(
              item["extendedAt"] ??
                  item["date"],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopHistoryCard(
    Map<String, dynamic> item,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: redSoft,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: red.withOpacity(.10),
        ),
      ),
      child: Column(
        children: [
          if (item["serviceName"] != null)
            _info(
              Icons.medical_services_outlined,
              "Service",
              item["serviceName"],
            ),

          _info(
            Icons.event_outlined,
            "Previous End",
            date(
              item["oldEndDate"],
            ),
          ),

          _info(
            Icons.event_busy_outlined,
            "Stopped / New End",
            date(
              item["newEndDate"],
            ),
          ),

          _info(
            Icons.currency_rupee_rounded,
            "Previous Amount",
            money(
              item["oldAmount"],
            ),
          ),

          _info(
            Icons.currency_rupee_rounded,
            "New Amount",
            money(
              item["newAmount"],
            ),
          ),

          _info(
            Icons.schedule_outlined,
            "Stopped At",
            dateTime(
              item["stoppedAt"],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER INFORMATION
  // ============================================================

  Widget _orderInformation() {
    return _section(
      id: "information",
      title: "Order Information",
      subtitle:
          "Additional order references",
      icon: Icons.info_outline_rounded,
      color: muted,
      child: Column(
        children: [
          _info(
            Icons.fingerprint_rounded,
            "Order ID",
            order["id"],
          ),

          _info(
            Icons.receipt_long_outlined,
            "Order Number",
            order["orderNo"],
          ),

          _info(
            Icons.medical_information_outlined,
            "Service Type",
            capitalize(
              order["serviceType"],
            ),
          ),

          _info(
            Icons.flag_outlined,
            "Status",
            capitalize(
              order["status"],
            ),
          ),

          _info(
            Icons.calendar_today_outlined,
            "Created",
            dateTime(
              order["createdAt"],
            ),
          ),

          _info(
            Icons.update_outlined,
            "Last Updated",
            dateTime(
              order["updatedAt"],
            ),
          ),

          _info(
            Icons.link_rounded,
            "Lead ID",
            order["leadId"],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // READ ONLY
  // ============================================================

  Widget _readOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: muted,
              size: 17,
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Order information",
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "This nursing service order is displayed for your reference. The information shown here is read-only.",
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _info(
    IconData icon,
    String label,
    dynamic value, {
    bool multiline = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius:
            BorderRadius.circular(11),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: muted,
              size: 15,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text(value),
                  maxLines:
                      multiline ? 6 : 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: secondary,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeading(
    String title,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _badge(
    String label,
    Color color,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _historyHeading(
    IconData icon,
    String title,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 17,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: primary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _empty(
    IconData icon,
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: lightMuted,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}