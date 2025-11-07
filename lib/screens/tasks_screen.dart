// lib/screens/tasks_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/delivery_service.dart';
import '../services/inventory_service.dart';

class TasksScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  const TasksScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

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
      final s = ((d['status'] ?? o['deliveryStatus'] ?? 'assigned')
              .toString()
              .toLowerCase());
      (init[s] ?? init['other']!).add(d);
    }
    return init;
  }

  Future<void> _updateStage({
    required String deliveryId,
    required String stage,
  }) async {
    await _svc.updateStage(
      deliveryId: deliveryId,
      newStage: stage,
      driverName: widget.driverName,
      byUid: _auth.currentUser?.uid,
    );
  }

  void _openDetails(Map<String, dynamic> d) {
    final o = (d['order'] ?? {}) as Map<String, dynamic>;
    final hist = (d['combinedHistory'] ?? []) as List? ?? const [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Details',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  title: Text(
                    (o['customerName'] ?? 'NA').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    (o['deliveryAddress'] ??
                            o['address'] ??
                            o['dropAddress'] ??
                            'NA')
                        .toString(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('History',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ...hist.map((h) {
                  final m = (h as Map).cast<String, dynamic>();
                  final title =
                      (m['stage'] ?? m['note'] ?? '').toString();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.timeline),
                    title: Text(title),
                    subtitle: Text(_fmtTS(m['at'])),
                  );
                }),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _startPickup(d);
                    },
                    child: const Text('Start Pickup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==== PICKUP: strict QR validation + error/success toasts ====
  Future<void> _startPickup(Map<String, dynamic> delivery) async {
    // Build expected assets list exactly like web does.
    // Expected element shape: { assetDocId, assetId, itemName }
    final expected = await _svc.loadExpectedAssets(delivery);

    if (expected.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assets to scan for this delivery.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final expectedIds = expected
        .map((e) => (e['assetId'] as String).trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final scanned = <String, bool>{}; // assetId -> true
    bool confirming = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void toast(String msg, {Color? color}) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: color),
            );
          }

          String? _matchScan(String payload) {
            final raw = payload.trim();
            if (raw.isEmpty) return null;
            if (expectedIds.contains(raw)) return raw;
            for (final id in expectedIds) {
              if (raw.contains(id)) return id;
            }
            return null;
          }

          void _onDetect(BarcodeCapture cap) {
            for (final b in cap.barcodes) {
              final v = (b.rawValue ?? '').trim();
              if (v.isEmpty) continue;

              final hit = _matchScan(v);
              if (hit == null) {
                toast('Not expected for this delivery: $v',
                    color: Colors.red);
                continue;
              }
              if (scanned[hit] == true) {
                toast('Already scanned: $hit', color: Colors.black87);
                continue;
              }
              scanned[hit] = true;
              setSheetState(() {});
              toast('Scanned: $hit', color: Colors.green);
            }
          }

          Future<void> _confirm() async {
            if (confirming) return;

            // Require ALL expected assets scanned (strict)
            final allScanned =
                expected.every((e) => scanned[e['assetId']] == true);
            if (!allScanned) {
              toast('Scan all expected assets to start pickup.',
                  color: Colors.orange);
              return;
            }

            setSheetState(() => confirming = true);
            try {
              // 1) Checkout each scanned asset → out_for_rental
              final toCheckout = expected
                  .where((e) => scanned[e['assetId']] == true)
                  .map((e) => e['assetDocId'] as String)
                  .toList();

              for (final assetDocId in toCheckout) {
                await _inv.checkoutAsset(
                  assetDocId,
                  note: 'Checked out at pickup by driver',
                );
              }

              // 2) THEN set stage → in_transit (delivery & order)
              await _updateStage(
                deliveryId: delivery['id'].toString(),
                stage: 'in_transit',
              );

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Pickup started • ${toCheckout.length} assets checked out'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              // Network / Firestore / permission errors
              toast('Failed to start pickup: $e', color: Colors.red);
            } finally {
              setSheetState(() => confirming = false);
            }
          }

          final order =
              (delivery['order'] ?? {}) as Map<String, dynamic>;
          final total = expected.length;
          final done = scanned.values.where((v) => v == true).length;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Scan assets for pickup',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('$done of $total scanned',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),

                  // Camera
                  SizedBox(
                    height: 260,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(onDetect: _onDetect),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Expected',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 6),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: expected.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = expected[i];
                        final id = e['assetId'] as String;
                        final ok = scanned[id] == true;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                              ok ? Icons.check_circle : Icons.qr_code_2),
                          title: Text('${e['itemName']} • $id'),
                          subtitle: Text(
                              (order['orderNo'] ?? delivery['id'])
                                  .toString()),
                          trailing: Text(
                            ok ? 'Scanned' : 'Pending',
                            style: TextStyle(
                              color: ok ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: confirming ? null : _confirm,
                          child: Text(confirming
                              ? 'Processing…'
                              : 'Confirm pickup & start'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

        // Tabs (assigned/accepted/in_transit/delivered/completed/rejected)
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
                  label: Text(
                      '${DeliveryService.label(s)}${count > 0 ? ' ($count)' : ''}'),
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
              ? Center(
                  child: Text(
                    'No ${DeliveryService.label(_tab).toLowerCase()} tasks.',
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    final o = (d['order'] ?? {}) as Map<String, dynamic>;
                    final status = ((d['status'] ??
                                o['deliveryStatus'] ??
                                'assigned')
                            .toString()
                            .toLowerCase());
                    final address =
                        (o['deliveryAddress'] ??
                                o['address'] ??
                                o['dropAddress'] ??
                                d['address'] ??
                                'NA')
                            .toString();

                    return ListTile(
                      onTap: () => _openDetails(d),
                      title: Text((o['customerName'] ?? 'NA').toString()),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(address),
                          const SizedBox(height: 2),
                          Text(
                            'Order: ${(o['orderNo'] ?? d['orderId'] ?? d['id']).toString()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: _Actions(
                        status: status,
                        onAccept: () => _updateStage(
                            deliveryId: d['id'].toString(),
                            stage: 'accepted'),
                        onReject: () => _updateStage(
                            deliveryId: d['id'].toString(),
                            stage: 'rejected'),
                        // IMPORTANT: only scanner can move to in_transit
                        onStartPickup: () => _startPickup(d),
                        onDelivered: () => _updateStage(
                            deliveryId: d['id'].toString(),
                            stage: 'delivered'),
                        onComplete: () => _updateStage(
                            deliveryId: d['id'].toString(),
                            stage: 'completed'),
                        onNavigate: () => _openMaps(address),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openMaps(String address) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps')),
      );
    }
  }

  String _fmtTS(dynamic at) {
    if (at is Timestamp) return at.toDate().toLocal().toString();
    if (at is int) {
      return DateTime.fromMillisecondsSinceEpoch(at).toLocal().toString();
    }
    if (at is String) {
      final d = DateTime.tryParse(at);
      if (d != null) return d.toLocal().toString();
    }
    return '—';
  }
}

class _Actions extends StatelessWidget {
  final String status;
  final VoidCallback onAccept,
      onReject,
      onStartPickup,
      onDelivered,
      onComplete,
      onNavigate;
  const _Actions({
    required this.status,
    required this.onAccept,
    required this.onReject,
    required this.onStartPickup,
    required this.onDelivered,
    required this.onComplete,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'assigned') {
      return Wrap(
        spacing: 6,
        children: [
          FilledButton(onPressed: onAccept, child: const Text('Accept')),
          OutlinedButton(onPressed: onReject, child: const Text('Reject')),
        ],
      );
    }
    if (status == 'accepted') {
      // No direct jump to in_transit; must scan first
      return FilledButton(
          onPressed: onStartPickup, child: const Text('Start Pickup'));
    }
    if (status == 'in_transit') {
      return Wrap(
        spacing: 6,
        children: [
          FilledButton(onPressed: onDelivered, child: const Text('Delivered')),
          OutlinedButton(onPressed: onNavigate, child: const Text('Navigate')),
        ],
      );
    }
    if (status == 'delivered') {
      return FilledButton(
          onPressed: onComplete, child: const Text('Complete'));
    }
    return const SizedBox.shrink();
  }
}
