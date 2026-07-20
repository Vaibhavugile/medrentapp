import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'full_screen_image.dart';

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
  //---------------------------------------------------------
  // Loading
  //---------------------------------------------------------

  bool loading = true;

  //---------------------------------------------------------
  // Attendance Records
  //---------------------------------------------------------

  List<Map<String, dynamic>> records = [];

  //---------------------------------------------------------
  // Selected Month
  //---------------------------------------------------------

  DateTime selectedMonth = DateTime.now();

  //---------------------------------------------------------
  // Summary
  //---------------------------------------------------------

  int present = 0;
  int grace = 0;
  int half = 0;
  int absent = 0;

  int totalMinutes = 0;

  //---------------------------------------------------------
  // Salary
  //---------------------------------------------------------

  double monthlySalary = 0;

  //---------------------------------------------------------
  // Filter
  //---------------------------------------------------------

  String selectedFilter = "all";

  //---------------------------------------------------------
  // Responsive Variables
  //---------------------------------------------------------

  late double screenWidth;
  late double screenHeight;

  late bool isSmallPhone;
  late bool isPhone;
  late bool isTablet;

  late double pagePadding;
  late double cardRadius;
  late double imageWidth;
  late double imageHeight;

  late double titleFont;
  late double subtitleFont;
  late double bodyFont;
  late double valueFont;

  //---------------------------------------------------------
  // Init
  //---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    load();
  }

  //---------------------------------------------------------
  // Responsive Initializer
  //---------------------------------------------------------

  void initializeResponsive(BuildContext context) {
    final size = MediaQuery.of(context).size;

    screenWidth = size.width;
    screenHeight = size.height;

    isSmallPhone = screenWidth < 360;
    isPhone = screenWidth >= 360 && screenWidth < 600;
    isTablet = screenWidth >= 600;

    pagePadding = isSmallPhone
        ? 12
        : isTablet
            ? 22
            : 16;

    cardRadius = isSmallPhone ? 14 : 18;

    imageWidth = isSmallPhone
        ? 95
        : isTablet
            ? 150
            : 120;

    imageHeight = isSmallPhone
        ? 72
        : isTablet
            ? 110
            : 90;

    titleFont = isSmallPhone
        ? 16
        : isTablet
            ? 22
            : 18;

    subtitleFont = isSmallPhone ? 13 : 15;

    bodyFont = isSmallPhone ? 12 : 14;

    valueFont = isSmallPhone ? 18 : 22;
  }

  //---------------------------------------------------------
  // Month Key
  //---------------------------------------------------------

  String get monthKey {
    return "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, "0")}";
  }

  //---------------------------------------------------------
  // Days Generator
  //---------------------------------------------------------

  List<String> getDaysOfMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);

    final end = DateTime(
      month.year,
      month.month + 1,
      0,
    );

    List<String> days = [];

    for (
      DateTime d = start;
      d.isBefore(end.add(const Duration(days: 1)));
      d = d.add(const Duration(days: 1))
    ) {
      days.add(
        "${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}",
      );
    }

    return days;
  }

  //---------------------------------------------------------
  // LOAD (Original Firestore Logic)
  //---------------------------------------------------------

  Future<void> load() async {
    setState(() => loading = true);

    final db = FirebaseFirestore.instance;

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

    int p = 0;
    int h = 0;
    int a = 0;
    int g = 0;
    int mins = 0;

    int graceUsed = 0;

    for (final dayId in days) {
      final raw = attMap[dayId];

      int duration = 0;

      if (raw != null) {
        final checkIn =
            raw['checkInServer'] ?? raw['checkInMs'];

        final checkOut =
            raw['checkOutServer'] ?? raw['checkOutMs'];

        if (checkIn != null) {
          final start = checkIn is Timestamp
              ? checkIn.toDate()
              : DateTime.fromMillisecondsSinceEpoch(
                  checkIn);

          final end = checkOut != null
              ? (checkOut is Timestamp
                  ? checkOut.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(
                      checkOut))
              : DateTime.now();

          duration = end.difference(start).inMinutes;
        }
      }

      String type;

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
        "checkInServer": raw?["checkInServer"],
        "checkOutServer": raw?["checkOutServer"],
        "checkInPhotoUrl": raw?["check-inPhotoUrl"],
        "checkOutPhotoUrl": raw?["check-outPhotoUrl"],
        "note": raw?["note"] ?? "",
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

  //---------------------------------------------------------
  // Time Formatter
  //---------------------------------------------------------

  String formatTime(dynamic value) {
    if (value == null) return "--";

    final DateTime dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else {
      dateTime =
          DateTime.fromMillisecondsSinceEpoch(value);
    }

    return TimeOfDay.fromDateTime(dateTime)
        .format(context);
  }

  //---------------------------------------------------------
  // Hours Formatter
  //---------------------------------------------------------

  String hhmm(int mins) {
    final h = mins ~/ 60;

    final m =
        (mins % 60).toString().padLeft(2, "0");

    return "$h:$m";
  }

  //---------------------------------------------------------
  // Salary Calculator
  //---------------------------------------------------------

  double get salary {
    if (monthlySalary == 0) return 0;

    final perDay = monthlySalary / 26;

    return ((present + grace) * perDay) +
        (half * (perDay / 2));
  }

  //---------------------------------------------------------
  // Month Picker
  //---------------------------------------------------------

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
        selectedMonth =
            DateTime(picked.year, picked.month);
      });

      load();
    }
  }

  //---------------------------------------------------------
  // Status Color
  //---------------------------------------------------------

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
  initializeResponsive(context);

  final filteredRecords = selectedFilter == "all"
      ? records
      : records.where((e) => e["type"] == selectedFilter).toList();

  if (loading) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  return Scaffold(
    backgroundColor: const Color(0xffF5F7FB),

    appBar: AppBar(
      elevation: 0,
      centerTitle: false,
      title: Text(
        "Attendance History",
        style: TextStyle(
          fontSize: titleFont + 4,
          fontWeight: FontWeight.bold,
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff2C3E50),
              Color(0xff4CA1AF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: pickMonth,
          icon: const Icon(Icons.calendar_month),
        ),
      ],
    ),

    body: SafeArea(
      child: ListView(
        padding: EdgeInsets.all(pagePadding),
        children: [

          //--------------------------------------
          // MONTH HEADER
          //--------------------------------------

          Container(
            padding: EdgeInsets.symmetric(
              horizontal: pagePadding,
              vertical: pagePadding,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardRadius),
              gradient: const LinearGradient(
                colors: [
                  Color(0xff4CA1AF),
                  Color(0xff2C3E50),
                ],
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [

                Text(
                  "Month : $monthKey",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFont,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                IconButton(
                  onPressed: pickMonth,
                  icon: const Icon(
                    Icons.edit_calendar,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: pagePadding),

          //--------------------------------------
          // SUMMARY GRID
          //--------------------------------------

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
                  isSmallPhone
                      ? 1.55
                      : 2.1,
            ),
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _summaryCard(
                    "Present",
                    present,
                    Colors.green,
                    "present",
                  );

                case 1:
                  return _summaryCard(
                    "Grace",
                    grace,
                    Colors.orange,
                    "grace",
                  );

                case 2:
                  return _summaryCard(
                    "Half Day",
                    half,
                    Colors.blue,
                    "half",
                  );

                default:
                  return _summaryCard(
                    "Absent",
                    absent,
                    Colors.red,
                    "absent",
                  );
              }
            },
          ),

          SizedBox(height: pagePadding),

          //--------------------------------------
          // SALARY
          //--------------------------------------

          Container(
            padding: EdgeInsets.all(pagePadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(cardRadius),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  "Salary Summary",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFont,
                  ),
                ),

                SizedBox(height: pagePadding),

                _salaryRow(
                  "Total Hours",
                  hhmm(totalMinutes),
                ),

                const SizedBox(height: 8),

                _salaryRow(
                  "Calculated Salary",
                  "₹${salary.round()}",
                  valueColor: Colors.blue,
                  bold: true,
                ),

                const SizedBox(height: 8),

                _salaryRow(
                  "Base Monthly Salary",
                  "₹${monthlySalary.round()}",
                ),
              ],
            ),
          ),

          SizedBox(height: pagePadding),

          //--------------------------------------
          // TITLE
          //--------------------------------------

          Text(
            "Daily Attendance",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFont,
            ),
          ),

          const SizedBox(height: 12),

          //--------------------------------------
          // DAILY CARDS
          //--------------------------------------

          ...filteredRecords.map((r) {

            final color = getTypeColor(r["type"]);

            return Card(
              elevation: 3,
              margin:
                  const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(cardRadius),
              ),
              child: Padding(
                padding: EdgeInsets.all(pagePadding),

                child: LayoutBuilder(
                  builder: (context, constraints) {

                    final compact =
                        constraints.maxWidth < 360;

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Text(
                          r["date"],
                          style: TextStyle(
                            fontSize: titleFont,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          runSpacing: 6,
                          children: [

                            Text(
                              "🟢 Check In : ${formatTime(r["checkInServer"])}",
                              style: TextStyle(
                                fontSize: bodyFont,
                              ),
                            ),

                            Text(
                              "🔴 Check Out : ${formatTime(r["checkOutServer"])}",
                              style: TextStyle(
                                fontSize: bodyFont,
                              ),
                            ),

                            Text(
                              "⏱ Hours : ${hhmm(r["minutes"])}",
                              style: TextStyle(
                                fontSize: bodyFont,
                                color:
                                    Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [

                            if (r["checkInPhotoUrl"] !=
                                null)
                              _attendancePhoto(
                                title: "Check In",
                                image:
                                    r["checkInPhotoUrl"],
                              ),

                            if (r["checkOutPhotoUrl"] !=
                                null)
                              _attendancePhoto(
                                title: "Check Out",
                                image:
                                    r["checkOutPhotoUrl"],
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Align(
                          alignment:
                              Alignment.centerRight,
                          child: Container(
                            padding:
                                EdgeInsets.symmetric(
                              horizontal:
                                  compact ? 12 : 16,
                              vertical:
                                  compact ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  color.withOpacity(.12),
                              borderRadius:
                                  BorderRadius.circular(
                                      30),
                            ),
                            child: Text(
                              r["type"]
                                  .toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: bodyFont,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          }).toList(),
        ],
      ),
    ),
  );
}
Widget _summaryCard(
  String title,
  int value,
  Color color,
  String filter,
) {
  final bool selected = selectedFilter == filter;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(cardRadius),
      onTap: () {
        setState(() {
          selectedFilter = selected ? "all" : filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(
          isSmallPhone ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(.12)
              : Colors.white,
          borderRadius:
              BorderRadius.circular(cardRadius),
          border: Border.all(
            color: selected
                ? color
                : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 4),
              color: color.withOpacity(
                selected ? .20 : .05,
              ),
            ),
          ],
        ),
        child: Row(
          children: [

            Container(
              width: isSmallPhone ? 36 : 42,
              height: isSmallPhone ? 36 : 42,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.circle,
                color: color,
                size: isSmallPhone ? 10 : 12,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Text(
                    title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize:
                          isSmallPhone ? 11 : 13,
                      color: Colors.grey[700],
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "$value",
                    style: TextStyle(
                      fontSize: valueFont,
                      color: selected
                          ? color
                          : Colors.black87,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 250),
              child: selected
                  ? Icon(
                      Icons.check_circle,
                      color: color,
                      key: ValueKey(filter),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _attendancePhoto({
  required String title,
  required String image,
}) {
  return SizedBox(
    width: imageWidth,
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [

        Text(
          title,
          style: TextStyle(
            fontSize: bodyFont,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FullScreenImage(
                  imageUrl: image,
                ),
              ),
            );
          },
          child: Hero(
            tag: image,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(cardRadius),
              child: Image.network(
                image,
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                  width: imageWidth,
                  height: imageHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius:
                        BorderRadius.circular(
                            cardRadius),
                  ),
                  child: const Icon(
                    Icons.broken_image,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _salaryRow(
  String title,
  String value, {
  bool bold = false,
  Color? valueColor,
}) {
  return Padding(
    padding:
        const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [

        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: bodyFont,
            ),
          ),
        ),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: bodyFont + 1,
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    ),
  );
}
    }