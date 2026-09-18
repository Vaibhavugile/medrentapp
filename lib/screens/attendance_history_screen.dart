import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

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
String? salarySlipUrl;
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
        // Load salary slip for selected month
final salarySlipDoc = await db
    .collection('payrollStatus')
    .doc('${widget.userId}_$monthKey')
    .get();

salarySlipUrl = salarySlipDoc.data()?['salarySlipUrl'];

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

  // =====================================================
  // NO ATTENDANCE DOCUMENT
  // =====================================================

  if (raw == null) {
    final duration = 0;

    String type = "absent";
    a++;

    mins += duration;

    list.add({
      "date": dayId,
      "shift": 1,
      "minutes": duration,
      "type": type,
      "checkInServer": null,
      "checkOutServer": null,
      "checkInPhotoUrl": null,
      "checkOutPhotoUrl": null,
      "note": "",
    });

    continue;
  }

  // =====================================================
  // SHIFT 1
  // =====================================================

  final Map<String, dynamic>? shift1 =
      raw['shifts']?['1'] != null
          ? Map<String, dynamic>.from(raw['shifts']['1'])
          : null;

  final shift1CheckIn =
      shift1?['checkInServer'] ??
      shift1?['checkInMs'] ??
      raw['checkInServer'] ??
      raw['checkInMs'];

  final shift1CheckOut =
      shift1?['checkOutServer'] ??
      shift1?['checkOutMs'] ??
      raw['checkOutServer'] ??
      raw['checkOutMs'];

  int shift1Duration = 0;

  if (shift1CheckIn != null) {
    final start = shift1CheckIn is Timestamp
        ? shift1CheckIn.toDate()
        : DateTime.fromMillisecondsSinceEpoch(
            shift1CheckIn,
          );

    final end = shift1CheckOut != null
        ? (shift1CheckOut is Timestamp
            ? shift1CheckOut.toDate()
            : DateTime.fromMillisecondsSinceEpoch(
                shift1CheckOut,
              ))
        : DateTime.now();

    shift1Duration = end.difference(start).inMinutes;
  }

  String shift1Type;

  if (shift1Duration >= 525) {
    shift1Type = "present";
    p++;
  } else if (shift1Duration >= 480) {
    if (graceUsed < 2) {
      graceUsed++;
      shift1Type = "grace";
      g++;
    } else {
      shift1Type = "half";
      h++;
    }
  } else if (shift1Duration >= 240) {
    shift1Type = "half";
    h++;
  } else {
    shift1Type = "absent";
    a++;
  }

  mins += shift1Duration;

  list.add({
    "date": dayId,
    "shift": 1,
    "minutes": shift1Duration,
    "type": shift1Type,
    "checkInServer": shift1CheckIn,
    "checkOutServer": shift1CheckOut,
    "checkInPhotoUrl":
        shift1?['checkInPhotoUrl'] ??
        raw['check-inPhotoUrl'],
    "checkOutPhotoUrl":
        shift1?['checkOutPhotoUrl'] ??
        raw['check-outPhotoUrl'],
    "note":
        shift1?['note'] ??
        raw['note'] ??
        "",
  });

  // =====================================================
  // SHIFT 2
  // =====================================================

  final Map<String, dynamic>? shift2 =
      raw['shifts']?['2'] != null
          ? Map<String, dynamic>.from(raw['shifts']['2'])
          : null;

  if (shift2 != null) {
    final shift2CheckIn =
        shift2['checkInServer'] ??
        shift2['checkInMs'];

    final shift2CheckOut =
        shift2['checkOutServer'] ??
        shift2['checkOutMs'];

    int shift2Duration = 0;

    if (shift2CheckIn != null) {
      final start = shift2CheckIn is Timestamp
          ? shift2CheckIn.toDate()
          : DateTime.fromMillisecondsSinceEpoch(
              shift2CheckIn,
            );

      final end = shift2CheckOut != null
          ? (shift2CheckOut is Timestamp
              ? shift2CheckOut.toDate()
              : DateTime.fromMillisecondsSinceEpoch(
                  shift2CheckOut,
                ))
          : DateTime.now();

      shift2Duration = end.difference(start).inMinutes;
    }

    String shift2Type;

    if (shift2Duration >= 525) {
      shift2Type = "present";
      p++;
    } else if (shift2Duration >= 480) {
      if (graceUsed < 2) {
        graceUsed++;
        shift2Type = "grace";
        g++;
      } else {
        shift2Type = "half";
        h++;
      }
    } else if (shift2Duration >= 240) {
      shift2Type = "half";
      h++;
    } else {
      shift2Type = "absent";
      a++;
    }

    mins += shift2Duration;

    list.add({
      "date": dayId,
      "shift": 2,
      "minutes": shift2Duration,
      "type": shift2Type,
      "checkInServer": shift2CheckIn,
      "checkOutServer": shift2CheckOut,
      "checkInPhotoUrl":
          shift2['checkInPhotoUrl'] ??
          "",
      "checkOutPhotoUrl":
          shift2['checkOutPhotoUrl'] ??
          "",
      "note": shift2['note'] ?? "",
    });
  }
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
bool isSunday(String dateString) {
  final parts = dateString.split("-");

  final date = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );

  return date.weekday == DateTime.sunday;
}
  //---------------------------------------------------------
  // Month Picker
  //---------------------------------------------------------
void openSalarySlip() {
  if (salarySlipUrl == null || salarySlipUrl!.isEmpty) {
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text("Salary Slip"),
          actions: [
            IconButton(
              tooltip: 'Download PDF',
              icon: const Icon(Icons.download),
              onPressed: downloadSalarySlip,
            ),
          ],
        ),
        body: SfPdfViewer.network(
          salarySlipUrl!,
        ),
      ),
    ),
  );
}
Future<void> downloadSalarySlip() async {
  if (salarySlipUrl == null || salarySlipUrl!.isEmpty) {
    return;
  }

  try {
    // Show downloading message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading salary slip...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final response = await http.get(
      Uri.parse(salarySlipUrl!),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Download failed: ${response.statusCode}',
      );
    }

    // Android public Downloads directory
    final downloadsDir = Directory(
      '/storage/emulated/0/Download',
    );

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(
        recursive: true,
      );
    }

    final fileName = 'Salary_Slip_$monthKey.pdf';

    final file = File(
      '${downloadsDir.path}/$fileName',
    );

    await file.writeAsBytes(
      response.bodyBytes,
      flush: true,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Salary slip saved to Downloads/$fileName',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () {
            OpenFilex.open(file.path);
          },
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      'Salary slip download error: $e',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Failed to download salary slip',
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    initializeResponsive(context);

    final filteredRecords = selectedFilter == "all"
        ? records
        : records.where((e) => e["type"] == selectedFilter).toList();

    if (loading) {
      return const Scaffold(
        backgroundColor: _AttendanceTheme.background,
        body: Center(
          child: CircularProgressIndicator(
            color: _AttendanceTheme.primary,
            strokeWidth: 2.8,
          ),
        ),
      );
    }

    final presentLike = present + grace;
    final totalDays = records.where((r) => r["shift"] == 1).length;
    final attendancePercent =
        totalDays == 0 ? 0.0 : (presentLike / totalDays) * 100;

    return Scaffold(
      backgroundColor: _AttendanceTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildPremiumHeader()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pagePadding, 14, pagePadding, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildMonthCard(),
                  const SizedBox(height: 14),
                  _buildPerformanceCard(attendancePercent),
                  const SizedBox(height: 14),
                  _buildSummaryGrid(),
                  const SizedBox(height: 14),
                  _buildSalaryCard(),
                  const SizedBox(height: 22),
                  _buildDailyHeader(filteredRecords.length),
                  const SizedBox(height: 10),
                  if (filteredRecords.isEmpty)
                    _buildEmptyState()
                  else
                    ...filteredRecords.map(_buildAttendanceTimelineCard),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(pagePadding, 18, pagePadding, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_AttendanceTheme.heroDark, _AttendanceTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _headerIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Attendance History",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFont + 2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Attendance • Hours • Salary",
                      style: TextStyle(
                        color: Colors.white.withOpacity(.72),
                        fontSize: bodyFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _headerIconButton(
                icon: Icons.calendar_month_rounded,
                onTap: pickMonth,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(.16)),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthKey,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFont + 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Monthly attendance overview",
                      style: TextStyle(
                        color: Colors.white.withOpacity(.68),
                        fontSize: bodyFont - .5,
                      ),
                    ),
                  ],
                ),
              ),
              _headerMetric("Hours", hhmm(totalMinutes)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.11),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _headerMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.white.withOpacity(.62),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }

  Widget _buildMonthCard() {
    return Material(
      color: _AttendanceTheme.surface,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: pickMonth,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: _AttendanceTheme.border),
            boxShadow: _AttendanceTheme.shadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _AttendanceTheme.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.date_range_rounded,
                    color: _AttendanceTheme.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Selected month",
                        style: TextStyle(
                          color: _AttendanceTheme.muted,
                          fontSize: bodyFont - 1,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 2),
                    Text(monthKey,
                        style: TextStyle(
                          color: _AttendanceTheme.text,
                          fontSize: subtitleFont,
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _AttendanceTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(double attendancePercent) {
    final percent = attendancePercent.clamp(0.0, 100.0);
    final presentLike = present + grace;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AttendanceTheme.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: _AttendanceTheme.border),
        boxShadow: _AttendanceTheme.shadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 7,
                  backgroundColor: _AttendanceTheme.primarySoft,
                  color: _AttendanceTheme.primary,
                ),
                Text("${percent.round()}%",
                    style: const TextStyle(
                      color: _AttendanceTheme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Attendance performance",
                    style: TextStyle(
                      color: _AttendanceTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 5),
                Text(
                  "$presentLike present/grace days • $absent absent • $half half day",
                  style: TextStyle(
                    color: _AttendanceTheme.muted,
                    fontSize: bodyFont,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final items = [
      ("Present", present, _AttendanceTheme.green, "present", Icons.check_circle_rounded),
      ("Grace", grace, _AttendanceTheme.orange, "grace", Icons.schedule_rounded),
      ("Half Day", half, _AttendanceTheme.blue, "half", Icons.timelapse_rounded),
      ("Absent", absent, _AttendanceTheme.red, "absent", Icons.cancel_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isSmallPhone ? 1.55 : isTablet ? 1.55 : 1.75,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _premiumSummaryCard(
          title: item.$1,
          value: item.$2,
          color: item.$3,
          filter: item.$4,
          icon: item.$5,
        );
      },
    );
  }

  Widget _premiumSummaryCard({
    required String title,
    required int value,
    required Color color,
    required String filter,
    required IconData icon,
  }) {
    final selected = selectedFilter == filter;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: () => setState(() {
          selectedFilter = selected ? "all" : filter;
        }),
        borderRadius: BorderRadius.circular(cardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.08) : _AttendanceTheme.surface,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: selected ? color.withOpacity(.55) : _AttendanceTheme.border,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: _AttendanceTheme.shadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _AttendanceTheme.muted,
                          fontSize: bodyFont - 1,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text("$value",
                        style: TextStyle(
                          color: selected ? color : _AttendanceTheme.text,
                          fontSize: valueFont - 1,
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryCard() {
    final hasSlip = salarySlipUrl != null && salarySlipUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AttendanceTheme.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: _AttendanceTheme.border),
        boxShadow: _AttendanceTheme.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _AttendanceTheme.greenSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: _AttendanceTheme.green, size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Salary Summary",
                        style: TextStyle(
                          color: _AttendanceTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        )),
                    SizedBox(height: 2),
                    Text("Calculated from monthly attendance",
                        style: TextStyle(
                          color: _AttendanceTheme.muted,
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _AttendanceTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _salaryRow("Total Hours", hhmm(totalMinutes)),
                _salaryDivider(),
                _salaryRow("Calculated Salary", "₹${salary.round()}",
                    valueColor: _AttendanceTheme.green, bold: true),
                _salaryDivider(),
                _salaryRow("Base Monthly Salary", "₹${monthlySalary.round()}"),
              ],
            ),
          ),
          if (hasSlip) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: openSalarySlip,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                label: const Text("View Salary Slip"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _AttendanceTheme.primary,
                  side: const BorderSide(color: _AttendanceTheme.borderStrong),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _salaryDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, color: _AttendanceTheme.border),
      );

  Widget _buildDailyHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Daily Attendance",
                  style: TextStyle(
                    color: _AttendanceTheme.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
              SizedBox(height: 3),
              Text("Check-in, check-out, hours and verification photos",
                  style: TextStyle(
                    color: _AttendanceTheme.muted,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: _AttendanceTheme.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text("$count records",
              style: const TextStyle(
                color: _AttendanceTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              )),
        ),
      ],
    );
  }

  Widget _buildAttendanceTimelineCard(Map<String, dynamic> r) {
    final sunday = isSunday(r["date"]);
    final color = sunday ? _AttendanceTheme.red : getTypeColor(r["type"]);
    final minutes = r["minutes"] is int
        ? r["minutes"] as int
        : int.tryParse("${r["minutes"]}") ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 21),
                  decoration: BoxDecoration(
                    color: _AttendanceTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 4),
                  ),
                ),
                Container(
                  width: 2,
                  height: 185,
                  color: _AttendanceTheme.border,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sunday ? _AttendanceTheme.redSoft : _AttendanceTheme.surface,
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(
                  color: sunday
                      ? _AttendanceTheme.red.withOpacity(.25)
                      : _AttendanceTheme.border,
                ),
                boxShadow: _AttendanceTheme.shadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sunday ? "${r["date"]} • SUNDAY" : "${r["date"]}",
                              style: TextStyle(
                                color: sunday
                                    ? _AttendanceTheme.red
                                    : _AttendanceTheme.text,
                                fontSize: subtitleFont,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("Shift ${r["shift"]}",
                                style: const TextStyle(
                                  color: _AttendanceTheme.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                      _statusBadge("${r["type"]}", color),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _timelineInfoRow(
                    icon: Icons.login_rounded,
                    title: "Check In",
                    value: formatTime(r["checkInServer"]),
                    color: _AttendanceTheme.green,
                  ),
                  const SizedBox(height: 9),
                  _timelineInfoRow(
                    icon: Icons.logout_rounded,
                    title: "Check Out",
                    value: formatTime(r["checkOutServer"]),
                    color: _AttendanceTheme.red,
                  ),
                  const SizedBox(height: 9),
                  _timelineInfoRow(
                    icon: Icons.timer_outlined,
                    title: "Duration",
                    value: hhmm(minutes),
                    color: _AttendanceTheme.primary,
                  ),
                  if ((r["note"] ?? "").toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _AttendanceTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(r["note"].toString(),
                          style: const TextStyle(
                            color: _AttendanceTheme.textSoft,
                            fontSize: 12,
                            height: 1.35,
                          )),
                    ),
                  ],
                  if (r["checkInPhotoUrl"] != null ||
                      r["checkOutPhotoUrl"] != null) ...[
                    const SizedBox(height: 14),
                    const Text("Verification Photos",
                        style: TextStyle(
                          color: _AttendanceTheme.textSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (r["checkInPhotoUrl"] != null)
                          _attendancePhoto(
                              title: "Check In",
                              image: r["checkInPhotoUrl"]),
                        if (r["checkOutPhotoUrl"] != null)
                          _attendancePhoto(
                              title: "Check Out",
                              image: r["checkOutPhotoUrl"]),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
      ),
    );
  }

  Widget _timelineInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                color: _AttendanceTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ),
        Text(value,
            style: const TextStyle(
              color: _AttendanceTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            )),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: _AttendanceTheme.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: _AttendanceTheme.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_busy_rounded,
              size: 44, color: _AttendanceTheme.muted),
          SizedBox(height: 12),
          Text("No attendance records",
              style: TextStyle(
                color: _AttendanceTheme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              )),
          SizedBox(height: 5),
          Text(
            "Try another filter or select a different month.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _AttendanceTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String title,
    int value,
    Color color,
    String filter,
  ) {
    return _premiumSummaryCard(
      title: title,
      value: value,
      color: color,
      filter: filter,
      icon: Icons.circle,
    );
  }

  Widget _attendancePhoto({
    required String title,
    required String image,
  }) {
    return SizedBox(
      width: imageWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                color: _AttendanceTheme.textSoft,
                fontSize: bodyFont,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImage(imageUrl: image),
                ),
              );
            },
            child: Hero(
              tag: image,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(cardRadius),
                child: Image.network(
                  image,
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: imageWidth,
                    height: imageHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _AttendanceTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(cardRadius),
                    ),
                    child: const Icon(Icons.broken_image_rounded,
                        color: _AttendanceTheme.muted),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                  color: _AttendanceTheme.muted,
                  fontSize: bodyFont,
                  fontWeight: FontWeight.w500,
                )),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? _AttendanceTheme.text,
                  fontSize: bodyFont + 1,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTheme {
  static const background = Color(0xffF6F8FC);
  static const surface = Color(0xffFFFFFF);
  static const surfaceAlt = Color(0xffF1F4F9);

  static const text = Color(0xff101828);
  static const textSoft = Color(0xff344054);
  static const muted = Color(0xff667085);

  static const border = Color(0xffE4E7EC);
  static const borderStrong = Color(0xffD0D5DD);

  static const primary = Color(0xff3157D5);
  static const primarySoft = Color(0xffEEF2FF);
  static const heroDark = Color(0xff172554);

  static const green = Color(0xff059669);
  static const greenSoft = Color(0xffECFDF3);
  static const blue = Color(0xff2563EB);
  static const orange = Color(0xffD97706);
  static const red = Color(0xffDC2626);
  static const redSoft = Color(0xffFEF2F2);

  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ];
}
