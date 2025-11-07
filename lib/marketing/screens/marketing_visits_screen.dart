import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../marketing/visits_service.dart';

class MarketingVisitsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const MarketingVisitsScreen({super.key, required this.userId, required this.userName});

  @override
  State<MarketingVisitsScreen> createState() => _MarketingVisitsScreenState();
}

class _MarketingVisitsScreenState extends State<MarketingVisitsScreen> {
  static const stages = ['planned','started','reached','done','cancelled'];

  final _svc = VisitsService();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _all = [];
  String _tab = 'planned';
  String _q = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _svc.streamUserVisits(widget.userId).listen((list) {
      setState(() { _all = list; loading = false; });
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    final list = _all.where((v) => (v['status'] ?? '') == _tab).toList();
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((v){
      final name = (v['customerName'] ?? '').toString().toLowerCase();
      final addr = (v['address'] ?? '').toString().toLowerCase();
      final phone = ((v['contact'] ?? {}) as Map)['phone']?.toString().toLowerCase() ?? '';
      return name.contains(q) || addr.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<Position?> _getPos(BuildContext ctx) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enable GPS'), backgroundColor: Colors.red));
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Location permission needed'), backgroundColor: Colors.red));
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _onStart(Map<String,dynamic> v) async {
    final pos = await _getPos(context);
    if (pos == null) return;
    await _svc.startVisit(
      visitId: v['id'],
      byUid: widget.userId,
      byName: widget.userName,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
    );
  }

  Future<void> _onReached(Map<String,dynamic> v) async {
    final pos = await _getPos(context);
    if (pos == null) return;
    await _svc.markReached(
      visitId: v['id'],
      byUid: widget.userId,
      byName: widget.userName,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      source: 'gps',
    );
  }

  Future<void> _onComplete(Map<String,dynamic> v) async {
    final noteCtrl = TextEditingController();
    bool createLead = true;
    String leadType = 'equipment_rental';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left:16,right:16,top:8,bottom:16+MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Complete visit', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:8),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Outcome / Notes'), maxLines: 3),
            const SizedBox(height:8),
            SwitchListTile(
              value: createLead, onChanged: (v)=>createLead=v, title: const Text('Create lead from this visit'),
            ),
            if (createLead) DropdownButtonFormField<String>(
              value: leadType,
              items: const [
                DropdownMenuItem(value: 'equipment_rental', child: Text('Equipment rental')),
                DropdownMenuItem(value: 'nursing_service', child: Text('Nursing service')),
              ],
              onChanged: (v){ if (v!=null) leadType=v; },
              decoration: const InputDecoration(labelText: 'Lead type'),
            ),
            const SizedBox(height:12),
            Row(children: [
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final note = noteCtrl.text.trim();
                  if (note.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter outcome note'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.pop(context);
                  await _svc.completeVisit(
                    visitId: v['id'],
                    byUid: widget.userId,
                    byName: widget.userName,
                    outcomeNote: note,
                    createLead: createLead,
                    leadType: leadType,
                    leadNeed: note,
                  );
                },
                child: const Text('Complete'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _onCancel(Map<String,dynamic> v) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel visit'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason'), maxLines: 2),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('No')),
          FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Yes')),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await _svc.cancelVisit(
      visitId: v['id'],
      byUid: widget.userId,
      byName: widget.userName,
      reason: ctrl.text.trim().isEmpty ? 'No reason' : ctrl.text.trim(),
    );
  }

  Future<void> _addVisit() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final addr = TextEditingController();
    final note = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left:16,right:16,top:8,bottom:16+MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add Visit', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:8),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')),
            const SizedBox(height:8),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height:8),
            TextField(controller: addr, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
            const SizedBox(height:8),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Purpose / Notes'), maxLines: 2),
            const SizedBox(height:12),
            Row(children: [
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name & phone required'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.pop(context);
                  await _svc.createVisit(
                    assignedToId: widget.userId,
                    assignedToName: widget.userName,
                    createdByUid: widget.userId,
                    createdByName: widget.userName,
                    customerName: name.text.trim(),
                    phone: phone.text.trim(),
                    address: addr.text.trim(),
                    purpose: note.text.trim(),
                  );
                },
                child: const Text('Create'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final grouped = {
      for (final s in stages) s: _all.where((v) => (v['status'] ?? '') == s).toList(),
    };
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Visits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVisit, icon: const Icon(Icons.add), label: const Text('Add Visit')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12,12,12,6),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search name/address/phone', border: OutlineInputBorder()),
            onChanged: (v)=>setState(()=>_q=v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: ['planned','started','reached','done','cancelled'].map((s){
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
           ? Center(child: Text('No ${_label(_tab).toLowerCase()} visits.'))
           : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __)=>const Divider(height:1),
              itemBuilder: (_, i){
                final v = items[i];
                final phone = ((v['contact'] ?? {}) as Map)['phone']?.toString() ?? '—';
                return ListTile(
                  title: Text((v['customerName'] ?? 'NA').toString()),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((v['address'] ?? '—').toString()),
                      const SizedBox(height:2),
                      Text('Phone: $phone', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: _Actions(
                    status: (v['status'] ?? '').toString(),
                    onStart: ()=>_onStart(v),
                    onReached: ()=>_onReached(v),
                    onComplete: ()=>_onComplete(v),
                    onCancel: ()=>_onCancel(v),
                  ),
                );
              },
            ),
        ),
      ]),
    );
  }

  String _label(String s){
    return {
      'planned':'Planned',
      'started':'Started',
      'reached':'Reached',
      'done':'Done',
      'cancelled':'Cancelled',
    }[s]!;
  }
}

class _Actions extends StatelessWidget {
  final String status;
  final VoidCallback onStart, onReached, onComplete, onCancel;
  const _Actions({
    required this.status,
    required this.onStart,
    required this.onReached,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'planned':
        return Wrap(spacing:6, children:[
          FilledButton(onPressed: onStart, child: const Text('Start')),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        ]);
      case 'started':
        return Wrap(spacing:6, children:[
          FilledButton(onPressed: onReached, child: const Text('Reached')),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        ]);
      case 'reached':
        return Wrap(spacing:6, children:[
          FilledButton(onPressed: onComplete, child: const Text('Complete')),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }
}
