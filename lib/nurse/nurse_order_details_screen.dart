import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NurseOrderDetailsScreen extends StatelessWidget {
  final String orderId;
  final String staffId;

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
    if (value is String) return value;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),

      appBar: AppBar(
        elevation: 0,
        title: const Text('Order Details'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
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
          final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [

              /// HEADER
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade600,
                      Colors.blue.shade400
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Order",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      order['orderNo'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _StatusChip(order['status'] ?? "pending"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// CUSTOMER
              _Card(
                title: "Patient / Customer",
                icon: Icons.person_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      order['customerName'] ?? '—',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      order['deliveryAddress'] ?? '—',
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16),
                        const SizedBox(width: 6),
                        Text(order['deliveryContact']?['phone'] ?? '')
                      ],
                    ),
                  ],
                ),
              ),

              /// SERVICES
              _Card(
                title: "Services",
                icon: Icons.medical_services_outlined,
                child: Column(
                  children: items.map((it) {

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),

                      child: Row(
                        children: [

                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_hospital,
                              color: Colors.blue,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(
                                  it['name'] ?? "Service",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  "${fmtDate(it['expectedStartDate'])} → ${fmtDate(it['expectedEndDate'])}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );

                  }).toList(),
                ),
              ),

              /// ASSIGNMENT
              _Card(
                title: "Your Assignment",
                icon: Icons.work_outline,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('staffAssignments')
                      .where('orderId', isEqualTo: orderId)
                      .where('staffId', isEqualTo: staffId)
                      .snapshots(),

                  builder: (context, snap) {

                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const Text('No assignment found');
                    }

                    final a =
                        snap.data!.docs.first.data() as Map<String, dynamic>;

                    final total = a['amount'] ?? 0;
                    final paid = a['paidAmount'] ?? 0;
                    final balance = a['balanceAmount'] ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        _Row('Shift', a['shift']),
                        _Row('Rate', "₹ ${a['rate']} / ${a['rateType']}"),

                        if (a['days'] != null)
                          _Row('Days', a['days']),

                        const Divider(height: 26),

                        _MoneyRow("Total Salary", total, Colors.black),

                        _MoneyRow("Paid", paid, Colors.green),

                        _MoneyRow("Balance", balance, Colors.red),

                        const SizedBox(height: 12),

                        Row(
                          children: [

                            _PaymentChip(
                              label: a['paid'] == true
                                  ? "PAID"
                                  : "UNPAID",
                              color: a['paid'] == true
                                  ? Colors.green
                                  : Colors.orange,
                            ),

                            const SizedBox(width: 10),

                            _PaymentChip(
                              label: a['status'] ?? "assigned",
                              color: Colors.blue,
                            ),
                          ],
                        )
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;

  const _MoneyRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(label, style: const TextStyle(color: Colors.grey)),

          Text(
            "₹ $value",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x11000000),
            offset: Offset(0, 4),
          )
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [

                Icon(icon, color: Colors.blue),

                const SizedBox(width: 8),

                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              ],
            ),

            const SizedBox(height: 14),

            child
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {

    Color color = Colors.orange;

    if (status == "completed") color = Colors.green;
    if (status == "active") color = Colors.blue;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PaymentChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(label, style: const TextStyle(color: Colors.grey)),

          Text(
            value?.toString() ?? '—',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}