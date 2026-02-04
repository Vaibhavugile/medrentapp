import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nurse_order_details_screen.dart';

/// =======================================================
/// Nurse Orders Screen
/// Shows orders assigned to the logged-in nurse
/// =======================================================

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: const Text('My Orders'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
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

/// =======================================================
/// Orders List (Reusable for each tab)
/// =======================================================

class _OrdersList extends StatelessWidget {
  final String staffId;
  final Query query;

  const _OrdersList({
    required this.staffId,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Empty
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No orders found',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        final assignments = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = assignments[index];
            final data = doc.data() as Map<String, dynamic>;

            return NurseOrderCard(
              staffId: staffId,
              orderId: data['orderId'],
              orderNo: data['orderNo'] ?? 'Order',
              startDate: data['startDate'] ?? '',
              endDate: data['endDate'] ?? '',
              shift: data['shift'] ?? 'day',
              status: data['status'] ?? 'assigned',
              salary: data['amount'] ?? 0,
            );
          },
        );
      },
    );
  }
}

/// =======================================================
/// Order Card Widget
/// =======================================================

class NurseOrderCard extends StatelessWidget {
  final String staffId;
  final String orderId;
  final String orderNo;
  final String startDate;
  final String endDate;
  final String shift;
  final String status;
  final num salary;

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
  });

  Color get statusColor {
    switch (status) {
      case 'assigned':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NurseOrderDetailsScreen(
                orderId: orderId,
                staffId: staffId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                orderNo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '$startDate → $endDate',
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text(
                      shift.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                'Salary: ₹ ${salary.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
