import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Monthly marketing performance screen.
///
/// IMPORTANT:
/// - Does NOT use daily_stats.
/// - Leads are included when either:
///     1. ownerId/createdBy == userId, OR
///     2. leadSource is one of the marketing user's connected source labels.
/// - A lead matching both conditions is counted only once.
/// - Monthly totals are calculated from the real Firestore documents.
class TodayScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const TodayScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const Color background = Color(0xFFF6F8FC);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF1F4F9);
  static const Color text = Color(0xFF101828);
  static const Color textSoft = Color(0xFF344054);
  static const Color muted = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);
  static const Color primary = Color(0xFF3157D5);
  static const Color primarySoft = Color(0xFFEEF2FF);
  static const Color heroDark = Color(0xFF172554);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color purple = Color(0xFF7C3AED);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF3);
  static const Color blue = Color(0xFF2563EB);
  static const Color orange = Color(0xFFD97706);
  static const Color red = Color(0xFFDC2626);

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;
  _MonthlyReport? _report;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  DateTime _monthStart(DateTime month) => DateTime(month.year, month.month, 1);
  DateTime _nextMonth(DateTime month) => DateTime(month.year, month.month + 1, 1);

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final db = FirebaseFirestore.instance;
      final start = _monthStart(_selectedMonth);
      final end = _nextMonth(_selectedMonth);

      // ------------------------------------------------------------
      // 1. Resolve the marketing person's connected source labels.
      // ------------------------------------------------------------
      final sourceNames = await _getConnectedSourceNames(db, widget.userId);

      // ------------------------------------------------------------
      // 2. Load monthly leads through BOTH attribution paths:
      //    A) created/owned by person
      //    B) connected source label
      // ------------------------------------------------------------
      final ownLeads = await _getLeadsByOwner(db, widget.userId, start, end);
      final sourceLeads = await _getLeadsBySources(db, sourceNames, start, end);

      // Merge by document ID => no double counting when a lead is both
      // created by the person and belongs to one of their source labels.
      final merged = <String, Map<String, dynamic>>{};
      final createdOnly = <String, Map<String, dynamic>>{};
      final sourceOnly = <String, Map<String, dynamic>>{};
      final both = <String, Map<String, dynamic>>{};

      for (final lead in ownLeads) {
        final id = lead['id']?.toString();
        if (id == null || id.isEmpty) continue;
        merged[id] = lead;
        createdOnly[id] = lead;
      }

      for (final lead in sourceLeads) {
        final id = lead['id']?.toString();
        if (id == null || id.isEmpty) continue;

        if (merged.containsKey(id)) {
          both[id] = lead;
          createdOnly.remove(id);
        } else {
          merged[id] = lead;
          sourceOnly[id] = lead;
        }
      }

      // ------------------------------------------------------------
      // 3. Load downstream CRM records for these unique leads.
      // ------------------------------------------------------------
      final leadIds = merged.keys.toList();
      final requirements = await _getRequirements(db, leadIds);
      final requirementIds = requirements.map((e) => e['id'].toString()).toSet().toList();
      final quotations = await _getQuotations(db, requirementIds);
      final orders = await _getOrders(db, leadIds);

      final report = _buildReport(
        leads: merged.values.toList(),
        createdOnly: createdOnly.values.toList(),
        sourceOnly: sourceOnly.values.toList(),
        both: both.values.toList(),
        requirements: requirements,
        quotations: quotations,
        orders: orders,
        sourceNames: sourceNames,
      );

      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ================================================================
  // MARKETING / SOURCE RESOLUTION
  // ================================================================

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findMarketingUser(
    FirebaseFirestore db,
    String userId,
  ) async {
    final direct = await db.collection('marketing').doc(userId).get();
    if (direct.exists) return direct;

    final byAuth = await db
        .collection('marketing')
        .where('authUid', isEqualTo: userId)
        .limit(1)
        .get();
    if (byAuth.docs.isNotEmpty) return byAuth.docs.first;

    final byUid = await db
        .collection('marketing')
        .where('uid', isEqualTo: userId)
        .limit(1)
        .get();
    if (byUid.docs.isNotEmpty) return byUid.docs.first;

    return null;
  }

  Future<List<String>> _getConnectedSourceNames(
    FirebaseFirestore db,
    String userId,
  ) async {
    final marketing = await _findMarketingUser(db, userId);
    if (marketing == null || !marketing.exists) return [];

    final data = marketing.data();
    final raw = data?['sourceLabels'];
    if (raw is! List) return [];

    final ids = raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final names = <String>[];
    for (final id in ids) {
      try {
        final doc = await db.collection('leadSources').doc(id).get();
        if (!doc.exists) continue;
        final name = doc.data()?['name']?.toString().trim();
        if (name != null && name.isNotEmpty) names.add(name);
      } catch (_) {}
    }

    return names.toSet().toList();
  }

  // ================================================================
  // LEADS
  // ================================================================

  Future<List<Map<String, dynamic>>> _getLeadsByOwner(
    FirebaseFirestore db,
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final snap = await db
        .collection('leads')
        .where('ownerId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: _ts(start))
        .where('createdAt', isLessThan: _ts(end))
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _getLeadsBySources(
    FirebaseFirestore db,
    List<String> sourceNames,
    DateTime start,
    DateTime end,
  ) async {
    if (sourceNames.isEmpty) return [];

    final result = <String, Map<String, dynamic>>{};

    for (var i = 0; i < sourceNames.length; i += 30) {
      final endIndex = (i + 30 < sourceNames.length) ? i + 30 : sourceNames.length;
      final chunk = sourceNames.sublist(i, endIndex);

      final snap = await db
          .collection('leads')
          .where('leadSource', whereIn: chunk)
          .where('createdAt', isGreaterThanOrEqualTo: _ts(start))
          .where('createdAt', isLessThan: _ts(end))
          .get();

      for (final d in snap.docs) {
        result[d.id] = {'id': d.id, ...d.data()};
      }
    }

    return result.values.toList();
  }

  // ================================================================
  // REQUIREMENTS / QUOTATIONS / ORDERS
  // ================================================================

  Future<List<Map<String, dynamic>>> _getRequirements(
    FirebaseFirestore db,
    List<String> leadIds,
  ) async {
    if (leadIds.isEmpty) return [];

    final result = <String, Map<String, dynamic>>{};

    for (var i = 0; i < leadIds.length; i += 30) {
      final endIndex = (i + 30 < leadIds.length) ? i + 30 : leadIds.length;
      final chunk = leadIds.sublist(i, endIndex);

      final snap = await db
          .collection('requirements')
          .where('leadId', whereIn: chunk)
          .get();

      for (final d in snap.docs) {
        result[d.id] = {'id': d.id, ...d.data()};
      }
    }

    return result.values.toList();
  }

  Future<List<Map<String, dynamic>>> _getQuotations(
    FirebaseFirestore db,
    List<String> requirementIds,
  ) async {
    if (requirementIds.isEmpty) return [];

    final result = <String, Map<String, dynamic>>{};

    for (var i = 0; i < requirementIds.length; i += 30) {
      final endIndex = (i + 30 < requirementIds.length) ? i + 30 : requirementIds.length;
      final chunk = requirementIds.sublist(i, endIndex);

      final snap = await db
          .collection('quotations')
          .where('requirementId', whereIn: chunk)
          .get();

      for (final d in snap.docs) {
        result[d.id] = {'id': d.id, ...d.data()};
      }
    }

    return result.values.toList();
  }

  Future<List<Map<String, dynamic>>> _getOrders(
    FirebaseFirestore db,
    List<String> leadIds,
  ) async {
    if (leadIds.isEmpty) return [];

    final result = <String, Map<String, dynamic>>{};

    for (var i = 0; i < leadIds.length; i += 30) {
      final endIndex = (i + 30 < leadIds.length) ? i + 30 : leadIds.length;
      final chunk = leadIds.sublist(i, endIndex);

      final equipment = await db
          .collection('orders')
          .where('leadId', whereIn: chunk)
          .get();

      for (final d in equipment.docs) {
        result['equipment_${d.id}'] = {
          'id': d.id,
          '_collection': 'orders',
          ...d.data(),
        };
      }

      final nursing = await db
          .collection('nursingOrders')
          .where('leadId', whereIn: chunk)
          .get();

      for (final d in nursing.docs) {
        result['nursing_${d.id}'] = {
          'id': d.id,
          '_collection': 'nursingOrders',
          ...d.data(),
        };
      }
    }

    return result.values.toList();
  }

  // ================================================================
  // REPORT CALCULATION
  // ================================================================

  _MonthlyReport _buildReport({
    required List<Map<String, dynamic>> leads,
    required List<Map<String, dynamic>> createdOnly,
    required List<Map<String, dynamic>> sourceOnly,
    required List<Map<String, dynamic>> both,
    required List<Map<String, dynamic>> requirements,
    required List<Map<String, dynamic>> quotations,
    required List<Map<String, dynamic>> orders,
    required List<String> sourceNames,
  }) {
    final leadIds = leads.map((e) => e['id'].toString()).toSet();

    final requirementsByLead = <String, List<Map<String, dynamic>>>{};
    for (final r in requirements) {
      final id = r['leadId']?.toString();
      if (id != null && id.isNotEmpty) {
        requirementsByLead.putIfAbsent(id, () => []).add(r);
      }
    }

    final reqIdsByLead = <String, Set<String>>{};
    for (final r in requirements) {
      final leadId = r['leadId']?.toString();
      final reqId = r['id']?.toString();
      if (leadId == null || reqId == null) continue;
      reqIdsByLead.putIfAbsent(leadId, () => {}).add(reqId);
    }

    final quotesByLead = <String, List<Map<String, dynamic>>>{};
    for (final q in quotations) {
      final reqId = q['requirementId']?.toString();
      if (reqId == null) continue;

      for (final entry in reqIdsByLead.entries) {
        if (entry.value.contains(reqId)) {
          quotesByLead.putIfAbsent(entry.key, () => []).add(q);
          break;
        }
      }
    }

    final ordersByLead = <String, List<Map<String, dynamic>>>{};
    for (final o in orders) {
      final leadId = o['leadId']?.toString();
      if (leadId != null && leadIds.contains(leadId)) {
        ordersByLead.putIfAbsent(leadId, () => []).add(o);
      }
    }

    int acceptedQuotes = 0;
    double business = 0;

    for (final q in quotations) {
      final status = _status(q).toLowerCase();
      if (status == 'accepted' || status == 'order_created' || status == 'order created') {
        acceptedQuotes++;
      }
    }

    // Business is taken from actual order records first.
    for (final order in orders) {
      business += _businessAmount(order);
    }

    // If there are no order amounts, use accepted quotation totals as the
    // fallback. This keeps the report useful with existing data structures.
    if (business == 0) {
      for (final q in quotations) {
        final status = _status(q).toLowerCase();
        if (status == 'accepted' || status == 'order_created' || status == 'order created') {
          business += _quotationAmount(q);
        }
      }
    }

    final sourceStats = <String, _SourcePerformance>{};
    for (final source in sourceNames) {
      sourceStats[source] = _SourcePerformance(source);
    }

    for (final lead in leads) {
      final source = _leadSource(lead);
      if (source.isEmpty) continue;
      final stat = sourceStats.putIfAbsent(source, () => _SourcePerformance(source));

      stat.leads++;
      final leadId = lead['id'].toString();
      stat.requirements += requirementsByLead[leadId]?.length ?? 0;
      stat.quotations += quotesByLead[leadId]?.length ?? 0;
      stat.orders += ordersByLead[leadId]?.length ?? 0;

      for (final order in ordersByLead[leadId] ?? const []) {
        stat.business += _businessAmount(order);
      }
    }

    // If an order does not have an amount, source business remains 0 rather
    // than inventing a value.
    final createdStats = _AttributionStats('Created By Me');
    final sourceOnlyStats = _AttributionStats('Source Connected');
    final bothStats = _AttributionStats('Both');

    void fill(_AttributionStats stat, List<Map<String, dynamic>> list) {
      stat.leads = list.length;
      for (final lead in list) {
        final id = lead['id'].toString();
        stat.requirements += requirementsByLead[id]?.length ?? 0;
        stat.quotations += quotesByLead[id]?.length ?? 0;
        stat.orders += ordersByLead[id]?.length ?? 0;
        for (final o in ordersByLead[id] ?? const []) {
          stat.business += _businessAmount(o);
        }
      }
    }

    fill(createdStats, createdOnly);
    fill(sourceOnlyStats, sourceOnly);
    fill(bothStats, both);

    final daily = <int, int>{};
    for (final lead in leads) {
      final d = _dateFrom(lead['createdAt']);
      if (d == null) continue;
      daily[d.day] = (daily[d.day] ?? 0) + 1;
    }

    return _MonthlyReport(
      leads: leads.length,
      createdByMe: createdOnly.length + both.length,
      sourceConnected: sourceOnly.length + both.length,
      createdOnly: createdOnly.length,
      sourceOnly: sourceOnly.length,
      both: both.length,
      requirements: requirements.length,
      quotations: quotations.length,
      acceptedQuotations: acceptedQuotes,
      orders: orders.length,
      business: business,
      sourceStats: sourceStats.values.toList()..sort((a, b) => b.leads.compareTo(a.leads)),
      attribution: [createdStats, sourceOnlyStats, bothStats],
      dailyLeads: daily,
      daysInMonth: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day,
    );
  }

  String _leadSource(Map<String, dynamic> lead) =>
      (lead['leadSource'] ?? '').toString().trim();

  String _status(Map<String, dynamic> data) =>
      (data['status'] ?? '').toString().trim();

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '').replaceAll('₹', '').trim()) ?? 0;
  }

  double _businessAmount(Map<String, dynamic> data) {
    const keys = [
      'finalAmount',
      'totalAmount',
      'grandTotal',
      'orderTotal',
      'total',
      'amount',
      'netAmount',
      'payableAmount',
      'final_amount',
      'total_amount',
      'grand_total',
      'order_value',
      'orderValue',
      'businessGenerated',
      'business_generated',
      'businessAmount',
      'business_amount',
    ];

    for (final key in keys) {
      if (data.containsKey(key)) {
        final n = _number(data[key]);
        if (n != 0) return n;
      }
    }

    return 0;
  }

  double _quotationAmount(Map<String, dynamic> data) {
    const keys = [
      'finalAmount',
      'totalAmount',
      'grandTotal',
      'total',
      'amount',
      'netAmount',
      'payableAmount',
      'final_amount',
      'total_amount',
      'grand_total',
    ];

    for (final key in keys) {
      if (data.containsKey(key)) {
        final n = _number(data[key]);
        if (n != 0) return n;
      }
    }

    return 0;
  }

  // ================================================================
  // UI
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHero()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                          sliver: SliverToBoxAdapter(child: _buildContent()),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHero() {
    final r = _report!;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [heroDark, primary, indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    widget.userName.isEmpty ? 'M' : widget.userName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MARKETING PERFORMANCE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .9)),
                    const SizedBox(height: 3),
                    Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showMonthPicker,
                icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(_monthLabel(_selectedMonth), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Created By + Connected Source Label', style: TextStyle(color: Colors.white.withOpacity(.70), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _heroMetric('UNIQUE LEADS', '${r.leads}')),
              const SizedBox(width: 8),
              Expanded(child: _heroMetric('ORDERS', '${r.orders}')),
              const SizedBox(width: 8),
              Expanded(child: _heroMetric('BUSINESS', _money(r.business))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 8, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildContent() {
    final r = _report!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Overview', 'Actual CRM records for this month', Icons.insights_rounded),
        const SizedBox(height: 12),
        _buildKpis(r),
        const SizedBox(height: 24),
        _section('Lead Attribution', 'Created By and Source Label are combined without duplicate counting', Icons.merge_type_rounded),
        const SizedBox(height: 12),
        _buildAttribution(r),
        const SizedBox(height: 24),
        _section('Source Performance', 'Leads, requirements, quotations, orders and business by source', Icons.source_rounded),
        const SizedBox(height: 12),
        _buildSources(r),
        const SizedBox(height: 24),
        _section('Monthly Lead Trend', 'Unique leads received each day', Icons.show_chart_rounded),
        const SizedBox(height: 12),
        _buildDailyTrend(r),
        const SizedBox(height: 24),
        _section('CRM Funnel', 'How the leads progressed through your CRM', Icons.filter_alt_rounded),
        const SizedBox(height: 12),
        _buildFunnel(r),
      ],
    );
  }

  Widget _buildKpis(_MonthlyReport r) {
    return LayoutBuilder(builder: (_, c) {
      final width = c.maxWidth > 700 ? (c.maxWidth - 36) / 4 : (c.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: width, child: _metric('Unique Leads', '${r.leads}', Icons.people_alt_rounded, primary)),
        SizedBox(width: width, child: _metric('Requirements', '${r.requirements}', Icons.assignment_rounded, blue)),
        SizedBox(width: width, child: _metric('Quotations', '${r.quotations}', Icons.request_quote_rounded, orange)),
        SizedBox(width: width, child: _metric('Orders', '${r.orders}', Icons.receipt_long_rounded, purple)),
        SizedBox(width: width, child: _metric('Accepted Quotes', '${r.acceptedQuotations}', Icons.check_circle_rounded, green)),
        SizedBox(width: width, child: _metric('Business', _money(r.business), Icons.currency_rupee_rounded, green)),
        SizedBox(width: width, child: _metric('Created By Me', '${r.createdByMe}', Icons.person_add_alt_1_rounded, indigo)),
        SizedBox(width: width, child: _metric('Source Connected', '${r.sourceConnected}', Icons.link_rounded, purple)),
      ]);
    });
  }

  Widget _metric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: textSoft, fontSize: 10, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _buildAttribution(_MonthlyReport r) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _card(),
      child: Column(children: [
        _attributeRow('Created by me only', r.createdOnly, r.leads, primary, Icons.person_rounded),
        const SizedBox(height: 12),
        _attributeRow('Source connected only', r.sourceOnly, r.leads, purple, Icons.source_rounded),
        const SizedBox(height: 12),
        _attributeRow('Both Created + Source', r.both, r.leads, orange, Icons.merge_type_rounded),
        const Divider(height: 28),
        Row(children: [
          const Expanded(child: Text('Unique leads counted', style: TextStyle(color: textSoft, fontSize: 12, fontWeight: FontWeight.w700))),
          Text('${r.leads}', style: const TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }

  Widget _attributeRow(String label, int value, int total, Color color, IconData icon) {
    final progress = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 17)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, style: const TextStyle(color: textSoft, fontSize: 11, fontWeight: FontWeight.w700))), Text('$value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: surfaceAlt, valueColor: AlwaysStoppedAnimation<Color>(color))),
      ])),
    ]);
  }

  Widget _buildSources(_MonthlyReport r) {
    if (r.sourceStats.isEmpty) {
      return _emptyCard('No connected source leads found for this month.');
    }

    return Container(
      decoration: _card(),
      child: Column(children: [
        for (int i = 0; i < r.sourceStats.length; i++) ...[
          _sourceRow(r.sourceStats[i], r.leads),
          if (i != r.sourceStats.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ]),
    );
  }

  Widget _sourceRow(_SourcePerformance s, int totalLeads) {
    final progress = totalLeads == 0 ? 0.0 : (s.leads / totalLeads).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: primarySoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.source_rounded, color: primary, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(s.source, style: const TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w800))),
          Text('${s.leads} leads', style: const TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: surfaceAlt, valueColor: const AlwaysStoppedAnimation<Color>(primary))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 7, children: [
          _miniPill('Req', s.requirements, blue),
          _miniPill('Quotes', s.quotations, orange),
          _miniPill('Orders', s.orders, purple),
          _miniPill('Business', _money(s.business), green),
        ]),
      ]),
    );
  }

  Widget _miniPill(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(.12))),
      child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label  ', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        TextSpan(text: '$value', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
      ])),
    );
  }

  Widget _buildDailyTrend(_MonthlyReport r) {
    final max = r.dailyLeads.values.isEmpty ? 1 : r.dailyLeads.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _card(),
      child: Column(children: [
        SizedBox(
          height: 180,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (int day = 1; day <= r.daysInMonth; day++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if ((r.dailyLeads[day] ?? 0) > 0)
                      Text('${r.dailyLeads[day]}', style: const TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Container(
                      height: ((r.dailyLeads[day] ?? 0) / max) * 125 + ((r.dailyLeads[day] ?? 0) > 0 ? 4 : 2),
                      decoration: BoxDecoration(color: primary.withOpacity((r.dailyLeads[day] ?? 0) > 0 ? .85 : .08), borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
                    ),
                    const SizedBox(height: 5),
                    Text('$day', style: const TextStyle(color: muted, fontSize: 7)),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFunnel(_MonthlyReport r) {
    final items = [
      ['Leads', r.leads, primary, Icons.people_alt_rounded],
      ['Requirements', r.requirements, blue, Icons.assignment_rounded],
      ['Quotations', r.quotations, orange, Icons.request_quote_rounded],
      ['Accepted', r.acceptedQuotations, green, Icons.check_circle_rounded],
      ['Orders', r.orders, purple, Icons.receipt_long_rounded],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: (items[i][2] as Color).withOpacity(.10), borderRadius: BorderRadius.circular(11)), child: Icon(items[i][3] as IconData, color: items[i][2] as Color, size: 17)),
            const SizedBox(width: 11),
            Expanded(child: Text(items[i][0] as String, style: const TextStyle(color: textSoft, fontSize: 12, fontWeight: FontWeight.w700))),
            Text('${items[i][1]}', style: const TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900)),
          ]),
          if (i != items.length - 1) const Padding(padding: EdgeInsets.only(left: 17, top: 4, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: SizedBox(height: 16, child: VerticalDivider(width: 1, color: border))),),
        ],
      ],
      ),
    );
  }

  Widget _section(String title, String subtitle, IconData icon) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primary, size: 20)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w500)),
      ])),
    ]);
  }

  Widget _emptyCard(String message) => Container(width: double.infinity, padding: const EdgeInsets.all(25), decoration: _card(), child: Center(child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 11))));

  BoxDecoration _card() => BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 18, offset: const Offset(0, 6))]);

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: _card(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: red, size: 42),
            const SizedBox(height: 12),
            const Text('Unable to load report', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _loadReport, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ]),
        ),
      ),
    );
  }

  Future<void> _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      helpText: 'Select any date in the month',
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });

    await _loadReport();
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _money(double value) {
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(2)} L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }
}

class _MonthlyReport {
  final int leads;
  final int createdByMe;
  final int sourceConnected;
  final int createdOnly;
  final int sourceOnly;
  final int both;
  final int requirements;
  final int quotations;
  final int acceptedQuotations;
  final int orders;
  final double business;
  final List<_SourcePerformance> sourceStats;
  final List<_AttributionStats> attribution;
  final Map<int, int> dailyLeads;
  final int daysInMonth;

  const _MonthlyReport({
    required this.leads,
    required this.createdByMe,
    required this.sourceConnected,
    required this.createdOnly,
    required this.sourceOnly,
    required this.both,
    required this.requirements,
    required this.quotations,
    required this.acceptedQuotations,
    required this.orders,
    required this.business,
    required this.sourceStats,
    required this.attribution,
    required this.dailyLeads,
    required this.daysInMonth,
  });
}

class _AttributionStats {
  final String label;
  int leads = 0;
  int requirements = 0;
  int quotations = 0;
  int orders = 0;
  double business = 0;

  _AttributionStats(this.label);
}

class _SourcePerformance {
  final String source;
  int leads = 0;
  int requirements = 0;
  int quotations = 0;
  int orders = 0;
  double business = 0;

  _SourcePerformance(this.source);
}
