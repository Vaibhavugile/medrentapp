import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TodayScreen extends StatelessWidget {
  final String userId;
  final String userName;
  const TodayScreen({super.key, required this.userId, required this.userName});

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final id = '${_isoDate(DateTime.now().toUtc())}_$userId';
    final ref = FirebaseFirestore.instance.collection('daily_stats').doc(id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data();
        final planned   = data?['visits_planned']   ?? 0;
        final started   = data?['visits_started']   ?? 0;
        final reached   = data?['visits_reached']   ?? 0;
        final done      = data?['visits_done']      ?? 0;
        final cancelled = data?['visits_cancelled'] ?? 0;
        final leadsC    = data?['leads_created']    ?? 0;
        final leadsW    = data?['leads_won']        ?? 0;
        final tl        = (data?['timeline'] ?? []) as List;

        return Scaffold(
          appBar: AppBar(title: const Text('Today')),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _chip('Planned', planned),
                    _chip('Started', started),
                    _chip('Reached', reached),
                    _chip('Done', done),
                    _chip('Cancelled', cancelled),
                    _chip('Leads', leadsC),
                    _chip('Won', leadsW),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: tl.isEmpty
                    ? const Center(child: Text('No activity yet.'))
                    : ListView.separated(
                        itemCount: tl.length,
                        separatorBuilder: (_, __)=>const Divider(height:1),
                        itemBuilder: (_, i) {
                          final e = (tl[i] as Map).cast<String, dynamic>();
                          final type = (e['type'] ?? '').toString();
                          final at   = (e['at'] ?? '').toString();
                          return ListTile(
                            leading: const Icon(Icons.timeline),
                            title: Text(type.replaceAll('_', ' ')),
                            subtitle: Text(at),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, int value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
