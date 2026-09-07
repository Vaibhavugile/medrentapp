import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class DriverProfileScreen extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;
  const DriverProfileScreen({
    super.key,
    required this.driverId,
    required this.driverData,
  });

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  bool _uploading = false;
  double _uploadProgress = 0;

  // =========================================================
  // HELPERS
  // =========================================================

  String _value(String key) {
    final value = widget.driverData[key];

    if (value == null) return '';

    return value.toString().trim();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;

    return value
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _salaryText() {
    final salary = widget.driverData['salary'];

    if (salary == null) return '';

    final period = _value('salaryPeriod');

    final amount = salary is num
        ? '₹${salary.toStringAsFixed(0)}'
        : '₹$salary';

    if (period.isEmpty) return amount;

    return '$amount / ${_capitalize(period)}';
  }

  bool _isActive() {
    return widget.driverData['active'] == true;
  }

  String _initial() {
    final name = _value('name');

    if (name.isEmpty) return 'D';

    return name.substring(0, 1).toUpperCase();
  }

  // =========================================================
  // INFO ITEM
  // =========================================================

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF4CA1AF).withOpacity(.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4CA1AF),
              size: 20,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION CARD
  // =========================================================

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final visibleChildren = children
        .where(
          (child) =>
              child is! SizedBox ||
              (child as SizedBox).height != 0,
        )
        .toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE8EDF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF4CA1AF),
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ...visibleChildren,
        ],
      ),
    );
  }


  // =========================================================
  // DOCUMENT HELPERS
  // =========================================================

  String _fileExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _formatFileSize(dynamic bytes) {
    final size = bytes is num ? bytes.toInt() : int.tryParse('$bytes') ?? 0;

    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDocumentDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    if (value is DateTime) {
      return '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/'
          '${value.year}';
    }

    return 'Recently uploaded';
  }

  IconData _documentIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _uploadDocument() async {
    if (_uploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;

      if (file.bytes == null) {
        if (!mounted) return;
        _showDocumentMessage(
          'Unable to read the selected file.',
          isError: true,
        );
        return;
      }

      const maxBytes = 15 * 1024 * 1024;

      if (file.bytes!.length > maxBytes) {
        if (!mounted) return;
        _showDocumentMessage(
          'File is too large. Maximum size is 15 MB.',
          isError: true,
        );
        return;
      }

      final originalName = file.name.trim().isEmpty
          ? 'document'
          : file.name.trim();

      final safeFileName = originalName
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final extension = _fileExtension(originalName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'driver-documents/${widget.driverId}/$timestamp-$safeFileName';

      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      final storageRef =
          FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = storageRef.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _contentType(extension),
        ),
      );

      final subscription = uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted || snapshot.totalBytes <= 0) return;

        setState(() {
          _uploadProgress =
              snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      try {
        await uploadTask;
      } finally {
        await subscription.cancel();
      }

      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .collection('documents')
          .add({
        'name': originalName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'size': file.bytes!.length,
        'extension': extension,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadProgress = 1;
      });

      _showDocumentMessage('Document uploaded successfully.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });

      _showDocumentMessage(
        'Upload failed. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _openDocument(
    String url,
    String name,
  ) async {
    try {
      final uri = Uri.tryParse(url);

      if (uri == null) {
        if (!mounted) return;
        _showDocumentMessage(
          'Invalid document link.',
          isError: true,
        );
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showDocumentMessage(
          'Could not open $name.',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showDocumentMessage(
        'Could not open this document.',
        isError: true,
      );
    }
  }

  Future<void> _deleteDocument(
    String documentId,
    Map<String, dynamic> documentData,
  ) async {
    final name = (documentData['name'] ?? 'this document').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Document?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$name"?',
            style: const TextStyle(
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePath = documentData['storagePath']?.toString();

      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(storagePath)
              .delete();
        } catch (_) {
          // Keep Firestore cleanup working even if the storage object
          // was already removed.
        }
      }

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .collection('documents')
          .doc(documentId)
          .delete();

      if (!mounted) return;
      _showDocumentMessage('Document deleted successfully.');
    } catch (_) {
      if (!mounted) return;
      _showDocumentMessage(
        'Could not delete the document.',
        isError: true,
      );
    }
  }

  void _showDocumentMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFDC2626)
              : const Color(0xFF172033),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
  }

  Widget _documentsSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE8EDF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  color: Color(0xFF4CA1AF),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Documents',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF172033),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Upload and manage your documents',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2C3E50),
                    Color(0xFF4CA1AF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CA1AF).withOpacity(.20),
                    blurRadius: 15,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _uploadDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.cloud_upload_outlined,
                        size: 20,
                      ),
                label: Text(
                  _uploading
                      ? 'Uploading ${(_uploadProgress * 100).round()}%'
                      : 'Upload Document',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),

          if (_uploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: _uploadProgress,
                backgroundColor: const Color(0xFFEAF0F5),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4CA1AF),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('drivers')
                .doc(widget.driverId)
                .collection('documents')
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF4CCCC),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unable to load documents right now.',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4CA1AF),
                    ),
                  ),
                );
              }

              final documents = snapshot.data?.docs ?? [];

              if (documents.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: const Color(0xFFE8EDF3),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 38,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 9),
                      Text(
                        'No documents uploaded yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your uploaded documents will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: documents.map((document) {
                  final data = document.data();
                  final name =
                      (data['name'] ?? 'Document').toString();
                  final extension =
                      (data['extension'] ?? _fileExtension(name))
                          .toString()
                          .toLowerCase();
                  final url = (data['downloadUrl'] ?? '').toString();
                  final size = _formatFileSize(data['size']);
                  final uploadedAt =
                      _formatDocumentDate(data['uploadedAt']);

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xFFE8EDF3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _documentIcon(extension),
                            color: const Color(0xFF4CA1AF),
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF172033),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${extension.isEmpty ? 'FILE' : extension.toUpperCase()} • $size',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                uploadedAt,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'View',
                          onPressed: url.isEmpty
                              ? null
                              : () => _openDocument(url, name),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEAF7F8),
                            foregroundColor: const Color(0xFF4CA1AF),
                          ),
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 19,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _deleteDocument(
                            document.id,
                            data,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFFFF1F2),
                            foregroundColor:
                                const Color(0xFFDC2626),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final name = _value('name');
    final phone = _value('phone');
    final email = _value('loginEmail');
    final status = _value('status');
    final shift = _value('shift');
    final salary = _salaryText();
    final active = _isActive();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      // =======================================================
      // NO APPBAR
      // =======================================================

      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ===================================================
            // PREMIUM PROFILE HEADER
            // ===================================================

            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  28,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF2C3E50),
                      Color(0xFF4CA1AF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // -------------------------------------------
                    // TOP TITLE
                    // -------------------------------------------

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'My Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.3,
                            ),
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.14),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                active ? 'Active' : 'Inactive',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // -------------------------------------------
                    // AVATAR
                    // -------------------------------------------

                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4CA1AF)
                                  .withOpacity(.16),
                              const Color(0xFF2C3E50)
                                  .withOpacity(.10),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _initial(),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4CA1AF),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------
                    // NAME
                    // -------------------------------------------

                    Text(
                      name.isEmpty ? 'Driver' : name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Driver',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------
                    // ACTIVE STATUS
                    // -------------------------------------------

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(.14)
                            : Colors.red.withOpacity(.18),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(.20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: active
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 17,
                          ),

                          const SizedBox(width: 7),

                          Text(
                            active
                                ? 'Account Active'
                                : 'Account Inactive',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===================================================
            // CONTENT
            // ===================================================

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                16,
                20,
                16,
                30,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // ==========================================
                    // QUICK INFO
                    // ==========================================

                    Row(
                      children: [
                        Expanded(
                          child: _quickCard(
                            icon: Icons.phone_rounded,
                            title: 'Phone',
                            value: phone.isEmpty
                                ? 'Not added'
                                : phone,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _quickCard(
                            icon: Icons.schedule_rounded,
                            title: 'Shift',
                            value: shift.isEmpty
                                ? 'Not added'
                                : _capitalize(shift),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ==========================================
                    // PERSONAL
                    // ==========================================

                    _section(
                      title: 'Personal Information',
                      icon: Icons.person_outline_rounded,
                      children: [
                        _infoRow(
                          icon: Icons.phone_outlined,
                          title: 'Phone',
                          value: phone,
                        ),
                        _infoRow(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          value: email,
                        ),
                        _infoRow(
                          icon: Icons.location_on_outlined,
                          title: 'Address',
                          value: _value('address'),
                        ),
                      ],
                    ),

                    // ==========================================
                    // WORK
                    // ==========================================

                    _section(
                      title: 'Work Information',
                      icon: Icons.work_outline_rounded,
                      children: [
                        _infoRow(
                          icon: Icons.directions_car_outlined,
                          title: 'Vehicle',
                          value: _value('vehicle'),
                        ),
                        _infoRow(
                          icon: Icons.work_history_outlined,
                          title: 'Status',
                          value: status.isEmpty
                              ? ''
                              : _capitalize(status),
                        ),
                        _infoRow(
                          icon: Icons.schedule_outlined,
                          title: 'Shift',
                          value: shift.isEmpty
                              ? ''
                              : _capitalize(shift),
                        ),
                        _infoRow(
                          icon: Icons.calendar_today_outlined,
                          title: 'Joining Date',
                          value: _value('joinDate'),
                        ),
                      ],
                    ),

                    // ==========================================
                    // LICENSE
                    // ==========================================

                    _section(
                      title: 'License Information',
                      icon: Icons.badge_outlined,
                      children: [
                        _infoRow(
                          icon: Icons.credit_card_outlined,
                          title: 'License Number',
                          value: _value('licenseNumber'),
                        ),
                        _infoRow(
                          icon: Icons.event_outlined,
                          title: 'License Expiry',
                          value: _value('licenseExpiry'),
                        ),
                      ],
                    ),

                    // ==========================================
                    // EMERGENCY
                    // ==========================================

                    _section(
                      title: 'Emergency Contact',
                      icon: Icons.emergency_outlined,
                      children: [
                        _infoRow(
                          icon: Icons.person_outline_rounded,
                          title: 'Contact Name',
                          value: _value(
                            'emergencyContactName',
                          ),
                        ),
                        _infoRow(
                          icon: Icons.phone_in_talk_outlined,
                          title: 'Contact Phone',
                          value: _value(
                            'emergencyContactPhone',
                          ),
                        ),
                      ],
                    ),

                    // ==========================================
                    // SALARY
                    // ==========================================

                    if (salary.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2C3E50),
                              Color(0xFF4CA1AF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2C3E50)
                                  .withOpacity(.16),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.14),
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.payments_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Salary',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    salary,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ==========================================
                    // DOCUMENTS
                    // ==========================================

                    _documentsSection(),

                    // ==========================================
                    // ACCOUNT STATUS
                    // ==========================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFEAF8F0)
                            : const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFFCDEEDB)
                              : const Color(0xFFF4CCCC),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.green.withOpacity(.12)
                                  : Colors.red.withOpacity(.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              active
                                  ? Icons.verified_user_rounded
                                  : Icons.gpp_bad_rounded,
                              color: active
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),

                          const SizedBox(width: 13),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  active
                                      ? 'Account Active'
                                      : 'Account Inactive',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: active
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  active
                                      ? 'Your account is currently active.'
                                      : 'Please contact the administrator.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: active
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // QUICK CARD
  // =========================================================

  Widget _quickCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8EDF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4CA1AF),
              size: 19,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w800,
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