import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NurseHomeScreen extends StatelessWidget {
  const NurseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assignments'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('staffAssignments')
            .where('authUid', isEqualTo: uid)
            .where('status', whereIn: ['active', 'completed'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text('No assignments yet'),
            );
          }

          final assignments = snap.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: assignments.length,
            itemBuilder: (context, i) {
              final a = assignments[i].data() as Map<String, dynamic>;

              return _AssignmentCard(
                assignmentId: assignments[i].id,
                orderId: a['orderId'],
                orderNo: a['orderNo'],
                shift: a['shift'],
                startDate: a['startDate'],
                endDate: a['endDate'],
                status: a['status'],
              );
            },
          );
        },
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String assignmentId;
  final String orderId;
  final String orderNo;
  final String shift;
  final String startDate;
  final String endDate;
  final String status;

  const _AssignmentCard({
    required this.assignmentId,
    required this.orderId,
    required this.orderNo,
    required this.shift,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ORDER NO + STATUS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #$orderNo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor:
                      status == 'active' ? Colors.green.shade100 : Colors.grey.shade300,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text('Shift: $shift'),
            Text('From: $startDate → $endDate'),

            const SizedBox(height: 8),

            // FETCH ORDER DETAILS
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('nursingOrders')
                  .doc(orderId)
                  .get(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();

                final o = snap.data!.data() as Map<String, dynamic>?;

                if (o == null) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      o['customerName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(o['deliveryAddress'] ?? ''),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
