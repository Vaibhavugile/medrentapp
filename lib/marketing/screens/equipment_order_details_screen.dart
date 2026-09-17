import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EquipmentOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const EquipmentOrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<EquipmentOrderDetailsScreen> createState() =>
      _EquipmentOrderDetailsScreenState();
}

class _EquipmentOrderDetailsScreenState
    extends State<EquipmentOrderDetailsScreen> {
  // ============================================================
  // PREMIUM PALETTE
  // ============================================================

  static const Color bg = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;

  static const Color ink = Color(0xFF111827);
  static const Color ink2 = Color(0xFF374151);
  static const Color muted = Color(0xFF6B7280);
  static const Color lightMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE7EAF0);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueLight = Color(0xFFEFF6FF);

  static const Color green = Color(0xFF059669);
  static const Color greenLight = Color(0xFFECFDF5);

  static const Color orange = Color(0xFFD97706);
  static const Color orangeLight = Color(0xFFFFF7ED);

  static const Color red = Color(0xFFDC2626);
  static const Color redLight = Color(0xFFFEF2F2);

  // ============================================================
  // STATE
  // ============================================================

  final Set<String> _collapsedSections = {};

  Map<String, dynamic> get order => widget.order;

  // ============================================================
  // BASIC HELPERS
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

  String money(dynamic value) {
    final amount = number(value);

    return "₹${NumberFormat("#,##0.00", "en_IN").format(amount)}";
  }

  String moneyCompact(dynamic value) {
    final amount = number(value);

    return "₹${NumberFormat("#,##0", "en_IN").format(amount)}";
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is TimestampLike) {
      return value.dateTime;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    // Firebase Timestamp compatibility without requiring
    // direct dependency here.
    try {
      final dynamic timestamp = value;

      if (timestamp.toDate != null) {
        return timestamp.toDate();
      }
    } catch (_) {}

    return null;
  }

  String date(dynamic value) {
    final d = parseDate(value);

    if (d == null) {
      return text(value, fallback: "Not available");
    }

    return DateFormat("dd MMM yyyy").format(d);
  }

  String dateTime(dynamic value) {
    final d = parseDate(value);

    if (d == null) {
      return text(value, fallback: "Not available");
    }

    return DateFormat("dd MMM yyyy, hh:mm a").format(d);
  }

  String capitalize(dynamic value) {
    final raw = text(value, fallback: "Not available");

    if (raw == "Not available") return raw;

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

  List<dynamic> list(dynamic value) {
    return value is List ? List<dynamic>.from(value) : [];
  }

  Map<String, dynamic> map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  // ============================================================
  // STATUS
  // ============================================================

  Color statusColor(String status) {
    final value = status.toLowerCase();

    if (value.contains("complete") ||
        value.contains("deliver") ||
        value.contains("active")) {
      return green;
    }

    if (value.contains("cancel") ||
        value.contains("reject")) {
      return red;
    }

    if (value.contains("pending") ||
        value.contains("assign") ||
        value.contains("accept") ||
        value.contains("transit")) {
      return orange;
    }

    return blue;
  }

  Color statusBackground(String status) {
    return statusColor(status).withOpacity(.11);
  }

  // ============================================================
  // SECTION COLLAPSE
  // ============================================================

  bool isCollapsed(String key) {
    return _collapsedSections.contains(key);
  }

  void toggleSection(String key) {
    setState(() {
      if (_collapsedSections.contains(key)) {
        _collapsedSections.remove(key);
      } else {
        _collapsedSections.add(key);
      }
    });
  }

  // ============================================================
  // SHADOW
  // ============================================================

  List<BoxShadow> get cardShadow {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(.035),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  // ============================================================
  // MAIN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
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
                    _orderOverview(),

                    const SizedBox(height: 14),

                    _customerSection(),

                    const SizedBox(height: 14),

                    _equipmentSection(),

                    const SizedBox(height: 14),

                    _rentalPeriodSection(),

                    const SizedBox(height: 14),

                    _deliverySection(),

                    const SizedBox(height: 14),

                    _paymentSection(),

                    const SizedBox(height: 14),

                    _refundSection(),

                    const SizedBox(height: 14),

                    _serviceHistorySection(),

                    const SizedBox(height: 14),

                    _orderMetaSection(),

                    const SizedBox(height: 20),

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

    final orderNumber = text(
      order["orderNo"],
      fallback: text(
        order["id"],
        fallback: "Order",
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        28,
      ),
      decoration: const BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _heroBackButton(),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  "Equipment Order",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusBackground(status),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: statusColor(status)
                        .withOpacity(.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      capitalize(status),
                      style: TextStyle(
                        color: statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            "Your order",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            orderNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -.8,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 7),
              Text(
                "Placed ${date(order["createdAt"])}",
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroBackButton() {
    return Material(
      color: Colors.white.withOpacity(.09),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.of(context).pop(),
        child: const SizedBox(
          width: 43,
          height: 43,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ORDER OVERVIEW
  // ============================================================

  Widget _orderOverview() {
    final totals = map(order["totals"]);

    final total = number(totals["total"]);

    final payments = list(order["payments"]);

    final paid = payments.fold<double>(
      0,
      (sum, item) {
        return sum + number(
          map(item)["amount"],
        );
      },
    );

    final balance = (total - paid).clamp(
      0,
      double.infinity,
    );

    return Container(
      transform: Matrix4.translationValues(
        0,
        -8,
        0,
      ),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryMetric(
              icon: Icons.receipt_long_rounded,
              label: "Order Total",
              value: moneyCompact(total),
              iconColor: blue,
              background: blueLight,
            ),
          ),

          _verticalDivider(),

          Expanded(
            child: _summaryMetric(
              icon: Icons.check_circle_outline_rounded,
              label: "Paid",
              value: moneyCompact(paid),
              iconColor: green,
              background: greenLight,
            ),
          ),

          _verticalDivider(),

          Expanded(
            child: _summaryMetric(
              icon: Icons.account_balance_wallet_outlined,
              label: "Balance",
              value: moneyCompact(balance),
              iconColor: balance > 0 ? orange : green,
              background:
                  balance > 0 ? orangeLight : greenLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 50,
      color: border,
      margin: const EdgeInsets.symmetric(
        horizontal: 5,
      ),
    );
  }

  Widget _summaryMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color background,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PREMIUM SECTION CARD
  // ============================================================

  Widget _section({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Color iconColor = blue,
    bool initiallyCollapsed = false,
  }) {
    final collapsed = isCollapsed(id);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => toggleSection(id),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
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
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedRotation(
                    turns: collapsed ? -.25 : 0,
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
            duration: const Duration(milliseconds: 220),
            crossFadeState: collapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox(
              width: double.infinity,
              height: 1,
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
    final contact = map(order["deliveryContact"]);

    final name = text(
      order["customerName"],
      fallback: "Customer",
    );

    return _section(
      id: "customer",
      title: "Customer",
      subtitle: "Customer and delivery contact information",
      icon: Icons.person_outline_rounded,
      iconColor: blue,
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
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text(
                        order["customerPhone"],
                        fallback: "Phone not available",
                      ),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _infoTile(
            icon: Icons.phone_outlined,
            label: "Phone",
            value: order["customerPhone"],
          ),

          _infoTile(
            icon: Icons.email_outlined,
            label: "Email",
            value: order["customerEmail"],
          ),

          _infoTile(
            icon: Icons.location_on_outlined,
            label: "Delivery Address",
            value: order["deliveryAddress"],
            multiline: true,
          ),

          if (contact.isNotEmpty) ...[
            const SizedBox(height: 5),

            _subHeading("Delivery Contact"),

            const SizedBox(height: 9),

            _infoTile(
              icon: Icons.person_outline_rounded,
              label: "Name",
              value: contact["name"],
            ),

            _infoTile(
              icon: Icons.phone_outlined,
              label: "Phone",
              value: contact["phone"],
            ),

            _infoTile(
              icon: Icons.email_outlined,
              label: "Email",
              value: contact["email"],
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final initials = name
        .split(" ")
        .where((e) => e.trim().isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
  // EQUIPMENT
  // ============================================================

  Widget _equipmentSection() {
    final items = list(order["items"]);

    return _section(
      id: "equipment",
      title: "Equipment",
      subtitle:
          "${items.length} ${items.length == 1 ? "item" : "items"} in this order",
      icon: Icons.medical_services_outlined,
      iconColor: blue,
      child: items.isEmpty
          ? _emptyState(
              icon: Icons.inventory_2_outlined,
              text: "No equipment information available.",
            )
          : Column(
              children: List.generate(
                items.length,
                (index) {
                  return _equipmentCard(
                    map(items[index]),
                    index,
                    items.length,
                  );
                },
              ),
            ),
    );
  }

  Widget _equipmentCard(
    Map<String, dynamic> item,
    int index,
    int total,
  ) {
    final assets = list(item["assignedAssets"]);

    final qty = number(item["qty"]);

    final assignedCount = assets.length;

    final fullyAssigned =
        qty > 0 && assignedCount >= qty;

    return Container(
      margin: EdgeInsets.only(
        bottom: index == total - 1 ? 0 : 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PRODUCT HEADER
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    color: blueLight,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: blue,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        text(
                          item["name"],
                          fallback: "Equipment",
                        ),
                        style: const TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Product ID: ${text(item["productId"])}",
                        style: const TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (fullyAssigned)
                  _smallBadge(
                    "Assigned",
                    green,
                    greenLight,
                  ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: border,
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _itemMetric(
                        "Quantity",
                        qty.toStringAsFixed(
                          qty.truncateToDouble() == qty
                              ? 0
                              : 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _itemMetric(
                        "Rate",
                        money(item["rate"]),
                      ),
                    ),
                    Expanded(
                      child: _itemMetric(
                        "Days",
                        text(
                          item["days"],
                          fallback: "—",
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 17),

                _dateRange(
                  start: item["expectedStartDate"],
                  end: item["expectedEndDate"],
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(13),
                    border: Border.all(
                      color: border,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Item Amount",
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        money(item["amount"]),
                        style: const TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                if (text(item["branchId"]) !=
                    "Not available") ...[
                  const SizedBox(height: 13),
                  _infoTile(
                    icon: Icons.storefront_outlined,
                    label: "Branch",
                    value: item["branchName"] ??
                        item["branchId"],
                  ),
                ],

                if (text(item["notes"]) !=
                    "Not available") ...[
                  _infoTile(
                    icon: Icons.notes_outlined,
                    label: "Notes",
                    value: item["notes"],
                    multiline: true,
                  ),
                ],

                if (assets.isNotEmpty) ...[
                  const SizedBox(height: 5),

                  _assetSection(
                    assets,
                    qty,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemMetric(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _dateRange({
    required dynamic start,
    required dynamic end,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: blueLight.withOpacity(.55),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.date_range_rounded,
              size: 17,
              color: blue,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rental Period",
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${date(start)}  →  ${date(end)}",
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetSection(
    List<dynamic> assets,
    double qty,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: greenLight.withOpacity(.55),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: green.withOpacity(.10),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                color: green,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Assigned Assets",
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                "${assets.length}/${qty.toInt()}",
                style: const TextStyle(
                  color: green,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: assets.map(
              (asset) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(9),
                    border: Border.all(
                      color: border,
                    ),
                  ),
                  child: Text(
                    text(asset),
                    style: const TextStyle(
                      color: ink2,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RENTAL PERIOD
  // ============================================================

  Widget _rentalPeriodSection() {
    final items = list(order["items"]);

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    DateTime? earliest;
    DateTime? latest;

    for (final raw in items) {
      final item = map(raw);

      final start =
          parseDate(item["expectedStartDate"]);

      final end =
          parseDate(item["expectedEndDate"]);

      if (start != null) {
        if (earliest == null ||
            start.isBefore(earliest!)) {
          earliest = start;
        }
      }

      if (end != null) {
        if (latest == null ||
            end.isAfter(latest!)) {
          latest = end;
        }
      }
    }

    if (earliest == null && latest == null) {
      return const SizedBox.shrink();
    }

    return _section(
      id: "period",
      title: "Rental Period",
      subtitle: "Your equipment service timeline",
      icon: Icons.date_range_rounded,
      iconColor: orange,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _periodPoint(
                  label: "START",
                  value: earliest == null
                      ? "—"
                      : DateFormat(
                          "dd MMM yyyy",
                        ).format(earliest!),
                  color: blue,
                ),
              ),

              Container(
                width: 60,
                height: 2,
                color: border,
              ),

              Expanded(
                child: _periodPoint(
                  label: "END",
                  value: latest == null
                      ? "—"
                      : DateFormat(
                          "dd MMM yyyy",
                        ).format(latest!),
                  color: orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFB),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: border,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: muted,
                  size: 18,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    "The rental dates shown above represent the service period recorded for this order.",
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodPoint({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.25),
                blurRadius: 7,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DELIVERY
  // ============================================================

  Widget _deliverySection() {
    final deliveryType = text(
      order["deliveryType"],
      fallback: "pickup",
    );

    final deliveryStatus = text(
      order["deliveryStatus"],
      fallback: "pending",
    );

    final pickupDrivers =
        list(order["pickupAssignedDrivers"]);

    final returnDrivers =
        list(order["returnAssignedDrivers"]);

    return _section(
      id: "delivery",
      title: "Delivery & Logistics",
      subtitle: "Delivery status, drivers and tracking",
      icon: Icons.local_shipping_outlined,
      iconColor: blue,
      child: Column(
        children: [
          _deliveryStatusHeader(
            deliveryType,
            deliveryStatus,
          ),

          const SizedBox(height: 18),

          _deliveryTimeline(
            deliveryStatus,
          ),

          const SizedBox(height: 18),

          _infoTile(
            icon: Icons.local_shipping_outlined,
            label: "Delivery Type",
            value: capitalize(deliveryType),
          ),

          _infoTile(
            icon: Icons.tag_outlined,
            label: "Pickup Delivery ID",
            value: order["pickupDeliveryId"],
          ),

          _infoTile(
            icon: Icons.assignment_return_outlined,
            label: "Return Delivery ID",
            value: order["returnDeliveryId"],
          ),

          if (pickupDrivers.isNotEmpty) ...[
            const SizedBox(height: 7),
            _subHeading("Pickup Driver"),
            const SizedBox(height: 9),
            _driverCards(pickupDrivers),
          ],

          if (returnDrivers.isNotEmpty) ...[
            const SizedBox(height: 14),
            _subHeading("Return Driver"),
            const SizedBox(height: 9),
            _driverCards(returnDrivers),
          ],
        ],
      ),
    );
  }

  Widget _deliveryStatusHeader(
    String type,
    String status,
  ) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withOpacity(.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: color,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "Current delivery status",
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  capitalize(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          _smallBadge(
            capitalize(type),
            color,
            color.withOpacity(.09),
          ),
        ],
      ),
    );
  }

  Widget _deliveryTimeline(String status) {
    final normalized = status.toLowerCase();

    final stages = [
      {
        "key": "assigned",
        "label": "Assigned",
        "icon": Icons.assignment_turned_in_outlined,
      },
      {
        "key": "accepted",
        "label": "Accepted",
        "icon": Icons.check_circle_outline_rounded,
      },
      {
        "key": "in_transit",
        "label": "In Transit",
        "icon": Icons.local_shipping_outlined,
      },
      {
        "key": "delivered",
        "label": "Delivered",
        "icon": Icons.inventory_2_outlined,
      },
      {
        "key": "completed",
        "label": "Completed",
        "icon": Icons.done_all_rounded,
      },
    ];

    int currentIndex = -1;

    for (int i = 0; i < stages.length; i++) {
      if (normalized.contains(
        stages[i]["key"] as String,
      )) {
        currentIndex = i;
      }
    }

    if (normalized.contains("complete")) {
      currentIndex = 4;
    }

    if (normalized.contains("deliver")) {
      currentIndex = 3;
    }

    if (currentIndex == -1) {
      currentIndex = 0;
    }

    return Column(
      children: List.generate(
        stages.length,
        (index) {
          final stage = stages[index];

          final completed =
              index <= currentIndex;

          final isCurrent =
              index == currentIndex;

          final stageColor =
              completed ? green : border;

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 250),
                      width: isCurrent ? 28 : 23,
                      height: isCurrent ? 28 : 23,
                      decoration: BoxDecoration(
                        color: completed
                            ? green
                            : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: stageColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        completed
                            ? Icons.check_rounded
                            : stage["icon"]
                                as IconData,
                        size: 13,
                        color: completed
                            ? Colors.white
                            : lightMuted,
                      ),
                    ),

                    if (index != stages.length - 1)
                      Container(
                        width: 2,
                        height: 28,
                        color: index < currentIndex
                            ? green
                            : border,
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 3,
                    bottom: 16,
                  ),
                  child: Text(
                    stage["label"] as String,
                    style: TextStyle(
                      color: completed
                          ? ink
                          : muted,
                      fontSize: 12,
                      fontWeight: completed
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),

              if (isCurrent)
                _smallBadge(
                  "Current",
                  green,
                  greenLight,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _driverCards(List<dynamic> drivers) {
    return Column(
      children: drivers.map(
        (raw) {
          final driver = map(raw);

          final name = text(
            driver["name"] ??
                driver["driverName"] ??
                driver["id"],
            fallback: "Assigned driver",
          );

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              bottom: 8,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: blueLight,
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.person_pin_circle_outlined,
                    color: blue,
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
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (driver["phone"] != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            top: 3,
                          ),
                          child: Text(
                            text(driver["phone"]),
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // PAYMENT
  // ============================================================

  Widget _paymentSection() {
    final totals = map(order["totals"]);

    final subtotal = number(
      totals["subtotal"],
    );

    final discount = number(
      totals["discountAmount"],
    );

    final totalTax = number(
      totals["totalTax"],
    );

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

    final balance = (total - paid)
        .clamp(0, double.infinity)
        .toDouble();

    final taxes = list(totals["taxes"]);

    return _section(
      id: "payment",
      title: "Payment & Billing",
      subtitle: "Complete financial breakdown",
      icon: Icons.account_balance_wallet_outlined,
      iconColor: green,
      child: Column(
        children: [
          _financialRow(
            "Subtotal",
            money(subtotal),
          ),

          if (discount > 0)
            _financialRow(
              "Discount",
              "- ${money(discount)}",
              valueColor: green,
            ),

          if (taxes.isNotEmpty) ...[
            const SizedBox(height: 9),

            _subHeading("Taxes"),

            const SizedBox(height: 8),

            ...taxes.map(
              (raw) {
                final tax = map(raw);

                return _financialRow(
                  text(
                    tax["name"],
                    fallback: "Tax",
                  ),
                  money(tax["amount"]),
                  small: true,
                );
              },
            ),
          ],

          if (totalTax > 0)
            _financialRow(
              "Total Tax",
              money(totalTax),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 7,
            ),
            child: Divider(
              height: 1,
              color: border,
            ),
          ),

          _totalRow(
            "Order Total",
            money(total),
          ),

          const SizedBox(height: 7),

          _financialRow(
            "Amount Paid",
            money(paid),
            valueColor: green,
          ),

          _financialRow(
            "Balance Due",
            money(balance),
            valueColor:
                balance > 0 ? orange : green,
          ),

          if (payments.isNotEmpty) ...[
            const SizedBox(height: 18),

            _subHeading("Payment History"),

            const SizedBox(height: 10),

            ...payments.map(
              (raw) => _paymentCard(
                map(raw),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _financialRow(
    String label,
    String value, {
    Color? valueColor,
    bool small = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: small ? muted : ink2,
                fontSize: small ? 11 : 12,
                fontWeight:
                    small ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? ink,
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: greenLight,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.check_rounded,
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
                  money(payment["amount"]),
                  style: const TextStyle(
                    color: ink,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (payment["date"] != null)
            Text(
              date(payment["date"]),
              style: const TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // REFUNDS
  // ============================================================

  Widget _refundSection() {
    final refunds = list(order["refunds"]);

    if (refunds.isEmpty) {
      return const SizedBox.shrink();
    }

    return _section(
      id: "refunds",
      title: "Refunds",
      subtitle:
          "${refunds.length} refund ${refunds.length == 1 ? "record" : "records"}",
      icon: Icons.currency_exchange_rounded,
      iconColor: orange,
      child: Column(
        children: refunds.map(
          (raw) {
            final refund = map(raw);

            final amount =
                number(refund["amount"]);

            final paid =
                number(refund["paidAmount"]);

            final remaining =
                (amount - paid)
                    .clamp(0, double.infinity);

            final status = text(
              refund["status"],
              fallback: "pending",
            );

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(
                bottom: 10,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF5),
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: orange.withOpacity(.14),
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
                          color: orangeLight,
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
                          "Refund",
                          style: TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      _smallBadge(
                        capitalize(status),
                        statusColor(status),
                        statusBackground(status),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _financialRow(
                    "Refund Amount",
                    money(amount),
                  ),

                  _financialRow(
                    "Paid",
                    money(paid),
                  ),

                  _financialRow(
                    "Remaining",
                    money(remaining),
                  ),

                  if (refund["reason"] != null)
                    _financialRow(
                      "Reason",
                      text(refund["reason"]),
                    ),

                  if (refund["paidAt"] != null)
                    _financialRow(
                      "Paid At",
                      dateTime(refund["paidAt"]),
                    ),

                  finalRefundPayments(
                    refund,
                  ),
                ],
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget finalRefundPayments(
    Map<String, dynamic> refund,
  ) {
    final payments = list(
      refund["payments"],
    );

    if (payments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),

        _subHeading("Refund Payment History"),

        const SizedBox(height: 8),

        ...payments.map(
          (raw) {
            final payment = map(raw);

            return Container(
              margin: const EdgeInsets.only(
                bottom: 6,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color: border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      money(payment["amount"]),
                      style: const TextStyle(
                        color: ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
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
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // SERVICE HISTORY
  // ============================================================

  Widget _serviceHistorySection() {
    final items = list(order["items"]);

    final extensions = <Map<String, dynamic>>[];
    final stops = <Map<String, dynamic>>[];

    for (final raw in items) {
      final item = map(raw);

      final extensionHistory =
          list(item["extensionHistory"]);

      for (final rawExtension
          in extensionHistory) {
        final extension = map(rawExtension);

        if (extension.isNotEmpty) {
          extensions.add(extension);
        }
      }

      final stopHistory =
          list(item["stopHistory"]);

      for (final rawStop in stopHistory) {
        final stop = map(rawStop);

        if (stop.isNotEmpty) {
          stops.add(stop);
        }
      }
    }

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
      iconColor: blue,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (extensions.isNotEmpty) ...[
            _historyTitle(
              icon: Icons.update_rounded,
              title: "Extensions",
              color: blue,
            ),

            const SizedBox(height: 10),

            ...extensions.map(
              (extension) => _extensionCard(
                extension,
              ),
            ),
          ],

          if (extensions.isNotEmpty &&
              stops.isNotEmpty)
            const SizedBox(height: 15),

          if (stops.isNotEmpty) ...[
            _historyTitle(
              icon: Icons.stop_circle_outlined,
              title: "Service Stops",
              color: red,
            ),

            const SizedBox(height: 10),

            ...stops.map(
              (stop) => _stopCard(
                stop,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyTitle({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _extensionCard(
    Map<String, dynamic> extension,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: blueLight.withOpacity(.45),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: blue.withOpacity(.10),
        ),
      ),
      child: Column(
        children: [
          _infoTile(
            icon: Icons.event_outlined,
            label: "Previous End Date",
            value: date(
              extension["previousEndDate"],
            ),
          ),

          _infoTile(
            icon: Icons.event_available_outlined,
            label: "New End Date",
            value: date(
              extension["newEndDate"],
            ),
          ),

          _infoTile(
            icon: Icons.add_card_outlined,
            label: "Additional Price",
            value: money(
              extension["extraPrice"],
            ),
          ),

          _infoTile(
            icon: Icons.schedule_outlined,
            label: "Recorded",
            value: dateTime(
              extension["date"],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopCard(
    Map<String, dynamic> stop,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: redLight,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: red.withOpacity(.10),
        ),
      ),
      child: Column(
        children: [
          _infoTile(
            icon: Icons.event_busy_outlined,
            label: "Previous End Date",
            value: date(
              stop["oldEndDate"],
            ),
          ),

          _infoTile(
            icon: Icons.event_available_outlined,
            label: "Stopped On",
            value: date(
              stop["newEndDate"],
            ),
          ),

          _infoTile(
            icon: Icons.schedule_outlined,
            label: "Stopped At",
            value: dateTime(
              stop["stoppedAt"],
            ),
          ),

          _infoTile(
            icon: Icons.payments_outlined,
            label: "Amount",
            value: money(
              stop["newAmount"],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER META
  // ============================================================

  Widget _orderMetaSection() {
    return _section(
      id: "meta",
      title: "Order Information",
      subtitle: "Additional order information",
      icon: Icons.info_outline_rounded,
      iconColor: muted,
      child: Column(
        children: [
          _infoTile(
            icon: Icons.fingerprint_rounded,
            label: "Order ID",
            value: order["id"],
          ),

          _infoTile(
            icon: Icons.receipt_long_outlined,
            label: "Order Number",
            value: order["orderNo"],
          ),

          _infoTile(
            icon: Icons.calendar_today_outlined,
            label: "Created",
            value: dateTime(
              order["createdAt"],
            ),
          ),

          _infoTile(
            icon: Icons.update_outlined,
            label: "Last Updated",
            value: dateTime(
              order["updatedAt"],
            ),
          ),

          _infoTile(
            icon: Icons.business_outlined,
            label: "Branch",
            value: order["branchName"] ??
                order["branchId"],
          ),

          _infoTile(
            icon: Icons.link_rounded,
            label: "Lead ID",
            value: order["leadId"],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // READ ONLY NOTICE
  // ============================================================

  Widget _readOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(15),
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
              borderRadius: BorderRadius.circular(10),
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
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "This order is shown for your reference. Order details are read-only.",
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
  // SMALL UI COMPONENTS
  // ============================================================

  Widget _infoTile({
    required IconData icon,
    required String label,
    required dynamic value,
    bool multiline = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: muted,
              size: 16,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text(value),
                  textAlign: TextAlign.left,
                  maxLines: multiline ? 5 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink2,
                    fontSize: 12,
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

  Widget _subHeading(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _smallBadge(
    String label,
    Color color,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(14),
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
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SIMPLE TIMESTAMP COMPATIBILITY TYPE
// ============================================================
//
// Allows the screen to remain independent of Firebase imports.
// Firestore Timestamp values are also handled through toDate()
// in parseDate().
//
// ============================================================

class TimestampLike {
  final DateTime dateTime;

  const TimestampLike(
    this.dateTime,
  );
}