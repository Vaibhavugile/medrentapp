import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nurse_order_details_screen.dart';

class NurseOrdersScreen extends StatefulWidget {
  final String staffId;

  const NurseOrdersScreen({
    super.key,
    required this.staffId,
  });

  @override
  State<NurseOrdersScreen> createState() => _NurseOrdersScreenState();
}

class _NurseOrdersScreenState extends State<NurseOrdersScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  final List<String> _tabs = [
    'all',
    'assigned',
    'active',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  Query _buildQuery(String status) {

    final base = FirebaseFirestore.instance
        .collection('staffAssignments')
        .where('staffId', isEqualTo: widget.staffId);

    if (status == 'all') {
      return base.orderBy('startDate', descending: true);
    }

    return base
        .where('status', isEqualTo: status)
        .orderBy('startDate', descending: true);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xffF5F7FB),

      appBar: AppBar(
        elevation: 0,
        title: const Text('My Orders'),
        centerTitle: true,

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xff3B82F6),
                Color(0xff60A5FA),
              ],
            ),
          ),
        ),

        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Assigned'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((status) {

          return _OrdersList(
            staffId: widget.staffId,
            query: _buildQuery(status),
          );

        }).toList(),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {

  final String staffId;
  final Query query;

  const _OrdersList({
    required this.staffId,
    required this.query,
  });

  String formatDate(dynamic value) {

    if (value == null) return "—";

    if (value is Timestamp) {
      final d = value.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }

    if (value is String) {
      return value.split("T").first;
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<QuerySnapshot>(

      stream: query.snapshots(),

      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No orders found"),
          );
        }

        final assignments = snapshot.data!.docs;

        return ListView.separated(

          padding: const EdgeInsets.all(16),

          itemCount: assignments.length,

          separatorBuilder: (_, __) => const SizedBox(height: 14),

          itemBuilder: (context, index) {

            final data =
                assignments[index].data() as Map<String, dynamic>;

            return NurseOrderCard(

              staffId: staffId,
              orderId: data['orderId'] ?? "",
              orderNo: data['orderNo'] ?? "Order",

              startDate: formatDate(data['startDate']),
              endDate: formatDate(data['endDate']),

              shift: data['shift'] ?? "day",
              status: data['status'] ?? "assigned",

              salary: data['amount'] ?? 0,
              paidAmount: data['paidAmount'] ?? 0,
              balanceAmount: data['balanceAmount'] ?? 0,
            );
          },
        );
      },
    );
  }
}

class NurseOrderCard extends StatefulWidget {

  final String staffId;
  final String orderId;
  final String orderNo;

  final String startDate;
  final String endDate;

  final String shift;
  final String status;

  final num salary;
  final num paidAmount;
  final num balanceAmount;

  const NurseOrderCard({
    super.key,
    required this.staffId,
    required this.orderId,
    required this.orderNo,
    required this.startDate,
    required this.endDate,
    required this.shift,
    required this.status,
    required this.salary,
    required this.paidAmount,
    required this.balanceAmount,
  });

  @override
  State<NurseOrderCard> createState() => _NurseOrderCardState();
}

class _NurseOrderCardState extends State<NurseOrderCard> {

  bool loading = false;

  Future<void> acceptOrder() async {

    setState(() => loading = true);

    final snap = await FirebaseFirestore.instance
        .collection('staffAssignments')
        .where('staffId', isEqualTo: widget.staffId)
        .where('orderId', isEqualTo: widget.orderId)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {

      await snap.docs.first.reference.update({
        'status': 'active',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() => loading = false);
  }

  Future<void> rejectOrder() async {

    setState(() => loading = true);

    final snap = await FirebaseFirestore.instance
        .collection('staffAssignments')
        .where('staffId', isEqualTo: widget.staffId)
        .where('orderId', isEqualTo: widget.orderId)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {

      await snap.docs.first.reference.update({
        'status': 'cancelled',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() => loading = false);
  }

  Color get statusColor {

    switch (widget.status) {

      case 'assigned':
        return Colors.orange;

      case 'active':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Container(

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0,6),
          )
        ],
      ),

      child: InkWell(

        borderRadius: BorderRadius.circular(18),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NurseOrderDetailsScreen(
                orderId: widget.orderId,
                staffId: widget.staffId,
              ),
            ),
          );
        },

        child: Padding(

          padding: const EdgeInsets.all(18),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Text(
                    widget.orderNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),

                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.15),
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(
                      widget.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                "${widget.startDate} → ${widget.endDate}",
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),

                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(.1),
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(
                      widget.shift.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),

                  Text(
                    "₹${widget.salary}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Text(
                    "Paid ₹${widget.paidAmount}",
                    style: const TextStyle(color: Colors.green),
                  ),

                  Text(
                    "Balance ₹${widget.balanceAmount}",
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),

              if (widget.status == "assigned") ...[

                const SizedBox(height: 14),

                Row(
                  children: [

                    Expanded(
                      child: ElevatedButton(
                        onPressed: loading ? null : acceptOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Accept"),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: OutlinedButton(
                        onPressed: loading ? null : rejectOrder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Reject"),
                      ),
                    ),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}