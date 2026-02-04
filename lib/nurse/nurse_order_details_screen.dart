import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NurseOrderDetailsScreen extends StatelessWidget {
  final String orderId;
  final String staffId; // ✅ REQUIRED

  const NurseOrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.staffId,
  });

  String fmtDate(dynamic value) {
    if (value == null) return '—';
    if (value is Timestamp) {
      return value.toDate().toString().split(' ').first;
    }
    if (value is String) {
      return value;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('nursingOrders')
            .doc(orderId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found'));
          }

          final order = snapshot.data!.data() as Map<String, dynamic>;
          final items =
              List<Map<String, dynamic>>.from(order['items'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // ================= ORDER HEADER =================
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Order No', order['orderNo']),
                    _Row('Status', order['status']),
                  ],
                ),
              ),

              // ================= CUSTOMER =================
              _Card(
                title: 'Customer',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['customerName'] ?? '—',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(order['deliveryAddress'] ?? '—'),
                    const SizedBox(height: 6),
                    Text(
                      order['deliveryContact']?['phone'] ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // ================= SERVICES =================
              _Card(
                title: 'Services',
                child: Column(
                  children: items.map((it) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it['name'] ?? 'Service',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${fmtDate(it['expectedStartDate'])} → ${fmtDate(it['expectedEndDate'])}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                        //   Text(
                        //     'Amount: ₹ ${it['amount'] ?? 0}',
                        //     style: const TextStyle(fontWeight: FontWeight.w600),
                        //   ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ================= SALARY (SECURE) =================
              _Card(
                title: 'Your Salary',
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('staffAssignments')
                      .where('orderId', isEqualTo: orderId)
                      .where('staffId', isEqualTo: staffId) // ✅ IMPORTANT
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const Text('No salary data');
                    }

                    final a =
                        snap.data!.docs.first.data() as Map<String, dynamic>;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row('Days', a['days']),
                        _Row('Shift', a['shift']),
                        _Row('Rate', '₹ ${a['rate']}'),
                        _Row('Total', '₹ ${a['amount']}'),
                        const SizedBox(height: 6),
                        Chip(
                          label: Text(
                            a['paid'] == true ? 'PAID' : 'UNPAID',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: a['paid'] == true
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// =======================================================
/// SMALL REUSABLE WIDGETS
/// =======================================================

class _Card extends StatelessWidget {
  final String? title;
  final Widget child;

  const _Card({
    this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final dynamic value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value?.toString() ?? '—',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
