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
    backgroundColor: const Color(0xFFF5F7FB),

    appBar: AppBar(
      elevation: 0,
      title: const Text("Attendance History"),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2C3E50),
              Color(0xFF4CA1AF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
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

        /// MONTH HEADER
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Month: $monthKey",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: Colors.white),
                onPressed: pickMonth,
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        /// SUMMARY GRID
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [

            _summaryCard("Present", present, Colors.green),
            _summaryCard("Grace", grace, Colors.orange),
            _summaryCard("Half Day", half, Colors.blue),
            _summaryCard("Absent", absent, Colors.red),

          ],
        ),

        const SizedBox(height: 16),

        /// SALARY CARD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 15,
                color: Colors.black.withOpacity(.06),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                "Salary Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Hours"),
                  Text(
                    hhmm(totalMinutes),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                ],
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Calculated Salary"),
                  Text(
                    "₹${salary.round()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 18,
                    ),
                  )
                ],
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Base Monthly Salary"),
                  Text("₹${monthlySalary.round()}"),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          "Daily Attendance",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        /// DAILY RECORDS
        ...records.map((r) {

          final color = getTypeColor(r["type"]);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  color: Colors.black.withOpacity(.05),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r["date"],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Hours: ${hhmm(r["minutes"])}",
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r["type"].toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
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
 Widget _summaryCard(String title, int value, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          blurRadius: 10,
          color: Colors.black.withOpacity(.05),
        )
      ],
    ),
    child: Row(
      children: [

        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(.15),
          child: Icon(Icons.circle, color: color, size: 10),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}