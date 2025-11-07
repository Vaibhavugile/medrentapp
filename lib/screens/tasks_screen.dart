import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/delivery_service.dart';
import '../services/inventory_service.dart';

class TasksScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  const TasksScreen({super.key, required this.driverId, required this.driverName});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _svc = DeliveryService();
  final _inv = InventoryService();
  final _auth = FirebaseAuth.instance;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _all = [];
  String _query = '';
  String _tab = DeliveryService.stages.first;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _svc.streamDriverDeliveries(widget.driverId).listen((list) {
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
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((d) {
      final o = (d['order'] ?? {}) as Map<String, dynamic>;
      final text = [
        o['customerName'],
        o['orderNo'],
        o['deliveryAddress'] ?? o['address'] ?? o['dropAddress'] ?? d['address'],
      ].where((e) => e != null).join(' ').toString().toLowerCase();
      return text.contains(q);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final init = {
      for (final s in DeliveryService.stages) s: <Map<String, dynamic>>[],
      'other': <Map<String, dynamic>>[],
    };
    for (final d in _filtered) {
      final o = (d['order'] ?? {}) as Map<String, dynamic>;
      final s = ((d['status'] ?? o['deliveryStatus'] ?? 'assigned').toString().toLowerCase());
      (init[s] ?? init['other']!) .add(d);
    }
    return init;
  }

  Future<void> _updateStage(String deliveryId, String stage) async {
    await _svc.updateStage(
      deliveryId: deliveryId,
      newStage: stage,
      driverName: widget.driverName,
      byUid: _auth.currentUser?.uid,
    );
  }

  void _openDetails(Map<String, dynamic> d) {
    final o = (d['order'] ?? {}) as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivery Details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                title: Text(o['customerName']?.toString() ?? 'NA', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  (o['deliveryAddress'] ?? o['address'] ?? o['dropAddress'] ?? d['address'] ?? 'NA').toString(),
                ),
              ),
              if (o['items'] is List && (o['items'] as List).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ...((o['items'] as List).map((it) {
                  final name = (it['name'] ?? 'Item').toString();
                  final qty = (it['qty'] ?? '1').toString();
                  final branch = it['branchId'];
                  return Text('$name × $qty${branch != null ? ' · branch: $branch' : ''}');
                })),
              ],
              const SizedBox(height: 12),
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...(((d['combinedHistory'] ?? const []) as List).reversed.map((h) {
                final stage = (h['stage'] ?? h['note'] ?? '').toString();
                final at = h['at'];
                String when;
                if (at is Timestamp) {
                  when = at.toDate().toLocal().toString();
                } else if (at is String) {
                  when = DateTime.tryParse(at)?.toLocal().toString() ?? '—';
                } else if (at is int) {
                  when = DateTime.fromMillisecondsSinceEpoch(at).toLocal().toString();
                } else {
                  when = '—';
                }
                final by = (h['by'] ?? '').toString();
                return ListTile(
                  dense: true,
                  title: Text(stage),
                  subtitle: Text('${when}${by.isNotEmpty ? ' • by $by' : ''}'),
                );
              })),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }

  void _startPickup(Map<String, dynamic> delivery) async {
    final expected = await _svc.loadExpectedAssets(delivery); // [{assetDocId, assetId, itemName}]
    if (expected.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assets to pickup (already out or none assigned).')),
      );
      return;
    }

    final scanned = <String, bool>{}; // assetId -> true
    bool confirming = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          void onScan(String payload) {
            final ids = expected.map((e) => e['assetId']!).toSet();
            String? hit = ids.contains(payload)
                ? payload
                : ids.firstWhere((id) => payload.contains(id), orElse: () => '');
            if (hit != null && hit.isNotEmpty) {
              scanned[hit] = true;
              setSheetState(() {});
            }
          }

          Future<void> onConfirm() async {
            if (confirming) return;
            setSheetState(() => confirming = true);
            try {
              final toCheckout = expected
                  .where((e) => scanned[e['assetId']!] == true)
                  .map((e) => e['assetDocId']!)
                  .toList();

              for (final assetDocId in toCheckout) {
                await _inv.checkoutAsset(assetDocId, note: 'Checked out at pickup by driver');
              }
              await _updateStage(delivery['id'].toString(), 'in_transit');
              if (mounted) Navigator.pop(ctx);
            } finally {
              setSheetState(() => confirming = false);
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Scan assets for pickup', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(
                        onDetect: (capture) {
                          for (final b in capture.barcodes) {
                            final raw = (b.rawValue ?? '').trim();
                            if (raw.isNotEmpty) onScan(raw);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Expected', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: expected.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = expected[i];
                          final ok = scanned[e['assetId']!] == true;
                          return ListTile(
                            dense: true,
                            leading: Icon(ok ? Icons.check_circle : Icons.qr_code_2),
                            title: Text('${e['itemName']} • ${e['assetId']}'),
                            trailing: Text(ok ? 'Scanned' : 'Pending', style: TextStyle(
                              color: ok ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w600,
                            )),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: confirming ? null : onConfirm,
                          child: Text(confirming ? 'Processing…' : 'Confirm pickup & start'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final grouped = _grouped;
    final items = grouped[_tab] ?? const <Map<String, dynamic>>[];

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search address, order no, customer…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        // Tabs
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: DeliveryService.stages.map((s) {
              final isActive = _tab == s;
              final count = (grouped[s] ?? const []).length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  selected: isActive,
                  label: Text('${DeliveryService.label(s)}${count > 0 ? ' ($count)' : ''}'),
                  onSelected: (_) => setState(() => _tab = s),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 6),

        // List
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('No ${DeliveryService.label(_tab).toLowerCase()} tasks.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    final o = (d['order'] ?? {}) as Map<String, dynamic>;
                    final status = ((d['status'] ?? o['deliveryStatus'] ?? 'assigned').toString().toLowerCase());
                    final address = (o['deliveryAddress'] ?? o['address'] ?? o['dropAddress'] ?? d['address'] ?? 'NA').toString();

                    return ListTile(
                      onTap: () => _openDetails(d),
                      title: Text((o['customerName'] ?? 'NA').toString()),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(address),
                          const SizedBox(height: 2),
                          Text('Order: ${(o['orderNo'] ?? d['orderId'] ?? d['id']).toString()}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: _Actions(
                        status: status,
                        onAccept: () => _updateStage(d['id'].toString(), 'accepted'),
                        onReject: () => _updateStage(d['id'].toString(), 'rejected'),
                        onStartPickup: () => _startPickup(d),
                        onDelivered: () => _updateStage(d['id'].toString(), 'delivered'),
                        onComplete: () => _updateStage(d['id'].toString(), 'completed'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final String status;
  final VoidCallback onAccept, onReject, onStartPickup, onDelivered, onComplete;
  const _Actions({
    required this.status,
    required this.onAccept,
    required this.onReject,
    required this.onStartPickup,
    required this.onDelivered,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'assigned') {
      return Wrap(spacing: 6, children: [
        FilledButton(onPressed: onAccept, child: const Text('Accept')),
        OutlinedButton(onPressed: onReject, child: const Text('Reject')),
      ]);
    }
    if (status == 'accepted') {
      return FilledButton(onPressed: onStartPickup, child: const Text('Start Pickup'));
    }
    if (status == 'in_transit') {
      return Wrap(spacing: 6, children: [
        FilledButton(onPressed: onDelivered, child: const Text('Delivered')),
        OutlinedButton(onPressed: () {}, child: const Text('Navigate')),
      ]);
    }
    if (status == 'delivered') {
      return FilledButton(onPressed: onComplete, child: const Text('Complete'));
    }
    return const SizedBox.shrink();
  }
}
