// lib/screens/tasks_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/delivery_service.dart';
import '../services/inventory_service.dart';
import 'package:flutter/services.dart';

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

bool _isReturn(Map<String, dynamic> d) {
  return (d['deliveryType'] ?? '').toString().toLowerCase() == 'return';
}

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((d) {
      final o = (d['order'] ?? {}) as Map<String, dynamic>;
      final text = [
        o['customerName'],
        o['orderNo'],
        o['deliveryAddress'] ??
            o['address'] ??
            o['dropAddress'] ??
            d['address'],
      ]
          .where((e) => e != null)
          .join(' ')
          .toString()
          .toLowerCase();
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

  // === Stage update with optional confirmation ===
  Future<void> _updateStage({
    required String deliveryId,
    required String stage,
    bool confirm = true,
  }) async {
    if (confirm) {
      final ok = await _confirmStage(stage);
      if (!ok) return;
    }

   await _svc.updateStage(
  deliveryId: deliveryId,
  newStage: stage,
  byDriverId: widget.driverId,
);


    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stage changed to: $stage')),
      );
    }
  }

  Future<bool> _confirmStage(String stage) async {
    final pretty = stage.replaceAll('_', ' ');
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm'),
            content: Text('Change stage to "$pretty"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openDetails(Map<String, dynamic> d) {
    final o = (d['order'] ?? {}) as Map<String, dynamic>;
    final hist = (d['combinedHistory'] ?? []) as List? ?? const [];

    final expectedStart = d['expectedStartDate'];

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
                Text(
                  'Delivery Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
                if (expectedStart != null) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.event),
                    title: const Text('Expected Start'),
                    subtitle: Text(_fmtTS(expectedStart)),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                ...hist.map((h) {
                  final m = (h as Map).cast<String, dynamic>();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.timeline),
                    title: Text(
                      (m['stage'] ?? m['note'] ?? '').toString(),
                    ),
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
  // ==== PICKUP: strict QR validation + shared multi-driver scans ====
Future<void> _startPickup(Map<String, dynamic> delivery) async {
  debugPrint('🟢 START PICKUP for delivery=${delivery['id']}');

  final expected = await _svc.loadExpectedAssets(delivery);
  debugPrint('🟢 EXPECTED ASSETS RAW = $expected');

  if (expected.isEmpty) {
    debugPrint('🔴 NO EXPECTED ASSETS');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No assets to scan for this delivery.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // 🔑 assetId (NKU45) -> assetDocId
  final Map<String, String> expectedMap = {};
  for (final e in expected) {
    final assetId = (e['assetId'] ?? '').toString().trim();
    final assetDocId = (e['assetDocId'] ?? '').toString().trim();
    if (assetId.isNotEmpty && assetDocId.isNotEmpty) {
      expectedMap[assetId] = assetDocId;
    }
  }

  debugPrint('🟢 EXPECTED MAP (assetId → docId) = $expectedMap');

  /// 🔒 LOCAL UI STATE (DOC IDS)
  final Set<String> scannedDocIds = {};
  final TextEditingController manualCtrl = TextEditingController();

  /// hydrate from Firestore (docIds)
  final rawScanned =
      Map<String, dynamic>.from(delivery['scannedAssets'] ?? {});
  scannedDocIds.addAll(rawScanned.keys);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheetState) {

        String msgText = '';
        Color msgColor = Colors.transparent;

        void setMsg(
          String text,
          Color color, {
          bool hapticOk = false,
          bool hapticWarn = false,
          bool hapticErr = false,
        }) {
          msgText = text;
          msgColor = color;
          if (hapticOk) HapticFeedback.mediumImpact();
          if (hapticWarn) HapticFeedback.selectionClick();
          if (hapticErr) HapticFeedback.heavyImpact();
          setSheetState(() {});
        }

        String? _matchScan(String payload) {
          final raw = payload.trim();
          if (raw.isEmpty) return null;
          if (expectedMap.containsKey(raw)) return raw;
          for (final id in expectedMap.keys) {
            if (raw.contains(id)) return id;
          }
          return null;
        }

        DateTime _lastHandled = DateTime.fromMillisecondsSinceEpoch(0);
        const int _cooldownMs = 900;

        Future<void> _handleScan(String raw) async {
          final hitAssetId = _matchScan(raw);
          if (hitAssetId == null) {
            setMsg('QR not matched for this task', Colors.red,
                hapticErr: true);
            return;
          }

          final assetDocId = expectedMap[hitAssetId]!;
          if (scannedDocIds.contains(assetDocId)) {
            setMsg('Already scanned: $hitAssetId', Colors.orange,
                hapticWarn: true);
            return;
          }

          try {
            await _svc.addScan(
              deliveryId: delivery['id'].toString(),
              assetId: assetDocId, // ✅ DOC ID (matches Firestore)
              driverId: widget.driverId,
            );

            // ✅ update local UI state
            setSheetState(() {
              scannedDocIds.add(assetDocId);
            });

            setMsg('Scanned: $hitAssetId', Colors.green, hapticOk: true);

            // ✅ ALWAYS TRY COMPLETION (BACKEND DECIDES)
            await _svc.tryCompletePickup(
              deliveryId: delivery['id'].toString(),
              leaderDriverId: widget.driverId,
            );

            // ✅ CLOSE & SHOW SUCCESS IF ALL SCANNED
            if (scannedDocIds.length >= expected.length) {
              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Pickup Completed'),
                  content: Text('All assets scanned successfully.'),
                ),
              );
            }
          } catch (e) {
            debugPrint('🔥 SCAN FAILED error=$e');
            setMsg('Failed to record scan', Colors.red, hapticErr: true);
          }
        }

        void _onDetect(BarcodeCapture cap) async {
          final now = DateTime.now();
          if (now.difference(_lastHandled).inMilliseconds < _cooldownMs) return;

          for (final b in cap.barcodes) {
            final raw = (b.rawValue ?? '').trim();
            if (raw.isNotEmpty) {
              _lastHandled = now;
              await _handleScan(raw);
              break;
            }
          }
        }

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
                Text(
                  'Scan assets for pickup',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${scannedDocIds.length} of ${expected.length} scanned',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),

                // 📷 CAMERA
                SizedBox(
                  height: 220,
                  child: MobileScanner(onDetect: _onDetect),
                ),

                const SizedBox(height: 8),

                // ⌨️ MANUAL VERIFY
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: manualCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Enter asset ID manually',
                          hintText: 'e.g. NKU45',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (v) {
                          _handleScan(v);
                          manualCtrl.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        _handleScan(manualCtrl.text);
                        manualCtrl.clear();
                      },
                      child: const Text('Verify'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 📋 EXPECTED LIST (NO OVERFLOW)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: expected.length,
                    itemBuilder: (_, i) {
                      final e = expected[i];
                      final assetId = e['assetId'] as String;
                      final assetDocId = expectedMap[assetId]!;
                      final ok = scannedDocIds.contains(assetDocId);

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          ok ? Icons.check_circle : Icons.qr_code_2,
                          color: ok ? Colors.green : Colors.orange,
                        ),
                        title: Text('${e['itemName']} • $assetId'),
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
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _startReturn(Map<String, dynamic> delivery) async {
  debugPrint('🔵 START RETURN for delivery=${delivery['id']}');

  final expected = await _svc.loadExpectedAssets(delivery);
  debugPrint('🔵 EXPECTED ASSETS RAW = $expected');

  if (expected.isEmpty) {
    debugPrint('🔴 NO EXPECTED ASSETS FOR RETURN');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No assets to scan for return.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // 🔑 assetId -> assetDocId
  final Map<String, String> expectedMap = {};
  for (final e in expected) {
    final assetId = (e['assetId'] ?? '').toString().trim();
    final assetDocId = (e['assetDocId'] ?? '').toString().trim();
    if (assetId.isNotEmpty && assetDocId.isNotEmpty) {
      expectedMap[assetId] = assetDocId;
    }
  }

  debugPrint('🔵 EXPECTED MAP (assetId → docId) = $expectedMap');

  final Set<String> scannedDocIds = {};
  final TextEditingController manualCtrl = TextEditingController();

  final rawScanned =
      Map<String, dynamic>.from(delivery['scannedAssets'] ?? {});
  scannedDocIds.addAll(rawScanned.keys);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        String msgText = '';
        Color msgColor = Colors.transparent;

        void setMsg(
          String text,
          Color color, {
          bool hapticOk = false,
          bool hapticWarn = false,
          bool hapticErr = false,
        }) {
          msgText = text;
          msgColor = color;
          if (hapticOk) HapticFeedback.mediumImpact();
          if (hapticWarn) HapticFeedback.selectionClick();
          if (hapticErr) HapticFeedback.heavyImpact();
          setSheetState(() {});
        }

        String? _matchScan(String payload) {
          final raw = payload.trim();
          if (raw.isEmpty) return null;
          if (expectedMap.containsKey(raw)) return raw;
          for (final id in expectedMap.keys) {
            if (raw.contains(id)) return id;
          }
          return null;
        }

        DateTime _lastHandled = DateTime.fromMillisecondsSinceEpoch(0);
        const int _cooldownMs = 900;

        Future<void> _handleScan(String raw) async {
          final hitAssetId = _matchScan(raw);
          if (hitAssetId == null) {
            setMsg('QR not matched for this return', Colors.red,
                hapticErr: true);
            return;
          }

          final assetDocId = expectedMap[hitAssetId]!;
          if (scannedDocIds.contains(assetDocId)) {
            setMsg('Already scanned: $hitAssetId', Colors.orange,
                hapticWarn: true);
            return;
          }

          try {
            await _svc.addScan(
              deliveryId: delivery['id'].toString(),
              assetId: assetDocId,
              driverId: widget.driverId,
            );

            setSheetState(() {
              scannedDocIds.add(assetDocId);
            });

            setMsg('Returned: $hitAssetId', Colors.green, hapticOk: true);

            await _svc.tryCompleteReturn(
              deliveryId: delivery['id'].toString(),
              leaderDriverId: widget.driverId,
            );

            if (scannedDocIds.length >= expected.length) {
              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Return Completed'),
                  content: Text('All assets returned successfully.'),
                ),
              );
            }
          } catch (e) {
            debugPrint('🔥 RETURN SCAN FAILED error=$e');
            setMsg('Failed to record return scan', Colors.red,
                hapticErr: true);
          }
        }

        void _onDetect(BarcodeCapture cap) async {
          final now = DateTime.now();
          if (now.difference(_lastHandled).inMilliseconds < _cooldownMs) return;

          for (final b in cap.barcodes) {
            final raw = (b.rawValue ?? '').trim();
            if (raw.isNotEmpty) {
              _lastHandled = now;
              await _handleScan(raw);
              break;
            }
          }
        }

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
                Text(
                  'Scan assets for return',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${scannedDocIds.length} of ${expected.length} returned',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),

                // 📷 CAMERA
                SizedBox(
                  height: 220,
                  child: MobileScanner(onDetect: _onDetect),
                ),

                const SizedBox(height: 8),

                // ⌨️ MANUAL VERIFY
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: manualCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Enter asset ID manually',
                          hintText: 'e.g. NKU45',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (v) {
                          _handleScan(v);
                          manualCtrl.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        _handleScan(manualCtrl.text);
                        manualCtrl.clear();
                      },
                      child: const Text('Verify'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 📋 EXPECTED LIST (THIS WAS MISSING)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: expected.length,
                    itemBuilder: (_, i) {
                      final e = expected[i];
                      final assetId = e['assetId'] as String;
                      final assetDocId = expectedMap[assetId]!;
                      final ok = scannedDocIds.contains(assetDocId);

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          ok ? Icons.check_circle : Icons.qr_code_2,
                          color: ok ? Colors.green : Colors.orange,
                        ),
                        title: Text('${e['itemName']} • $assetId'),
                        trailing: Text(
                          ok ? 'Returned' : 'Pending',
                          style: TextStyle(
                            color: ok ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
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
                  label: Text(
                    '${DeliveryService.label(s)}${count > 0 ? ' ($count)' : ''}',
                  ),
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

                    final expectedStart = d['expectedStartDate'];

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
                          if (expectedStart != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Expected: ${_fmtTS(expectedStart)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      trailing: _Actions(
                        status: status,
                        onAccept: () => _svc.acceptDelivery(
                          deliveryId: d['id'].toString(),
                          driverId: widget.driverId,
                        ),
                        onReject: () => _updateStage(
                          deliveryId: d['id'].toString(),
                          stage: 'rejected',
                        ),
                        onStartPickup: () {
  if (_isReturn(d)) {
    _startReturn(d);
  } else {
    _startPickup(d);
  }
},

                        onDelivered: () => _updateStage(
                          deliveryId: d['id'].toString(),
                          stage: 'delivered',
                        ),
                        onComplete: () => _updateStage(
                          deliveryId: d['id'].toString(),
                          stage: 'completed',
                        ),
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
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}',
    );
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
      return FilledButton(
        onPressed: onStartPickup,
        child: const Text('Start Pickup'),



      );
    }

    if (status == 'in_transit') {
      return Wrap(
        spacing: 6,
        children: [
          FilledButton(
              onPressed: onDelivered, child: const Text('Delivered')),
          OutlinedButton(
              onPressed: onNavigate, child: const Text('Navigate')),
        ],
      );
    }

    if (status == 'delivered') {
      return FilledButton(
        onPressed: onComplete,
        child: const Text('Complete'),
      );
    }

    return const SizedBox.shrink();
  }
}
