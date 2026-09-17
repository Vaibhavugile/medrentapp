import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../leads_service.dart';
import 'equipment_order_details_screen.dart';
import 'nursing_order_details_screen.dart';

/// Premium, read-only Lead Details screen.
///
/// Relationship:
/// Lead
///  ├─ Requirements: requirements.where(leadId)
///  │    └─ Quotations: quotations.where(requirementId)
///  └─ Orders
///       ├─ Equipment: orders.where(leadId)
///       └─ Nursing/Caretaker: nursingOrders.where(leadId)
///             └─ Staff: staffAssignments.where(orderId)
class LeadDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> lead;

  const LeadDetailsScreen({
    super.key,
    required this.lead,
  });

  @override
  State<LeadDetailsScreen> createState() =>
      _LeadDetailsScreenState();
}

class _LeadDetailsScreenState extends State<LeadDetailsScreen> {
  final LeadsService _leadsService = LeadsService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _requirements = [];
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _orders = [];

  String get _leadId =>
      widget.lead['id']?.toString().trim() ?? '';

  String get _type =>
      widget.lead['type']?.toString().trim().toLowerCase() ?? '';

  bool get _isEquipment => _type == 'equipment';

  bool get _isNursing =>
      _type == 'nursing' || _type == 'caretaker';

  @override
  void initState() {
    super.initState();
    _loadRelatedData();
  }

  Future<void> _loadRelatedData() async {
    if (_leadId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Lead ID is missing.';
      });

      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _leadsService.getRequirements(_leadId),
        _leadsService.getLeadQuotations(_leadId),
        if (_isEquipment)
          _leadsService.getEquipmentOrders(_leadId)
        else if (_isNursing)
          _leadsService.getNursingOrders(_leadId)
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      setState(() {
        _requirements =
            results[0] as List<Map<String, dynamic>>;
        _quotations =
            results[1] as List<Map<String, dynamic>>;
        _orders =
            results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _refresh() async {
    await _loadRelatedData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lead = widget.lead;

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _AppColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _buildTopBar(context),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  6,
                  18,
                  34,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHero(context, lead),
                    const SizedBox(height: 18),
                    _buildQuickStats(),
                    const SizedBox(height: 22),
                    _buildSectionHeading(
                      'Customer information',
                      'Contact and lead details',
                      Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildCustomerCard(lead),
                    const SizedBox(height: 22),
                    _buildSectionHeading(
                      'Lead activity',
                      'Everything connected to this lead',
                      Icons.timeline_rounded,
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      _buildLoadingCard()
                    else if (_error != null)
                      _buildErrorCard()
                    else ...[
                      _buildActivityGrid(context),
                      const SizedBox(height: 18),
                      _buildActivitySummary(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          _circleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lead Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: _AppColors.text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Complete lead overview',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _circleButton(
            icon: Icons.refresh_rounded,
            onTap: _loading ? null : _refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    Map<String, dynamic> lead,
  ) {
    final name = _text(lead['customerName'], fallback: 'Customer');
    final type = _type.isEmpty
        ? 'Lead'
        : _type[0].toUpperCase() + _type.substring(1);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _AppColors.heroDark,
            _AppColors.heroLight,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _AppColors.primary.withOpacity(.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(.18),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _firstLetter(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Lead ID  •  ${_leadId.isEmpty ? '-' : _leadId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroPill(
                icon: Icons.circle,
                label: _text(
                  lead['status'],
                  fallback: 'New',
                ).toUpperCase(),
              ),
              _heroPill(
                icon: _typeIcon(),
                label: type.toUpperCase(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final items = [
      _StatItem(
        label: 'Requirements',
        value: _loading ? '—' : '${_requirements.length}',
        icon: Icons.assignment_outlined,
      ),
      _StatItem(
        label: 'Quotations',
        value: _loading ? '—' : '${_quotations.length}',
        icon: Icons.request_quote_outlined,
      ),
      _StatItem(
        label: _orderLabel,
        value: _loading ? '—' : '${_orders.length}',
        icon: Icons.shopping_bag_outlined,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(child: _statCard(items[i])),
          if (i != items.length - 1)
            const SizedBox(width: 9),
        ],
      ],
    );
  }

  Widget _statCard(_StatItem item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _AppColors.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: _AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _AppColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: _AppColors.primary,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _AppColors.text,
                  letterSpacing: -.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> lead) {
    final fields = <_InfoItem>[
      _InfoItem(
        icon: Icons.person_outline_rounded,
        label: 'Contact person',
        value: lead['contactPerson'],
      ),
      _InfoItem(
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: lead['phone'],
      ),
      _InfoItem(
        icon: Icons.email_outlined,
        label: 'Email',
        value: lead['email'],
      ),
      _InfoItem(
        icon: Icons.location_on_outlined,
        label: 'Address',
        value: lead['address'],
      ),
      _InfoItem(
        icon: Icons.campaign_outlined,
        label: 'Lead source',
        value: lead['leadSource'],
      ),
      _InfoItem(
        icon: Icons.person_add_alt_1_outlined,
        label: 'Created by',
        value: lead['createdByName'],
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        children: [
          for (int i = 0; i < fields.length; i++) ...[
            _infoRow(fields[i]),
            if (i != fields.length - 1)
              Divider(
                height: 22,
                color: _AppColors.divider,
              ),
          ],
          if (_hasValue(lead['notes'])) ...[
            Divider(
              height: 22,
              color: _AppColors.divider,
            ),
            _infoRow(
              _InfoItem(
                icon: Icons.notes_rounded,
                label: 'Notes',
                value: lead['notes'],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(_InfoItem item) {
    final value = _text(item.value);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.icon,
            size: 18,
            color: _AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: _AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityGrid(BuildContext context) {
    final cards = <Widget>[
      _activityCard(
        icon: Icons.assignment_outlined,
        title: 'Requirements',
        subtitle: _requirements.isEmpty
            ? 'No requirements yet'
            : '${_requirements.length} requirement${_requirements.length == 1 ? '' : 's'}',
        count: _requirements.length,
        color: _AppColors.indigo,
        onTap: _requirements.isEmpty
            ? null
            : () => _showRequirements(context),
      ),
      _activityCard(
        icon: Icons.request_quote_outlined,
        title: 'Quotations',
        subtitle: _quotations.isEmpty
            ? 'No quotations yet'
            : '${_quotations.length} quotation${_quotations.length == 1 ? '' : 's'}',
        count: _quotations.length,
        color: _AppColors.purple,
        onTap: _quotations.isEmpty
            ? null
            : () => _showQuotations(context),
      ),
      _activityCard(
        icon: Icons.shopping_bag_outlined,
        title: _orderLabel,
        subtitle: _orders.isEmpty
            ? 'No orders yet'
            : '${_orders.length} ${_orderLabel.toLowerCase()}',
        count: _orders.length,
        color: _AppColors.green,
        onTap: _orders.isEmpty
            ? null
            : () => _showOrders(context),
      ),
    ];

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 11),
        cards[1],
        const SizedBox(height: 11),
        cards[2],
      ],
    );
  }

  Widget _activityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: _AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(
                  minWidth: 40,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: enabled
                      ? color.withOpacity(.09)
                      : _AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: enabled
                        ? color
                        : _AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                enabled
                    ? Icons.chevron_right_rounded
                    : Icons.remove_rounded,
                color: enabled
                    ? _AppColors.textSoft
                    : _AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySummary() {
    final hasAny =
        _requirements.isNotEmpty ||
        _quotations.isNotEmpty ||
        _orders.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _AppColors.primarySoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _AppColors.primary.withOpacity(.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_outlined,
            color: _AppColors.primary,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              hasAny
                  ? 'All related information is loaded from the lead relationships and is available as read-only details.'
                  : 'There is no related requirement, quotation or order information for this lead yet.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: _AppColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: _cardDecoration(radius: 24),
      child: const Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: _AppColors.primary,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading related information',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _AppColors.text,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Requirements, quotations and orders',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _AppColors.error.withOpacity(.16),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _AppColors.error.withOpacity(.08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _AppColors.error,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load related information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: _AppColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
            style: FilledButton.styleFrom(
              backgroundColor: _AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUIREMENTS
  // ============================================================

  void _showRequirements(BuildContext context) {
    _showSheet(
      context,
      title: 'Requirements',
      subtitle:
          '${_requirements.length} requirement${_requirements.length == 1 ? '' : 's'}',
      icon: Icons.assignment_outlined,
      color: _AppColors.indigo,
      child: _requirements.isEmpty
          ? _sheetEmpty(
              Icons.assignment_outlined,
              'No requirements',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                28,
              ),
              itemCount: _requirements.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 11),
              itemBuilder: (_, index) {
                return _detailDataCard(
                  index: index + 1,
                  icon: Icons.assignment_outlined,
                  title: 'Requirement ${index + 1}',
                  data: _requirements[index],
                  color: _AppColors.indigo,
                );
              },
            ),
    );
  }

  // ============================================================
  // QUOTATIONS
  // ============================================================

  void _showQuotations(BuildContext context) {
    _showSheet(
      context,
      title: 'Quotations',
      subtitle:
          '${_quotations.length} quotation${_quotations.length == 1 ? '' : 's'}',
      icon: Icons.request_quote_outlined,
      color: _AppColors.purple,
      child: _quotations.isEmpty
          ? _sheetEmpty(
              Icons.request_quote_outlined,
              'No quotations',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                28,
              ),
              itemCount: _quotations.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 11),
              itemBuilder: (_, index) {
                final quotation = _quotations[index];

                return _detailDataCard(
                  index: index + 1,
                  icon: Icons.request_quote_outlined,
                  title: 'Quotation ${index + 1}',
                  data: quotation,
                  color: _AppColors.purple,
                );
              },
            ),
    );
  }

  // ============================================================
  // ORDERS
  // ============================================================

  void _showOrders(BuildContext context) {
    if (_orders.isEmpty) return;

    // One order: go directly to the proper premium detail screen.
    if (_orders.length == 1) {
      _openOrder(_orders.first);
      return;
    }

    // Multiple orders: let the user choose which order to inspect.
    _showSheet(
      context,
      title: _orderLabel,
      subtitle:
          'Select an order to view complete details',
      icon: Icons.shopping_bag_outlined,
      color: _AppColors.green,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          28,
        ),
        itemCount: _orders.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 11),
        itemBuilder: (_, index) {
          return _orderSelectorCard(
            context,
            order: _orders[index],
            index: index,
          );
        },
      ),
    );
  }

  Widget _orderSelectorCard(
    BuildContext context, {
    required Map<String, dynamic> order,
    required int index,
  }) {
    final orderNo = _orderNumber(order);
    final status = _text(
      order['status'],
      fallback: 'Pending',
    );

    final total = _money(
      _nested(order, 'totals', 'total'),
    );

    final serviceName = _orderPrimaryName(order);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () {
          Navigator.pop(context);
          _openOrder(order);
        },
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: _AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,
                decoration: BoxDecoration(
                  color: _AppColors.green.withOpacity(.09),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _AppColors.green,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _miniStatus(status),
                        if (total != '-') ...[
                          const SizedBox(width: 7),
                          Text(
                            total,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _AppColors.textSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: _AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openOrder(Map<String, dynamic> order) {
    if (!mounted) return;

    if (_isEquipment) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              EquipmentOrderDetailsScreen(order: order),
        ),
      );
      return;
    }

    if (_isNursing) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              NursingOrderDetailsScreen(order: order),
        ),
      );
      return;
    }
  }

  // ============================================================
  // GENERIC SHEET
  // ============================================================

  void _showSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * .84,
          decoration: const BoxDecoration(
            color: _AppColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: _AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  17,
                  10,
                  14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: color.withOpacity(.10),
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      child: Icon(
                        icon,
                        color: color,
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
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: _AppColors.divider,
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetEmpty(
    IconData icon,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                icon,
                size: 31,
                color: _AppColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _AppColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailDataCard({
    required int index,
    required IconData icon,
    required String title,
    required Map<String, dynamic> data,
    required Color color,
  }) {
    final visibleEntries = <MapEntry<String, dynamic>>[];

    for (final entry in data.entries) {
      if (entry.key.startsWith('_')) continue;
      if (entry.value == null) continue;

      final display = _displayValue(entry.value);

      if (display.trim().isEmpty ||
          display == 'null') {
        continue;
      }

      visibleEntries.add(entry);
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '#$index',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          if (visibleEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (int i = 0;
                i < visibleEntries.length;
                i++) ...[
              _compactDataRow(
                _prettyLabel(visibleEntries[i].key),
                _displayValue(visibleEntries[i].value),
              ),
              if (i != visibleEntries.length - 1)
                Divider(
                  height: 17,
                  color: _AppColors.divider,
                ),
            ],
          ] else ...[
            const SizedBox(height: 15),
            const Text(
              'No details available',
              style: TextStyle(
                fontSize: 12,
                color: _AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compactDataRow(
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: _AppColors.text,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  BoxDecoration _cardDecoration({
    double radius = 20,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: _AppColors.border,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 17,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? _AppColors.muted
                : _AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withOpacity(.13),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: Colors.white.withOpacity(.90),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatus(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'complete':
      case 'closed':
      case 'delivered':
        return _AppColors.green;
      case 'cancelled':
      case 'canceled':
      case 'lost':
        return _AppColors.error;
      case 'accepted':
      case 'assigned':
      case 'in_transit':
      case 'in transit':
        return _AppColors.blue;
      case 'pending':
      case 'new':
      default:
        return _AppColors.orange;
    }
  }

  IconData _typeIcon() {
    if (_isEquipment) {
      return Icons.medical_services_outlined;
    }

    if (_type == 'nursing') {
      return Icons.health_and_safety_outlined;
    }

    if (_type == 'caretaker') {
      return Icons.accessibility_new_rounded;
    }

    return Icons.category_outlined;
  }

  String get _orderLabel {
    if (_isEquipment) return 'Equipment Orders';
    if (_type == 'nursing') return 'Nursing Orders';
    if (_type == 'caretaker') return 'Caretaker Orders';
    return 'Orders';
  }

  String _orderNumber(Map<String, dynamic> order) {
    return _text(
      order['orderNo'],
      fallback: _text(
        order['id'],
        fallback: 'Order',
      ),
    );
  }

  String _orderPrimaryName(
    Map<String, dynamic> order,
  ) {
    final items = order['items'];

    if (items is List && items.isNotEmpty) {
      final names = <String>[];

      for (final item in items.take(2)) {
        if (item is Map) {
          final name =
              item['name'] ??
              item['productName'] ??
              item['serviceName'];

          if (name != null &&
              name.toString().trim().isNotEmpty) {
            names.add(name.toString().trim());
          }
        }
      }

      if (names.isNotEmpty) {
        final result = names.join(', ');

        if (items.length > 2) {
          return '$result + ${items.length - 2} more';
        }

        return result;
      }
    }

    return _isEquipment
        ? 'Equipment order'
        : _type == 'nursing'
            ? 'Nursing service order'
            : 'Caretaker service order';
  }

  dynamic _nested(
    Map<String, dynamic> map,
    String parent,
    String child,
  ) {
    final value = map[parent];

    if (value is Map) {
      return value[child];
    }

    return null;
  }

  String _money(dynamic value) {
    if (value == null) return '-';

    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return '₹${number.toStringAsFixed(2)}';
  }

  String _displayValue(dynamic value) {
    if (value == null) return '';

    if (value is DateTime) {
      return _formatDate(value);
    }

    if (value is Timestamp) {
      return _formatDate(value.toDate());
    }

    if (value is List) {
      if (value.isEmpty) return '';

      return value
          .map(_displayValue)
          .where((e) => e.trim().isNotEmpty)
          .join(', ');
    }

    if (value is Map) {
      final parts = <String>[];

      value.forEach((key, val) {
        if (val == null) return;

        final display = _displayValue(val);

        if (display.trim().isEmpty) return;

        parts.add(
          '${_prettyLabel(key.toString())}: $display',
        );
      });

      return parts.join('  •  ');
    }

    return value.toString();
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    return '$day/$month/$year';
  }

  String _text(
    dynamic value, {
    String fallback = '-',
  }) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  bool _hasValue(dynamic value) {
    return value != null &&
        value.toString().trim().isNotEmpty;
  }

  String _firstLetter(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return 'C';

    return trimmed.characters.first.toUpperCase();
  }

  String _prettyLabel(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) =>
          '${match.group(1)} ${match.group(2)}',
    );

    return spaced
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                '${word.substring(1)}',
        )
        .join(' ');
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('permission-denied')) {
      return 'You do not have permission to view some related information.';
    }

    return message.replaceFirst(
      'Exception: ',
      '',
    );
  }
}
class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _InfoItem {
  final IconData icon;
  final String label;
  final dynamic value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Fixed premium light palette.
/// This screen intentionally does not read tenant colors from Firebase.
class _AppColors {
  static const background = Color(0xfff6f8fc);
  static const surfaceAlt = Color(0xfff1f4f9);

  static const text = Color(0xff101828);
  static const textSoft = Color(0xff344054);
  static const muted = Color(0xff667085);

  static const border = Color(0xffe4e7ec);
  static const divider = Color(0xffedf0f4);

  static const primary = Color(0xff3157d5);
  static const primarySoft = Color(0xffeef2ff);

  static const heroDark = Color(0xff172554);
  static const heroLight = Color(0xff3157d5);

  static const indigo = Color(0xff4f46e5);
  static const purple = Color(0xff7c3aed);
  static const green = Color(0xff059669);
  static const blue = Color(0xff2563eb);
  static const orange = Color(0xffd97706);
  static const error = Color(0xffdc2626);
}
