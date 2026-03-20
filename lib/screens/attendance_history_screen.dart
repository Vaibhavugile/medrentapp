import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String userId;
  final String collectionRoot;

  const AttendanceHistoryScreen({
    super.key,
    required this.userId,
    required this.collectionRoot,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends State<AttendanceHistoryScreen> {

  bool loading = true;
  List<Map<String, dynamic>> records = [];

  DateTime selectedMonth = DateTime.now();

  int present = 0;
  int half = 0;
  int absent = 0;
  int grace = 0;
  int totalMinutes = 0;

  double monthlySalary = 0; // ✅ FROM FIRESTORE

  @override
  void initState() {
    super.initState();
    load();
  }

  String get monthKey {
    return "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}";
  }

  List<String> getDaysOfMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    List<String> days = [];

    for (DateTime d = start;
        d.isBefore(end.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))) {
      days.add(
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}",
      );
    }

    return days;
  }

  Future<void> load() async {
    setState(() => loading = true);

    final db = FirebaseFirestore.instance;

    // ✅ FETCH SALARY
    final userDoc = await db
        .collection(widget.collectionRoot)
        .doc(widget.userId)
        .get();

    monthlySalary =
        (userDoc.data()?['salaryMonthly'] ?? 0).toDouble();

    final snap = await db
        .collection(widget.collectionRoot)
        .doc(widget.userId)
        .collection('attendance')
        .get();

    final Map<String, Map<String, dynamic>> attMap = {
      for (var d in snap.docs) d.id: d.data()
    };

    final days = getDaysOfMonth(selectedMonth);

    List<Map<String, dynamic>> list = [];

    int p = 0, h = 0, a = 0, g = 0, mins = 0;
    int graceUsed = 0;

    for (final dayId in days) {

      final raw = attMap[dayId];

      int duration = 0;

      if (raw != null) {
        final checkIn = raw['checkInServer'] ?? raw['checkInMs'];
        final checkOut = raw['checkOutServer'] ?? raw['checkOutMs'];

        if (checkIn != null) {
          final start = checkIn is Timestamp
              ? checkIn.toDate()
              : DateTime.fromMillisecondsSinceEpoch(checkIn);

          final end = checkOut != null
              ? (checkOut is Timestamp
                  ? checkOut.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(checkOut))
              : DateTime.now();

          duration = end.difference(start).inMinutes;
        }
      }

      String type;

      // ✅ SAME LOGIC AS WEB
      if (duration >= 525) {
        type = "present";
        p++;
      } else if (duration >= 480) {
        if (graceUsed < 2) {
          graceUsed++;
          type = "grace";
          g++;
        } else {
          type = "half";
          h++;
        }
      } else if (duration >= 240) {
        type = "half";
        h++;
      } else {
        type = "absent";
        a++;
      }

      mins += duration;

      list.add({
        "date": dayId,
        "minutes": duration,
        "type": type,
      });
    }

    list.sort((a, b) => b["date"].compareTo(a["date"]));

    setState(() {
      records = list;
      present = p;
      half = h;
      absent = a;
      grace = g;
      totalMinutes = mins;
      loading = false;
    });
  }

  String hhmm(int mins) {
    final h = mins ~/ 60;
    final m = (mins % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  double get salary {
    if (monthlySalary == 0) return 0;

    final perDay = monthlySalary / 26;

    return ((present + grace) * perDay) +
        (half * (perDay / 2));
  }

  Future<void> pickMonth() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });
      load();
    }
  }

  Color getTypeColor(String type) {
    switch (type) {
      case "present":
        return Colors.green;
      case "grace":
        return Colors.orange;
      case "half":
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: pickMonth,
          )
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ===== SUMMARY =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  color: Colors.black.withOpacity(0.05),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  "Month: $monthKey",
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _pill("Present $present", Colors.green),
                    _pill("Grace $grace", Colors.orange),
                    _pill("Half $half", Colors.blue),
                    _pill("Absent $absent", Colors.red),
                  ],
                ),

                const SizedBox(height: 12),

                Text("Total Hours: ${hhmm(totalMinutes)}"),

                const SizedBox(height: 6),

                Text(
                  "Salary: ₹${salary.round()}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "Base Salary: ₹${monthlySalary.round()} / month",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== DAILY =====
          ...records.map((r) {
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                title: Text(r["date"]),
                subtitle: Text("Hours: ${hhmm(r["minutes"])}"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: getTypeColor(r["type"]).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r["type"].toUpperCase(),
                    style: TextStyle(
                      color: getTypeColor(r["type"]),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          })
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}