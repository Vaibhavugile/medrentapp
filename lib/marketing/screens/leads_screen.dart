import 'dart:async';
import 'package:flutter/material.dart';
import '../../marketing/leads_service.dart';

class LeadsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const LeadsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _svc = LeadsService();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  List<Map<String, dynamic>> _all = [];

  String _q = '';
  String _tab = 'new';

  bool loading = true;

  final _customerCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _status = 'new';
  String _type = 'equipment';

  final statuses = [
    'new',
    'contacted',
    'req shared',
    'converted',
    'lost'
  ];

  @override
  void initState() {
    super.initState();

    _sub = _svc.streamMyLeads(widget.userId).listen((list) {
      setState(() {
        _all = list;
        loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _all.where((l) => (l['status'] ?? '') == _tab).toList();

    final q = _q.toLowerCase();

    if (q.isEmpty) return list;

    return list.where((l) {
      final text = [
        l['customerName'],
        l['contactPerson'],
        l['phone'],
        l['email'],
        l['leadSource'],
        l['notes']
      ].join(' ').toLowerCase();

      return text.contains(q);
    }).toList();
  }

  Future<void> _update(String id, String status) async {
    await _svc.updateStatus(
      leadId: id,
      newStatus: status,
      byUid: widget.userId,
      byName: widget.userName,
    );
  }

  Color _statusColor(String s) {
    final colors = {
      "new": Colors.blue,
      "contacted": Colors.orange,
      "req shared": Colors.indigo,
      "converted": Colors.green,
      "lost": Colors.red
    };

    return colors[s] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Leads"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text("Add Lead"),
      ),
      body: Column(
        children: [

          /// SEARCH
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search leads...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),

          /// STATUS TABS
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: statuses.map((s) {
                final active = _tab == s;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: active,
                    label: Text(_label(s)),
                    onSelected: (_) => setState(() => _tab = s),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          /// LEADS LIST
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("No leads"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {

                      final l = items[i];
                      final color = _statusColor(l['status']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 8,
                              offset: const Offset(0,3),
                            )
                          ],
                        ),
                        child: Row(
                          children: [

                            /// STATUS BAR
                            Container(
                              width: 4,
                              height: 95,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                ),
                              ),
                            ),

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    /// HEADER
                                    Row(
                                      children: [

                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              color.withOpacity(.15),
                                          child: Text(
                                            (l['customerName'] ?? 'C')[0]
                                                .toString()
                                                .toUpperCase(),
                                            style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),

                                        const SizedBox(width: 10),

                                        Expanded(
                                          child: Text(
                                            l['customerName'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15),
                                          ),
                                        ),

                                        _statusChip(l['status'])
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline,
                                            size: 16,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            l['contactPerson'] ?? '-',
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 3),

                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 16,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          l['phone'] ?? '-',
                                          style:
                                              const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 3),

                                    Row(
                                      children: [
                                        const Icon(Icons.campaign_outlined,
                                            size: 16,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            l['leadSource'] ?? '-',
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: _LeadActions(
                                        status: l['status'],
                                        onAdvance: () {
                                          final next =
                                              _nextStatus(l['status'] ?? 'new');

                                          if (next != null) {
                                            _update(l['id'], next);
                                          }
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _statusChip(String s) {
    final color = _statusColor(s);

    return Chip(
      label: Text(_label(s)),
      backgroundColor: color.withOpacity(.15),
    );
  }

  String _label(String s) => {
        'new': 'New',
        'contacted': 'Contacted',
        'req shared': 'Req Shared',
        'converted': 'Converted',
        'lost': 'Lost'
      }[s]!;

  String? _nextStatus(String cur) {
    const flow = ['new', 'contacted', 'req shared', 'converted'];

    final i = flow.indexOf(cur);

    if (i == -1) return null;

    if (i < flow.length - 1) {
      return flow[i + 1];
    }

    return null;
  }
}

class _LeadActions extends StatelessWidget {
  final String status;
  final VoidCallback onAdvance;

  const _LeadActions({
    required this.status,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'new':
      case 'contacted':
      case 'req shared':
        return FilledButton(
          onPressed: onAdvance,
          child: const Text("Next →"),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}