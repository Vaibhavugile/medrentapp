import 'dart:async';
import 'package:flutter/material.dart';
import '../../marketing/leads_service.dart';

class LeadsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const LeadsScreen({super.key, required this.userId, required this.userName});

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

  // Add Lead form state
  final _customerCtrl = TextEditingController();
  final _contactCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _addrCtrl     = TextEditingController();
  final _sourceCtrl   = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _status = 'new';
  String _type   = 'equipment'; // equipment | nursing

  @override
  void initState() {
    super.initState();
    _sub = _svc.streamMyLeads(widget.userId).listen((list) {
      setState(() { _all = list; loading = false; });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _customerCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addrCtrl.dispose();
    _sourceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _all.where((l) => (l['status'] ?? '') == _tab).toList();
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((l){
      final t = [
        (l['customerName'] ?? '').toString().toLowerCase(),
        (l['contactPerson'] ?? '').toString().toLowerCase(),
        (l['phone'] ?? '').toString().toLowerCase(),
        (l['email'] ?? '').toString().toLowerCase(),
        (l['leadSource'] ?? '').toString().toLowerCase(),
        (l['notes'] ?? '').toString().toLowerCase(),
      ].join(' ');
      return t.contains(q);
    }).toList();
  }

Future<void> _addLeadSheet() async {
  _customerCtrl.clear();
  _contactCtrl.clear();
  _phoneCtrl.clear();
  _emailCtrl.clear();
  _addrCtrl.clear();
  _sourceCtrl.clear();
  _notesCtrl.clear();
  _status = 'new';
  _type = 'equipment';

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      final kb = MediaQuery.of(context).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: kb), // 🧠 keyboard padding
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Material(
              elevation: 6,
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SafeArea(
                top: false,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text('New Lead', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 8),

                    TextField(controller: _customerCtrl, decoration: const InputDecoration(labelText: 'Customer / Hospital *')),
                    const SizedBox(height: 8),
                    TextField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person *')),
                    const SizedBox(height: 8),
                    TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *')),
                    const SizedBox(height: 8),
                    TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 8),
                    TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Address / City')),
                    const SizedBox(height: 8),
                    TextField(controller: _sourceCtrl, decoration: const InputDecoration(labelText: 'Lead Source')),
                    const SizedBox(height: 8),
                    TextField(controller: _notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                    const SizedBox(height: 8),

                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('new')),
                          DropdownMenuItem(value: 'contacted', child: Text('contacted')),
                          DropdownMenuItem(value: 'qualified', child: Text('qualified')),
                          DropdownMenuItem(value: 'req shared', child: Text('req shared')),
                          DropdownMenuItem(value: 'converted', child: Text('converted')),
                          DropdownMenuItem(value: 'lost', child: Text('lost')),
                        ],
                        onChanged: (v){ if (v!=null) setState(()=>_status = v); },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
                          DropdownMenuItem(value: 'nursing', child: Text('Nursing')),
                        ],
                        onChanged: (v){ if (v!=null) setState(()=>_type = v); },
                      )),
                    ]),
                    const SizedBox(height: 16),

                    Row(children: [
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final cust = _customerCtrl.text.trim();
                          final cont = _contactCtrl.text.trim();
                          final ph   = _phoneCtrl.text.trim();
                          if (cust.isEmpty || cont.isEmpty || ph.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Customer, Contact, Phone are required'),
                                backgroundColor: Colors.red),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          try {
                            await _svc.createLeadDetailed(
                              ownerId: widget.userId,
                              ownerName: widget.userName,
                              customerName: cust,
                              contactPerson: cont,
                              phone: ph,
                              email: _emailCtrl.text.trim(),
                              address: _addrCtrl.text.trim(),
                              leadSource: _sourceCtrl.text.trim(),
                              notes: _notesCtrl.text.trim(),
                              status: _status,
                              type: _type,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lead created')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to create lead: $e'),
                                  backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        child: const Text('Create'),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  Future<void> _update(String id, String status) async {
    await _svc.updateStatus(
      leadId: id,
      newStatus: status,
      byUid: widget.userId,
      byName: widget.userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final grouped = {
      for (final s in ['new','contacted','qualified','req shared','converted','lost'])
        s: _all.where((l) => (l['status'] ?? '') == s).toList()
    };
    final items = _filtered;

    return Scaffold(
     resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Leads'),
        actions: [
          IconButton(
            tooltip: 'Add Lead',
            onPressed: _addLeadSheet,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLeadSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Lead'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12,12,12,6),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search by customer/contact/phone/source/notes',
              border: OutlineInputBorder(),
            ),
            onChanged: (v)=>setState(()=>_q=v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: ['new','contacted','qualified','req shared','converted','lost'].map((s){
              final isActive = _tab==s;
              final count = (grouped[s] ?? const []).length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  selected: isActive,
                  label: Text('${_label(s)}${count>0?' ($count)':''}'),
                  onSelected: (_)=>setState(()=>_tab=s),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: items.isEmpty
            ? Center(child: Text('No ${_label(_tab).toLowerCase()} leads.'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __)=>const Divider(height:1),
                itemBuilder: (_, i){
                  final l = items[i];
                  final type = (l['type'] ?? 'equipment').toString();
                  return ListTile(
                    title: Text((l['customerName'] ?? 'NA').toString()),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contact: ${(l['contactPerson'] ?? '—')}'
                            '${(l['email'] ?? '').toString().isNotEmpty ? ' · ${l['email']}' : ''}'),
                        const SizedBox(height: 2),
                        Text('Phone: ${(l['phone'] ?? '—')} · Source: ${(l['leadSource'] ?? '—')}'),
                        const SizedBox(height: 2),
                        Text('Type: ${type == 'nursing' ? 'Nursing' : 'Equipment'}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    trailing: _LeadActions(
                      status: (l['status'] ?? '').toString(),
                      onAdvance: () {
                        final next = _nextStatus((l['status'] ?? 'new').toString());
                        if (next == null) return;
                        _update(l['id'], next);
                      },
                    ),
                  );
                },
              ),
        ),
      ]),
    );
  }

  String _label(String s) => {
    'new':'New','contacted':'Contacted','qualified':'Qualified','req shared':'Req shared','converted':'Converted','lost':'Lost'
  }[s]!;

  String? _nextStatus(String cur) {
    const flow = ['new','contacted','qualified','req shared','converted'];
    final i = flow.indexOf(cur);
    if (i == -1) return null;
    if (i < flow.length - 1) return flow[i + 1];
    return null;
  }
}

class _LeadActions extends StatelessWidget {
  final String status;
  final VoidCallback onAdvance;
  const _LeadActions({required this.status, required this.onAdvance});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'new':
      case 'contacted':
      case 'qualified':
      case 'req shared':
        return FilledButton(onPressed: onAdvance, child: const Text('Next →'));
      default:
        return const SizedBox.shrink();
    }
  }
}
