import 'dart:async';
import 'package:flutter/material.dart';
import '../../marketing/leads_service.dart';
import 'lead_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class LeadsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const LeadsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _svc = LeadsService();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  List<Map<String, dynamic>> _all = [];

  String _q = '';
  String _sortBy = 'latest';

String _filterType = 'all';
DateTimeRange? _dateRange;
List<Map<String, dynamic>> _leadSources = [];
bool _loadingLeadSources = false;
bool _duplicatesOnly = false;
  Map<String, dynamic> _draft = {};

  /// Lightweight relationship cache used by the lead cards.
  /// Each card can independently discover whether a requirement, quotation,
  /// or order exists for the lead without changing the existing LeadsService.
  final Map<String, _LeadTimelineData> _timelineCache = {};
  final Set<String> _timelineLoading = {};

  bool loading = true;

  final _customerCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _status = 'new';
String _type = '';
 
@override
void initState() {
  super.initState();

  _loadLeadSources();

  _sub = _svc.streamMyLeads(widget.userId).listen((list) {
    if (!mounted) return;

    setState(() {
      _all = list;
      loading = false;
    });
  });
}

  @override
  void dispose() {
    _sub?.cancel();

_customerCtrl.dispose();
_contactCtrl.dispose();
_phoneCtrl.dispose();
_emailCtrl.dispose();
_addrCtrl.dispose();
_sourceCtrl.dispose();
_notesCtrl.dispose();

super.dispose();
  }

List<Map<String, dynamic>> get _filtered {

  List<Map<String, dynamic>> data =
      [..._all];

  /// SEARCH

  final q = _q.toLowerCase();

  if (q.isNotEmpty) {

    data = data.where((l) {

      final text = [

        l['customerName'],
        l['contactPerson'],
        l['phone'],
        l['email'],
        l['leadSource'],
        l['notes'],
        l['type'],

      ].join(' ').toLowerCase();

      return text.contains(q);

    }).toList();
  }

  /// TYPE FILTER

  if (_filterType != 'all') {

    data = data.where((l) {

      return l['type'] == _filterType;

    }).toList();
  }

  /// DUPLICATE FILTER

  if (_duplicatesOnly) {

    data = data.where((l) {

      return l['isDuplicate'] == true;

    }).toList();
  }

/// DATE FILTER

if (_dateRange != null) {

  data = data.where((l) {

    final created =
        l['createdAt'];

    if (created == null) {
      return false;
    }

    final date =
        created.toDate();

    return date.isAfter(

          _dateRange!.start.subtract(
            const Duration(days: 1),
          ),
        ) &&
        date.isBefore(

          _dateRange!.end.add(
            const Duration(days: 1),
          ),
        );
  }).toList();
}
  /// SORT

  data.sort((a, b) {

    final aDate =
        a['createdAt'];

    final bDate =
        b['createdAt'];

    if (aDate == null ||
        bDate == null) {
      return 0;
    }

    final aTime =
        aDate.toDate();

    final bTime =
        bDate.toDate();

    if (_sortBy == 'latest') {

      return bTime.compareTo(aTime);
    }

    return aTime.compareTo(bTime);
  });

  return data;
}
Future<void> _loadLeadSources() async {
  if (_loadingLeadSources) return;

  setState(() {
    _loadingLeadSources = true;
  });

  try {
    final snap = await FirebaseFirestore.instance
        .collection('leadSources')
        .where('active', isEqualTo: true)
        .get();

    final sources = snap.docs
        .map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'active': data['active'] ?? true,
          };
        })
        .where((source) => source['name'].toString().trim().isNotEmpty)
        .toList();

    sources.sort(
      (a, b) => a['name']
          .toString()
          .toLowerCase()
          .compareTo(
            b['name'].toString().toLowerCase(),
          ),
    );

    if (!mounted) return;

    setState(() {
      _leadSources = sources;
    });
  } catch (e) {
    debugPrint('Load lead sources error: $e');
  } finally {
    if (mounted) {
      setState(() {
        _loadingLeadSources = false;
      });
    }
  }
}

void _saveDraft() {
  _draft = {
    'customer': _customerCtrl.text,
    'contact': _contactCtrl.text,
    'phone': _phoneCtrl.text,
    'email': _emailCtrl.text,
    'address': _addrCtrl.text,
    'source': _sourceCtrl.text,
    'notes': _notesCtrl.text,
    'type': _type,
  };
}
void _clearDraft() {

  _draft.clear();
}
 Future<void> _addLeadSheet() async {

  _customerCtrl.text = _draft['customer'] ?? '';
_contactCtrl.text = _draft['contact'] ?? '';
_phoneCtrl.text = _draft['phone'] ?? '';
_emailCtrl.text = _draft['email'] ?? '';
_addrCtrl.text = _draft['address'] ?? '';
_sourceCtrl.text = _draft['source'] ?? '';
_notesCtrl.text = _draft['notes'] ?? '';
_type = _draft['type'] ?? '';

  _status = 'new';

  await showModalBottomSheet(

    context: context,

    isScrollControlled: true,
isDismissible: false,
enableDrag: false,
    backgroundColor: Colors.transparent,

    builder: (_) {

      final kb =
          MediaQuery.of(context)
              .viewInsets
              .bottom;

      return AnimatedPadding(

        duration: const Duration(
          milliseconds: 220,
        ),

        padding: EdgeInsets.only(
          bottom: kb,
        ),

        child: SafeArea(

          child: DraggableScrollableSheet(

            expand: false,

            initialChildSize: 0.92,

            minChildSize: 0.6,

            maxChildSize: 0.96,

            builder: (
              ctx,
              scrollController,
            ) {

              return StatefulBuilder(

                builder: (
                  ctx,
                  setModalState,
                ) {

                  return WillPopScope(

  onWillPop: () async {

    final hasData =

        _customerCtrl.text.isNotEmpty ||

        _contactCtrl.text.isNotEmpty ||

        _phoneCtrl.text.isNotEmpty ||

        _emailCtrl.text.isNotEmpty ||

        _notesCtrl.text.isNotEmpty;

    /// NO DATA
   if (!hasData) {

  Navigator.pop(context);

  return false;
}

    /// ASK BEFORE CLOSE
    final shouldClose =
        await showDialog<bool>(

      context: context,

      builder: (_) {

        return AlertDialog(

          title: const Text(
            "Save Draft?",
          ),

          content: const Text(

            "Your entered form data will be restored later.",
          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(
                  context,
                  false,
                );
              },

              child: const Text(
                "Continue Editing",
              ),
            ),

            FilledButton(

              onPressed: () {

                _saveDraft();

                Navigator.pop(
                  context,
                  true,
                );
              },

              child: const Text(
                "Close",
              ),
            ),
          ],
        );
      },
    );

    return shouldClose ?? false;
  },

  child: Container(

                    decoration:
                        const BoxDecoration(

                      color:
                          Color(0xfff8fafc),

                      borderRadius:
                          BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),

                    child: ClipRRect(

                      borderRadius:
                          const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),

                     child: LayoutBuilder(

                       builder: (context, constraints) {

                       return SingleChildScrollView(

                          controller: scrollController,

                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior
                        .onDrag,

                         physics:
                        const BouncingScrollPhysics(),

                      padding: EdgeInsets.fromLTRB(

                      20,
                      20,
                      20,

                      MediaQuery.of(context)
                              .viewInsets
                              .bottom +
                          40,
                    ),

                   child: ConstrainedBox(

               constraints: BoxConstraints(
          minHeight:
              constraints.maxHeight,
        ),

        child: IntrinsicHeight(

          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                            children: [

                              /// HANDLE
                              Center(
                                child: Container(

                                  width: 55,
                                  height: 6,

                                  decoration:
                                      BoxDecoration(

                                    color:
                                        Colors.grey
                                            .shade300,

                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      100,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 24,
                              ),

                              /// HEADER
                              Row(
                                children: [

                                  Container(

                                    padding:
                                        const EdgeInsets
                                            .all(14),

                                    decoration:
                                        BoxDecoration(

                                      gradient:
                                          LinearGradient(
                                        colors: [

                                          Colors
                                              .indigo
                                              .shade400,

                                          Colors
                                              .blue
                                              .shade400,
                                        ],
                                      ),

                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        18,
                                      ),
                                    ),

                                    child: const Icon(

                                      Icons
                                          .auto_graph_rounded,

                                      color:
                                          Colors.white,

                                      size: 28,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 16,
                                  ),

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [

                                        Text(

                                          "Create Lead",

                                          style:
                                              TextStyle(

                                            fontSize:
                                                26,

                                            fontWeight:
                                                FontWeight
                                                    .w800,

                                            color:
                                                Colors
                                                    .grey
                                                    .shade900,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 4,
                                        ),

                                        Text(

                                          "Track customers beautifully",

                                          style:
                                              TextStyle(
                                            color:
                                                Colors
                                                    .grey
                                                    .shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(

                   onPressed: () async {

                      final hasData =

                  _customerCtrl.text.isNotEmpty ||

                  _contactCtrl.text.isNotEmpty ||

                  _phoneCtrl.text.isNotEmpty;

              if (!hasData) {

                Navigator.pop(context);

                return;
              }

              final shouldClose =
                  await showDialog<bool>(

                context: context,

                builder: (_) {

                  return AlertDialog(

                    title: const Text(
                      "Save Draft?",
                    ),

                    content: const Text(

                      "Your form will be restored next time.",
                    ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(
                  context,
                  false,
                );
              },

              child: const Text(
                "Cancel",
              ),
            ),

            FilledButton(

              onPressed: () {

                _saveDraft();

                Navigator.pop(
                  context,
                  true,
                );
              },

              child: const Text(
                "Close",
              ),
            ),
          ],
        );
      },
    );

    if (shouldClose == true) {

      Navigator.pop(context);
    }
  },

                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                                ],
                              ),

                              const SizedBox(
                                height: 28,
                              ),

                              /// TYPE
                              Text(

                                "Lead Type",

                                style: TextStyle(

                                  fontSize: 15,

                                  fontWeight:
                                      FontWeight
                                          .w700,

                                  color:
                                      Colors.grey
                                          .shade800,
                                ),
                              ),

                              const SizedBox(
                                height: 14,
                              ),

                              Wrap(

                                spacing: 10,
                                runSpacing: 10,

                                children: [

                                  _leadTypeChip(

                                    label:
                                        "Equipment",

                                    value:
                                        "equipment",

                                    icon: Icons
                                        .medical_services_outlined,

                                    setModalState:
                                        setModalState,
                                  ),

                                  _leadTypeChip(

                                    label:
                                        "Nursing",

                                    value:
                                        "nursing",

                                    icon: Icons
                                        .local_hospital_outlined,

                                    setModalState:
                                        setModalState,
                                  ),

                                  _leadTypeChip(

                                    label:
                                        "Caretaker",

                                    value:
                                        "caretaker",

                                    icon: Icons
                                        .health_and_safety_outlined,

                                    setModalState:
                                        setModalState,
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 28,
                              ),

                             /// CUSTOMER + CONTACT



   _premiumField(

    controller: _customerCtrl,

    label: "Customer / Hospital",

    icon: Icons.business_outlined,
  ),



const SizedBox(
  height: 16,
),
 _premiumField(

    controller: _contactCtrl,

    label: "Contact Person",

    icon: Icons.person_outline,
  ),

const SizedBox(
  height: 16,
),

/// PHONE + EMAIL

 _premiumField(

    controller: _phoneCtrl,

    label: "Phone Number",

    icon: Icons.call_outlined,

    keyboard: TextInputType.phone,
  ),
  const SizedBox(
  height: 16,
),

  _premiumField(

    controller: _emailCtrl,

    label: "Email Address",

    icon: Icons.mail_outline,
  ),
  const SizedBox(
  height: 16,
),




/// ADDRESS

_premiumField(

  controller: _addrCtrl,

  label: "Address / City",

  icon: Icons.location_on_outlined,

  maxLines: 2,
),

const SizedBox(
  height: 16,
),

/// SOURCE + NOTES



 _buildLeadSourceField(setModalState),


  _premiumField(

    controller: _notesCtrl,

    label: "Notes",

    icon: Icons.notes_outlined,

    maxLines: 3,
  ),


                                  const SizedBox(
                                    height: 32,
                                  ),
                              SizedBox(

                                width:
                                    double.infinity,

                                height: 58,

                                child:
                                    DecoratedBox(

                                  decoration:
                                      BoxDecoration(

                                    gradient:
                                        LinearGradient(
                                      colors: [

                                        Colors
                                            .indigo
                                            .shade500,

                                        Colors
                                            .blue
                                            .shade500,
                                      ],
                                    ),

                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      18,
                                    ),

                                    boxShadow: [

                                      BoxShadow(

                                        color: Colors
                                            .indigo
                                            .withOpacity(
                                          .22,
                                        ),

                                        blurRadius:
                                            18,

                                        offset:
                                            const Offset(
                                          0,
                                          10,
                                        ),
                                      ),
                                    ],
                                  ),

                                  child:
                                      ElevatedButton(

                                    style:
                                        ElevatedButton
                                            .styleFrom(

                                      backgroundColor:
                                          Colors
                                              .transparent,

                                      shadowColor:
                                          Colors
                                              .transparent,

                                      shape:
                                          RoundedRectangleBorder(

                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          18,
                                        ),
                                      ),
                                    ),

                                    onPressed:
                                        () async {

                                      final cust =
                                          _customerCtrl
                                              .text
                                              .trim();

                                      final cont =
                                          _contactCtrl
                                              .text
                                              .trim();

                                      final ph =
                                          _phoneCtrl
                                              .text
                                              .trim();

                                      if (

    _type.isEmpty ||

    cust.isEmpty ||

    cont.isEmpty ||

    ph.isEmpty

) {

                                        ScaffoldMessenger
                                                .of(
                                                    context)
                                            .showSnackBar(

                                          SnackBar(

                                            backgroundColor:
                                                Colors
                                                    .red,

                                            behavior:
                                                SnackBarBehavior
                                                    .floating,

                                            content:
                                                const Text(

                                              "Select lead type and fill all required fields",
                                            ),
                                          ),
                                        );

                                        return;
                                      }

                                      /// DUPLICATE
                                      final isDuplicate =
                                          await _svc
                                              .checkDuplicate(

                                        phone: ph,

                                        type: _type,
                                      );

                                      if (isDuplicate) {

                                        final proceed =
                                            await showDialog<bool>(

                                          context:
                                              context,

                                          builder:
                                              (_) {

                                            return AlertDialog(

                                              shape:
                                                  RoundedRectangleBorder(

                                                borderRadius:
                                                    BorderRadius.circular(
                                                  24,
                                                ),
                                              ),

                                              title:
                                                  const Text(
                                                "Duplicate Lead",
                                              ),

                                              content:
                                                  const Text(

                                                "Lead with same phone and type already exists.\n\nContinue anyway?",
                                              ),

                                              actions: [

                                                TextButton(

                                                  onPressed:
                                                      () {

                                                    Navigator.pop(
                                                      context,
                                                      false,
                                                    );
                                                  },

                                                  child:
                                                      const Text(
                                                    "Cancel",
                                                  ),
                                                ),

                                                FilledButton(

                                                  onPressed:
                                                      () {

                                                    Navigator.pop(
                                                      context,
                                                      true,
                                                    );
                                                  },

                                                  child:
                                                      const Text(
                                                    "Create Anyway",
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (proceed !=
                                            true) {
                                          return;
                                        }
                                      }

                                      Navigator.pop(
                                        context,
                                      );

                                      await _svc
                                          .createLeadDetailed(

                                        ownerId:
                                            widget
                                                .userId,

                                        ownerName:
                                            widget
                                                .userName,

                                        customerName:
                                            cust,

                                        contactPerson:
                                            cont,

                                        phone: ph,

                                        email:
                                            _emailCtrl
                                                .text
                                                .trim(),

                                        address:
                                            _addrCtrl
                                                .text
                                                .trim(),

                                        leadSource:
                                            _sourceCtrl
                                                .text
                                                .trim(),

                                        notes:
                                            _notesCtrl
                                                .text
                                                .trim(),

                                        status:
                                            _status,

                                        type:
                                            _type,
                                      );
                                      _clearDraft();
                                    },

                                    child:
                                        const Text(

                                      "Create Lead",

                                      style:
                                          TextStyle(

                                        fontSize:
                                            17,

                                        fontWeight:
                                            FontWeight
                                                .w700,

                                        color:
                                            Colors
                                                .white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                       );
                  },
                ),
                    ),
                    
                    ),
);
                },
              );
            },
          ),
        ),
      );
    },
  );
}
Widget _twoFields({

  required Widget left,
  required Widget right,

}) {

  return Row(

    children: [

      Expanded(
        child: left,
      ),

      const SizedBox(width: 12),

      Expanded(
        child: right,
      ),
    ],
  );
}
Widget _leadTypeChip({

  required String label,
  required String value,
  required IconData icon,
  required StateSetter setModalState,

}) {

  final active = _type == value;

  return GestureDetector(

    onTap: () {

      setModalState(() {

        _type = value;

_saveDraft();

      });
    },

    child: AnimatedContainer(

      duration: const Duration(
        milliseconds: 220,
      ),

      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),

      decoration: BoxDecoration(

        color: active
            ? Colors.indigo
            : Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: active
              ? Colors.indigo
              : Colors.grey.shade300,
        ),

        boxShadow: [

          BoxShadow(
            color: active
                ? Colors.indigo.withOpacity(.2)
                : Colors.black.withOpacity(.04),

            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(
            icon,
            size: 18,

            color: active
                ? Colors.white
                : Colors.grey.shade700,
          ),

          const SizedBox(width: 8),

          Text(
            label,

            style: TextStyle(
              fontWeight: FontWeight.w600,

              color: active
                  ? Colors.white
                  : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _premiumField({

  required TextEditingController controller,
  required String label,
  required IconData icon,

  int maxLines = 1,

  TextInputType keyboard =
      TextInputType.text,

}) {

  final isNotes =
      label.toLowerCase().contains(
    'notes',
  );

  return Container(

    decoration: BoxDecoration(

      color: Colors.white,

      borderRadius:
          BorderRadius.circular(18),

      boxShadow: [

        BoxShadow(
          color: Colors.black.withOpacity(.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),

    child: TextField(

      controller: controller,
      onChanged: (_) => _saveDraft(),

     maxLines: maxLines,

minLines: maxLines,

      keyboardType: keyboard,

      textInputAction:
          isNotes
              ? TextInputAction.done
              : TextInputAction.next,

     scrollPadding:
    EdgeInsets.only(
  bottom:
      MediaQuery.of(context)
              .viewInsets
              .bottom +
          350,
),
      decoration: InputDecoration(

        hintText: label,

        alignLabelWithHint:
            maxLines > 1,

        prefixIcon: Padding(

          padding:
              EdgeInsets.only(
            bottom:
                maxLines > 1 ? 72 : 0,
          ),

          child: Icon(
            icon,
            color: Colors.grey.shade500,
          ),
        ),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),

          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(

          borderRadius:
              BorderRadius.circular(18),

          borderSide:
              BorderSide.none,
        ),

        focusedBorder:
            OutlineInputBorder(

          borderRadius:
              BorderRadius.circular(18),

          borderSide: BorderSide(
            color:
                Colors.indigo.shade400,
            width: 1.5,
          ),
        ),

        filled: true,
        fillColor: Colors.white,

        contentPadding:
            EdgeInsets.symmetric(

          horizontal: 18,

          vertical:
              maxLines > 1
                  ? 20
                  : 18,
        ),
      ),
    ),
  );
}

Widget _buildLeadSourceField(
  StateSetter setModalState,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Lead Source',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),

      const SizedBox(height: 8),

      GestureDetector(
        onTap: () async {
          final selected = await _showLeadSourcePicker();

          if (selected != null && mounted) {
            setModalState(() {
              _sourceCtrl.text = selected;
              _saveDraft();
            });
          }
        },
        child: AbsorbPointer(
          child: TextField(
            controller: _sourceCtrl,
            maxLines: 1,
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Select or create lead source',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),

              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 19,
                  color: Color(0xFF2563EB),
                ),
              ),

              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),

              filled: true,
              fillColor: Colors.white,

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                ),
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                ),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),

      if (_sourceCtrl.text.trim().isNotEmpty) ...[
        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: Color(0xFF059669),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _sourceCtrl.text.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
Future<String?> _showLeadSourcePicker() async {
  final searchCtrl = TextEditingController(
    text: _sourceCtrl.text.trim(),
  );

  List<Map<String, dynamic>> filteredSources =
      List<Map<String, dynamic>>.from(_leadSources);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchCtrl.text.trim().toLowerCase();

          filteredSources = _leadSources.where((source) {
            final name = source['name']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

            return query.isEmpty || name.contains(query);
          }).toList();

          final exactExists = _leadSources.any(
            (source) {
              final name = source['name']
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  '';

              return name == query && query.isNotEmpty;
            },
          );

          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context)
                      .viewInsets
                      .bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),

                    // Handle
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius:
                            BorderRadius.circular(100),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),

                          const SizedBox(width: 12),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lead Source',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.w800,
                                    color:
                                        Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Select an existing source or create a new one',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () =>
                                Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Search
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        onChanged: (_) {
                          setSheetState(() {});
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search or type new source...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF2563EB),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          24,
                        ),
                        children: [
                          if (_loadingLeadSources)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(
                                child:
                                    CircularProgressIndicator(
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),

                          if (!_loadingLeadSources &&
                              filteredSources.isEmpty &&
                              query.isEmpty)
                            _buildSourceEmptyState(),

                          // Existing sources
                          ...filteredSources.map(
                            (source) {
                              final name =
                                  source['name']
                                          ?.toString()
                                          .trim() ??
                                      '';

                              final selected =
                                  _sourceCtrl.text
                                          .trim()
                                          .toLowerCase() ==
                                      name.toLowerCase();

                              return Container(
                                margin:
                                    const EdgeInsets.only(
                                  bottom: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(
                                    16,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(
                                            0xFF2563EB,
                                          )
                                        : const Color(
                                            0xFFE5E7EB,
                                          ),
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.pop(
                                      context,
                                      name,
                                    );
                                  },
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration:
                                        BoxDecoration(
                                      color: selected
                                          ? const Color(
                                              0xFF2563EB,
                                            )
                                          : const Color(
                                              0xFFEFF6FF,
                                            ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),
                                    child: Icon(
                                      selected
                                          ? Icons.check_rounded
                                          : Icons
                                              .campaign_outlined,
                                      color: selected
                                          ? Colors.white
                                          : const Color(
                                              0xFF2563EB,
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w700,
                                      color:
                                          Color(0xFF111827),
                                    ),
                                  ),
                                  trailing: selected
                                      ? const Icon(
                                          Icons
                                              .check_circle_rounded,
                                          color:
                                              Color(0xFF2563EB),
                                        )
                                      : const Icon(
                                          Icons
                                              .chevron_right_rounded,
                                          color:
                                              Color(0xFF9CA3AF),
                                        ),
                                ),
                              );
                            },
                          ),

                          // Create new source
                          if (query.isNotEmpty &&
                              !exactExists)
                            _buildCreateSourceTile(
                              context,
                              searchCtrl.text.trim(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
Widget _buildCreateSourceTile(
  BuildContext context,
  String sourceName,
) {
  return Container(
    margin: const EdgeInsets.only(top: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFBFDBFE),
      ),
    ),
    child: ListTile(
      onTap: () async {
        final newSource = sourceName.trim();

        if (newSource.isEmpty) return;

        try {
          final normalized = newSource.toLowerCase();

          // Check again against Firestore
          final existingSnapshot =
              await FirebaseFirestore.instance
                  .collection('leadSources')
                  .where(
                    'active',
                    isEqualTo: true,
                  )
                  .get();

          String? existingName;

          for (final doc in existingSnapshot.docs) {
            final name =
                doc.data()['name']
                        ?.toString()
                        .trim() ??
                    '';

            if (name.toLowerCase() == normalized) {
              existingName = name;
              break;
            }
          }

          // Already exists
          if (existingName != null) {
            if (!mounted) return;

            setState(() {
              _leadSources = _leadSources;
            });

            Navigator.pop(
              context,
              existingName,
            );

            return;
          }

          // Create new source
          final ref = await FirebaseFirestore.instance
              .collection('leadSources')
              .add({
            'name': newSource,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Add locally
          if (mounted) {
            setState(() {
              _leadSources = [
                ..._leadSources,
                {
                  'id': ref.id,
                  'name': newSource,
                  'active': true,
                },
              ];

              _leadSources.sort(
                (a, b) => a['name']
                    .toString()
                    .toLowerCase()
                    .compareTo(
                      b['name']
                          .toString()
                          .toLowerCase(),
                    ),
              );
            });

            Navigator.pop(
              context,
              newSource,
            );
          }
        } catch (e) {
          debugPrint(
            'Create lead source error: $e',
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              behavior:
                  SnackBarBehavior.floating,
              backgroundColor:
                  const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
              content: const Text(
                'Failed to create lead source',
              ),
            ),
          );
        }
      },
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
        ),
      ),
      title: const Text(
        'Create New Source',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1D4ED8),
        ),
      ),
      subtitle: Text(
        '"$sourceName"',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Color(0xFF2563EB),
      ),
    ),
  );
}
Widget _buildSourceEmptyState() {
  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 30,
    ),
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.campaign_outlined,
            size: 28,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No lead sources yet',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Type a source above to create one.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final totalLeads = items.length;

    if (loading) {
      return const Scaffold(
        backgroundColor: _LeadTheme.background,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: _LeadTheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _LeadTheme.background,
      floatingActionButton: _buildFloatingAddButton(),
      body: SafeArea(
        child: Column(
          children: [
            _buildPremiumHeader(items),
            _buildSearchAndFilters(),
            _buildLeadSummary(totalLeads),
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: _LeadTheme.primary,
                      onRefresh: () async {
                        await _loadLeadSources();
                        if (mounted) setState(() {});
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _buildLeadCard(items[i], i),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(List<Map<String, dynamic>> items) {
    final active = items.where((l) {
      final status = (l['status'] ?? 'new').toString().toLowerCase();
      return status != 'closed' && status != 'lost';
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LeadTheme.heroDark,
            _LeadTheme.heroLight,
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: Colors.white.withOpacity(.14),
              ),
            ),
            child: const Icon(
              Icons.groups_2_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leads',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$active active • Track every customer journey',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.70),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _headerIconButton(
            Icons.refresh_rounded,
            onTap: () {
              if (!loading) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 43,
          height: 43,
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          Container(
            decoration: _leadCardDecoration(radius: 17),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search customer, phone, email, source...',
                hintStyle: const TextStyle(
                  color: _LeadTheme.muted,
                  fontSize: 12.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _LeadTheme.primary,
                ),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _q = ''),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _LeadTheme.muted,
                        ),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: const BorderSide(
                    color: _LeadTheme.primary,
                    width: 1.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _filterDropdown(
                  value: _sortBy,
                  icon: Icons.swap_vert_rounded,
                  items: const {
                    'latest': 'Latest',
                    'oldest': 'Oldest',
                  },
                  onChanged: (v) => setState(() => _sortBy = v),
                ),
                const SizedBox(width: 8),
                _filterDropdown(
                  value: _filterType,
                  icon: Icons.category_outlined,
                  items: const {
                    'all': 'All Types',
                    'equipment': 'Equipment',
                    'nursing': 'Nursing',
                    'caretaker': 'Caretaker',
                  },
                  onChanged: (v) => setState(() => _filterType = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _duplicatesOnly,
                  label: const Text('Duplicates'),
                  avatar: const Icon(Icons.copy_all_outlined, size: 16),
                  onSelected: (v) => setState(() => _duplicatesOnly = v),
                  selectedColor: _LeadTheme.error.withOpacity(.10),
                  checkmarkColor: _LeadTheme.error,
                  labelStyle: TextStyle(
                    color: _duplicatesOnly
                        ? _LeadTheme.error
                        : _LeadTheme.textSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: _duplicatesOnly
                        ? _LeadTheme.error.withOpacity(.22)
                        : _LeadTheme.border,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 8),
                _dateFilterButton(),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _LeadTheme.textSoft,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _LeadTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required IconData icon,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _LeadTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: _LeadTheme.muted,
          ),
          items: items.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: _LeadTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _LeadTheme.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _dateFilterButton() {
    final label = _dateRange == null
        ? 'Date'
        : '${_dateRange!.start.day}/${_dateRange!.start.month} - '
            '${_dateRange!.end.day}/${_dateRange!.end.month}';

    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2023),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _dateRange,
        );

        if (picked != null && mounted) {
          setState(() => _dateRange = picked);
        }
      },
      icon: const Icon(Icons.date_range_rounded, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _dateRange == null
            ? _LeadTheme.textSoft
            : _LeadTheme.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: _dateRange == null
              ? _LeadTheme.border
              : _LeadTheme.primary.withOpacity(.25),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _q = '';
      _sortBy = 'latest';
      _filterType = 'all';
      _dateRange = null;
      _duplicatesOnly = false;
    });
  }

  Widget _buildLeadSummary(int totalLeads) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _LeadTheme.primarySoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _LeadTheme.primary.withOpacity(.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_graph_rounded,
                  size: 16,
                  color: _LeadTheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$totalLeads Leads',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _LeadTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Tap a lead to open full journey',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _LeadTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> l, int index) {
    final name = (l['customerName'] ?? 'Customer').toString().trim();
    final type = (l['type'] ?? 'equipment').toString().toLowerCase();
    final status = (l['status'] ?? 'new').toString();
    final duplicate = l['isDuplicate'] == true;

    final typeColor = _leadTypeColor(type);
    final typeIcon = _leadTypeIcon(type);
    final initial = name.isEmpty ? 'C' : name[0].toUpperCase();

    final leadId = (l['id'] ?? '').toString();
    final timeline = _timelineCache[leadId];

    // Start loading the relationship summary lazily for visible cards.
    if (leadId.isNotEmpty &&
        timeline == null &&
        !_timelineLoading.contains(leadId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLeadTimeline(leadId);
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _leadCardDecoration(radius: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LeadDetailsScreen(lead: l),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 51,
                      height: 51,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(.10),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Customer' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _LeadTheme.text,
                              letterSpacing: -.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                typeIcon,
                                size: 13,
                                color: typeColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _prettyType(type),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: typeColor,
                                ),
                              ),
                              if ((l['leadSource'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: _LeadTheme.muted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    l['leadSource'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _LeadTheme.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _statusChip(status),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _LeadTheme.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildLeadContactStrip(l),
                const SizedBox(height: 14),
                _buildMiniJourney(
                  l,
                  timeline,
                ),
                if (duplicate) ...[
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _LeadTheme.error.withOpacity(.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _LeadTheme.error.withOpacity(.12),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _LeadTheme.error,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Potential duplicate lead detected',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _LeadTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadContactStrip(Map<String, dynamic> l) {
    final phone = (l['phone'] ?? '').toString().trim();
    final email = (l['email'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: _LeadTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.phone_outlined,
            size: 15,
            color: _LeadTheme.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              phone.isEmpty ? 'No phone number' : phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _LeadTheme.textSoft,
              ),
            ),
          ),
          if (email.isNotEmpty) ...[
            Container(
              width: 1,
              height: 17,
              color: _LeadTheme.border,
            ),
            const SizedBox(width: 9),
            const Icon(
              Icons.mail_outline_rounded,
              size: 15,
              color: _LeadTheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _LeadTheme.textSoft,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniJourney(
    Map<String, dynamic> lead,
    _LeadTimelineData? data,
  ) {
    final stages = <_JourneyStage>[
      _JourneyStage(
        label: 'Lead',
        icon: Icons.person_add_alt_1_rounded,
        color: _LeadTheme.primary,
        active: true,
        date: _dateFromValue(lead['createdAt']),
      ),
      _JourneyStage(
        label: 'Requirement',
        icon: Icons.assignment_outlined,
        color: _LeadTheme.indigo,
        active: data?.hasRequirement == true,
        date: data?.requirementDate,
      ),
      _JourneyStage(
        label: 'Quotation',
        icon: Icons.request_quote_outlined,
        color: _LeadTheme.purple,
        active: data?.hasQuotation == true,
        date: data?.quotationDate,
      ),
      _JourneyStage(
        label: 'Order',
        icon: Icons.shopping_bag_outlined,
        color: _LeadTheme.green,
        active: data?.hasOrder == true,
        date: data?.orderDate,
      ),
    ];

    final loadingTimeline =
        data == null && (lead['id'] ?? '').toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _LeadTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                size: 15,
                color: _LeadTheme.textSoft,
              ),
              const SizedBox(width: 6),
              const Text(
                'Customer journey',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: _LeadTheme.textSoft,
                ),
              ),
              const Spacer(),
              if (loadingTimeline)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.7,
                    color: _LeadTheme.primary,
                  ),
                )
              else
                Text(
                  _journeyLabel(data),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _LeadTheme.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              for (int i = 0; i < stages.length; i++) ...[
                Expanded(
                  child: _journeyStageTile(stages[i]),
                ),
                if (i != stages.length - 1)
                  SizedBox(
                    width: 12,
                    child: Center(
                      child: Container(
                        height: 2,
                        color: stages[i + 1].active
                            ? stages[i + 1].color.withOpacity(.35)
                            : _LeadTheme.border,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _journeyStageTile(_JourneyStage stage) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: stage.active
                ? stage.color.withOpacity(.10)
                : _LeadTheme.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(
              color: stage.active
                  ? stage.color.withOpacity(.20)
                  : _LeadTheme.border,
            ),
          ),
          child: Icon(
            stage.active
                ? Icons.check_rounded
                : stage.icon,
            size: 17,
            color: stage.active
                ? stage.color
                : _LeadTheme.muted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stage.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: stage.active
                ? stage.color
                : _LeadTheme.muted,
          ),
        ),
        if (stage.active && stage.date != null) ...[
          const SizedBox(height: 2),
          Text(
            _shortDate(stage.date!),
            style: const TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              color: _LeadTheme.muted,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadLeadTimeline(String leadId) async {
    if (_timelineLoading.contains(leadId)) return;

    _timelineLoading.add(leadId);

    try {
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        db
            .collection('requirements')
            .where('leadId', isEqualTo: leadId)
            .limit(1)
            .get(),
        db
            .collection('quotations')
            .where('leadId', isEqualTo: leadId)
            .limit(1)
            .get(),
        db
            .collection('orders')
            .where('leadId', isEqualTo: leadId)
            .limit(1)
            .get(),
        db
            .collection('nursingOrders')
            .where('leadId', isEqualTo: leadId)
            .limit(1)
            .get(),
      ]);

      final requirements = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final quotations = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final equipmentOrders =
          results[2] as QuerySnapshot<Map<String, dynamic>>;
      final nursingOrders =
          results[3] as QuerySnapshot<Map<String, dynamic>>;

      final requirementDate = requirements.docs.isEmpty
          ? null
          : _dateFromValue(
              requirements.docs.first.data()['createdAt'],
            );

      final quotationDate = quotations.docs.isEmpty
          ? null
          : _dateFromValue(
              quotations.docs.first.data()['createdAt'],
            );

      final orderDocs = [
        ...equipmentOrders.docs,
        ...nursingOrders.docs,
      ];

      DateTime? orderDate;
      if (orderDocs.isNotEmpty) {
        orderDate = _dateFromValue(
          orderDocs.first.data()['createdAt'],
        );
      }

      if (!mounted) return;

      setState(() {
        _timelineCache[leadId] = _LeadTimelineData(
          hasRequirement: requirements.docs.isNotEmpty,
          hasQuotation: quotations.docs.isNotEmpty,
          hasOrder: orderDocs.isNotEmpty,
          requirementDate: requirementDate,
          quotationDate: quotationDate,
          orderDate: orderDate,
        );
      });
    } catch (e) {
      debugPrint('Lead timeline error for $leadId: $e');
      if (mounted) {
        setState(() {
          _timelineCache[leadId] = const _LeadTimelineData();
        });
      }
    } finally {
      _timelineLoading.remove(leadId);
    }
  }

  String _journeyLabel(_LeadTimelineData? data) {
    if (data == null) return 'Loading journey...';
    if (data.hasOrder) return 'Order created';
    if (data.hasQuotation) return 'Quotation ready';
    if (data.hasRequirement) return 'Requirement added';
    return 'Lead created';
  }

  Color _leadTypeColor(String type) {
    switch (type) {
      case 'nursing':
        return _LeadTheme.blue;
      case 'caretaker':
        return _LeadTheme.purple;
      case 'equipment':
      default:
        return _LeadTheme.indigo;
    }
  }

  IconData _leadTypeIcon(String type) {
    switch (type) {
      case 'nursing':
        return Icons.local_hospital_outlined;
      case 'caretaker':
        return Icons.health_and_safety_outlined;
      case 'equipment':
      default:
        return Icons.medical_services_outlined;
    }
  }

  String _prettyType(String type) {
    switch (type) {
      case 'nursing':
        return 'Nursing';
      case 'caretaker':
        return 'Caretaker';
      case 'equipment':
        return 'Equipment';
      default:
        if (type.isEmpty) return 'Lead';
        return '${type[0].toUpperCase()}${type.substring(1)}';
    }
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _shortDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month}';
  }

  BoxDecoration _leadCardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _LeadTheme.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: _leadCardDecoration(radius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _LeadTheme.primarySoft,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 32,
                  color: _LeadTheme.primary,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'No leads found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _LeadTheme.text,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try changing your search or filters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: _LeadTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    return FloatingActionButton.extended(
      onPressed: _addLeadSheet,
      backgroundColor: _LeadTheme.primary,
      foregroundColor: Colors.white,
      elevation: 7,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Lead',
        style: TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

Widget _statusChip(String status) {
  final value = status.toLowerCase();

  Color bgColor;
  Color textColor;
  IconData icon;

  switch (value) {
    case "new":
      bgColor = const Color(0xFFE8F1FF);
      textColor = const Color(0xFF2563EB);
      icon = Icons.fiber_new_rounded;
      break;

    case "contacted":
      bgColor = const Color(0xFFFFF4E5);
      textColor = const Color(0xFFF59E0B);
      icon = Icons.call_rounded;
      break;

    case "req shared":
      bgColor = const Color(0xFFF3E8FF);
      textColor = const Color(0xFF7C3AED);
      icon = Icons.description_rounded;
      break;

    case "closed":
      bgColor = const Color(0xFFE8F8EC);
      textColor = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
      break;

    case "lost":
      bgColor = const Color(0xFFFDECEC);
      textColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      break;

    default:
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
      icon = Icons.circle;
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [

        Icon(
          icon,
          color: textColor,
          size: 16,
        ),

        const SizedBox(width: 6),

        Text(
          status.toUpperCase(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
  

 
}

class _LeadTimelineData {
  final bool hasRequirement;
  final bool hasQuotation;
  final bool hasOrder;
  final DateTime? requirementDate;
  final DateTime? quotationDate;
  final DateTime? orderDate;

  const _LeadTimelineData({
    this.hasRequirement = false,
    this.hasQuotation = false,
    this.hasOrder = false,
    this.requirementDate,
    this.quotationDate,
    this.orderDate,
  });
}

class _JourneyStage {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final DateTime? date;

  const _JourneyStage({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    this.date,
  });
}

/// Fixed premium light palette matching the lead/detail screens.
class _LeadTheme {
  static const background = Color(0xfff6f8fc);
  static const surfaceAlt = Color(0xfff1f4f9);

  static const text = Color(0xff101828);
  static const textSoft = Color(0xff344054);
  static const muted = Color(0xff667085);

  static const border = Color(0xffe4e7ec);
  static const divider = Color(0xffedf0f4);

  static const primary = Color(0xff3157d5);
  static const primarySoft = Color(0xffeef2ff);

  static const heroDark = Color(0xff172554);
  static const heroLight = Color(0xff3157d5);

  static const indigo = Color(0xff4f46e5);
  static const purple = Color(0xff7c3aed);
  static const green = Color(0xff059669);
  static const blue = Color(0xff2563eb);
  static const error = Color(0xffdc2626);
}

class _LeadActions extends StatelessWidget {
  final String status;
  final VoidCallback onAdvance;

  const _LeadActions({
    required this.status,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'new':
      case 'contacted':
      case 'req shared':
        return FilledButton(
          onPressed: onAdvance,
          child: const Text("Next →"),
        );

      default:
        return const SizedBox.shrink();
    }
  }
  
}
