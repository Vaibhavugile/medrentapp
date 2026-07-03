import 'dart:async';
import 'package:flutter/material.dart';
import '../../marketing/leads_service.dart';
import 'lead_details_screen.dart';
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

bool _duplicatesOnly = false;
  Map<String, dynamic> _draft = {};

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

    _sub = _svc.streamMyLeads(widget.userId).listen((list) {
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



 _premiumField(

    controller: _sourceCtrl,

    label: "Lead Source",

    icon: Icons.campaign_outlined,

    maxLines: 3,
  ),
  const SizedBox(
  height: 16,
),


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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered;
    final totalLeads = items.length;


    return Scaffold(
      
      floatingActionButton: FloatingActionButton.extended(
  onPressed: _addLeadSheet,
  icon: const Icon(Icons.add),
  label: const Text("Add Lead"),
),
      body: Column(
        children: [

          /// SEARCH
         Padding(

  padding: const EdgeInsets.all(12),

  child: Column(

    children: [

      /// SEARCH

      TextField(

        decoration: InputDecoration(

          hintText: "Search leads...",

          prefixIcon:
              const Icon(Icons.search),

          filled: true,

          fillColor: Colors.white,

          border: OutlineInputBorder(

            borderRadius:
                BorderRadius.circular(16),

            borderSide:
                BorderSide.none,
          ),
        ),

        onChanged: (v) {

          setState(() {

            _q = v;

          });
        },
      ),

      const SizedBox(height: 12),

      /// FILTERS

      SingleChildScrollView(

        scrollDirection: Axis.horizontal,

        child: Row(

          children: [

            /// SORT

            Container(

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(14),
              ),

              child:
                  DropdownButtonHideUnderline(

                child: DropdownButton<String>(

                  value: _sortBy,

                  items: const [

                    DropdownMenuItem(

                      value: 'latest',

                      child: Text(
                        "Latest",
                      ),
                    ),

                    DropdownMenuItem(

                      value: 'oldest',

                      child: Text(
                        "Oldest",
                      ),
                    ),
                  ],

                  onChanged: (v) {

                    setState(() {

                      _sortBy = v!;

                    });
                  },
                ),
              ),
            ),

            const SizedBox(width: 10),

            /// TYPE FILTER

            Container(

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(14),
              ),

              child:
                  DropdownButtonHideUnderline(

                child: DropdownButton<String>(

                  value: _filterType,

                  items: const [

                    DropdownMenuItem(

                      value: 'all',

                      child: Text(
                        "All Types",
                      ),
                    ),

                    DropdownMenuItem(

                      value: 'equipment',

                      child: Text(
                        "Equipment",
                      ),
                    ),

                    DropdownMenuItem(

                      value: 'nursing',

                      child: Text(
                        "Nursing",
                      ),
                    ),

                    DropdownMenuItem(

                      value: 'caretaker',

                      child: Text(
                        "Caretaker",
                      ),
                    ),
                  ],

                  onChanged: (v) {

                    setState(() {

                      _filterType = v!;

                    });
                  },
                ),
              ),
            ),

            const SizedBox(width: 10),

            /// DUPLICATE FILTER

            FilterChip(

              label:
                  const Text("Duplicates"),

              selected:
                  _duplicatesOnly,

              onSelected: (v) {

                setState(() {

                  _duplicatesOnly = v;

                });
              },
            ),

            const SizedBox(width: 10),
            OutlinedButton.icon(

  onPressed: () async {

    final picked =
        await showDateRangePicker(

      context: context,

      firstDate:
          DateTime(2023),

      lastDate:
          DateTime.now()
              .add(
        const Duration(days: 365),
      ),
    );

    if (picked != null) {

      setState(() {

        _dateRange = picked;
      });
    }
  },

  icon: const Icon(
    Icons.date_range,
  ),

  label: Text(

    _dateRange == null
        ? "Date Filter"
        : "${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}",
  ),
),

            /// CLEAR FILTERS

            OutlinedButton.icon(

              onPressed: () {

                setState(() {

                  _q = '';

                  _sortBy = 'latest';

                  _filterType = 'all';
                  _dateRange = null;

                  _duplicatesOnly = false;

                });
              },

              icon: const Icon(
                Icons.refresh,
              ),

              label: const Text(
                "Reset",
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
          /// STATUS TABS
        Padding(

  padding: const EdgeInsets.symmetric(
    horizontal: 16,
  ),

  child: Row(

    children: [

      Container(

        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),

        decoration: BoxDecoration(

          color:
              Colors.indigo.withOpacity(.08),

          borderRadius:
              BorderRadius.circular(14),
        ),

        child: Row(

          children: [

            Icon(
              Icons.auto_graph,
              size: 18,
              color:
                  Colors.indigo.shade700,
            ),

            const SizedBox(width: 8),

            Text(

              "Total Leads: $totalLeads",

              style: TextStyle(

                fontWeight:
                    FontWeight.w700,

                color:
                    Colors.indigo.shade700,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),

          const SizedBox(height: 10),

          /// LEADS LIST
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("No leads"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {

                      final l = items[i];
final color = Colors.indigo;
                      return InkWell(
  borderRadius: BorderRadius.circular(14),
  onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LeadDetailsScreen(
        lead: l,
      ),
    ),
  );
},
  child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 8,
                              offset: const Offset(0,3),
                            )
                          ],
                        ),
                        child: Row(
                          children: [

                            /// STATUS BAR
                            Container(
                              width: 4,
                              height: l['isDuplicate'] == true ? 210 : 180,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                ),
                              ),
                            ),

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    /// HEADER
                                    Row(
                                      children: [

                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              color.withOpacity(.15),
                                          child: Text(
                                            (l['customerName'] ?? 'C')[0]
                                                .toString()
                                                .toUpperCase(),
                                            style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),

                                        const SizedBox(width: 10),

                                        Expanded(
                                          child: Text(
                                            l['customerName'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15),
                                          ),
                                        ),

                                        Container(

  padding: const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 5,
  ),

  decoration: BoxDecoration(

    color: Colors.indigo.withOpacity(.1),

    borderRadius:
        BorderRadius.circular(100),
  ),

  child: Text(

    (l['type'] ?? 'equipment')
        .toString()
        .toUpperCase(),

    style: TextStyle(

      fontSize: 11,

      fontWeight: FontWeight.w700,

      color: Colors.indigo.shade700,
    ),
  ),
),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline,
                                            size: 16,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            l['contactPerson'] ?? '-',
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 3),

                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 16,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          l['phone'] ?? '-',
                                          style:
                                              const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),

Row(
  children: [

    const Icon(
      Icons.email_outlined,
      size: 16,
      color: Colors.grey,
    ),

    const SizedBox(width: 4),

    Expanded(
      child: Text(
        l['email'] ?? '-',
        style: const TextStyle(fontSize: 13),
      ),
    ),
  ],
),

const SizedBox(height: 3),

Row(
  children: [

    const Icon(
      Icons.location_on_outlined,
      size: 16,
      color: Colors.grey,
    ),

    const SizedBox(width: 4),

    Expanded(
      child: Text(
        l['address'] ?? '-',
        style: const TextStyle(fontSize: 13),
      ),
    ),
  ],
),
if (l['isDuplicate'] == true) ...[

  const SizedBox(height: 8),

  Container(

    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),

    decoration: BoxDecoration(

      color: Colors.red.withOpacity(.10),

      borderRadius:
          BorderRadius.circular(100),
    ),

    child: Row(
      mainAxisSize: MainAxisSize.min,

      children: const [

        Icon(
          Icons.copy_rounded,
          size: 14,
          color: Colors.red,
        ),

        SizedBox(width: 6),

        Text(

          "Duplicate Lead",

          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    ),
  ),
],

                                    const SizedBox(height: 3),

                                    Row(
                                      children: [
                                        const Icon(Icons.campaign_outlined,
                                            size: 16,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            l['leadSource'] ?? '-',
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

Divider(height: 1),

const SizedBox(height: 10),

Text(

  "Created by ${l['createdByName'] ?? '-'}",

  style: TextStyle(
    fontSize: 11,
    color: Colors.grey.shade600,
  ),
),


                                    
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

 

  

 
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
