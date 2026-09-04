import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class NurseProfileScreen extends StatefulWidget {
  final String staffId;

  const NurseProfileScreen({
    super.key,
    required this.staffId,
  });

  @override
  State<NurseProfileScreen> createState() =>
      _NurseProfileScreenState();
}

class _NurseProfileScreenState extends State<NurseProfileScreen> {
  bool _uploading = false;
  double _uploadProgress = 0;

  // ============================================================
  // HELPERS
  // ============================================================

  String _value(Map<String, dynamic> data, String key) {
    final value = data[key];

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

  String _maskAadhar(String value) {
    if (value.length < 4) return value;

    return '•••• •••• ${value.substring(value.length - 4)}';
  }

  String _maskPan(String value) {
    if (value.length < 4) return value;

    return '••••••${value.substring(value.length - 4)}';
  }

  String _maskAccount(String value) {
    if (value.length < 4) return value;

    return '••••••${value.substring(value.length - 4)}';
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
    bool sensitive = false,
  }) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    String displayValue = value;

    if (sensitive) {
      if (title == 'Aadhaar Number') {
        displayValue = _maskAadhar(value);
      } else if (title == 'PAN Number') {
        displayValue = _maskPan(value);
      } else if (title == 'Bank Account') {
        displayValue = _maskAccount(value);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffE7EDF3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xff0F4C75).withOpacity(.12),
                  const Color(0xff3282B8).withOpacity(.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: const Color(0xff0F4C75),
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
                    fontSize: 11,
                    color: Color(0xff94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  displayValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xff17202A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          if (sensitive)
            Icon(
              Icons.visibility_off_outlined,
              size: 17,
              color: Colors.grey.shade500,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _sectionCard({
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
          color: const Color(0xffE9EEF4),
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
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xff0F4C75).withOpacity(.12),
                      const Color(0xff3282B8).withOpacity(.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xff0F4C75),
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff17202A),
                  ),
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

  // ============================================================
  // QUICK INFO
  // ============================================================

  Widget _quickInfo({
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(.16),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),

            const SizedBox(height: 6),

            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR VIEW
  // ============================================================

  Widget _errorView() {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: Colors.red.shade400,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Unable to load profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff17202A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Please try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NOT FOUND VIEW
  // ============================================================

  Widget _notFoundView() {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: const Color(0xff0F4C75)
                          .withOpacity(.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_search_outlined,
                      size: 40,
                      color: Color(0xff0F4C75),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Profile Not Found',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff17202A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'We could not find your profile information.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DOCUMENT HELPERS
  // ============================================================

  String _fileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  String _formatFileSize(dynamic bytes) {
    final size = bytes is int
        ? bytes
        : int.tryParse(bytes?.toString() ?? '') ?? 0;

    if (size <= 0) return '';
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
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  IconData _documentIcon(String fileName) {
    switch (_fileExtension(fileName)) {
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

  String _contentType(String fileName) {
    switch (_fileExtension(fileName)) {
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

  // ============================================================
  // UPLOAD DOCUMENT
  // ============================================================

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

      final file = result.files.first;

      if (file.bytes == null || file.bytes!.isEmpty) {
        _showDocumentMessage(
          'Unable to read the selected file.',
          isError: true,
        );
        return;
      }

      // Keep mobile uploads reasonably sized.
      const maxFileSize = 15 * 1024 * 1024;

      if (file.bytes!.length > maxFileSize) {
        _showDocumentMessage(
          'Please select a document smaller than 15 MB.',
          isError: true,
        );
        return;
      }

      final fileName = file.name;
      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final safeFileName = fileName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );

      final storagePath =
          'staff-documents/${widget.staffId}/'
          '$timestamp-$safeFileName';

      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      final storageRef =
          FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = storageRef.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _contentType(fileName),
        ),
      );

      final progressSubscription =
          uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;

        if (snapshot.totalBytes > 0) {
          setState(() {
            _uploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      try {
        final snapshot = await uploadTask;
        final downloadUrl =
            await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('staff')
            .doc(widget.staffId)
            .collection('documents')
            .add({
          'name': fileName,
          'storagePath': storagePath,
          'downloadUrl': downloadUrl,
          'size': file.bytes!.length,
          'extension': _fileExtension(fileName),
          'uploadedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          _uploading = false;
          _uploadProgress = 0;
        });

        _showDocumentMessage(
          'Document uploaded successfully.',
        );
      } finally {
        await progressSubscription.cancel();
      }
    } catch (e) {
      debugPrint('Nurse document upload error: $e');

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });

      _showDocumentMessage(
        'Failed to upload document.',
        isError: true,
      );
    }
  }

  // ============================================================
  // OPEN DOCUMENT
  // ============================================================

  Future<void> _openDocument(
    Map<String, dynamic> document,
  ) async {
    final url =
        (document['downloadUrl'] ?? '').toString().trim();

    if (url.isEmpty) {
      _showDocumentMessage(
        'Document link is unavailable.',
        isError: true,
      );
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null) {
      _showDocumentMessage(
        'Invalid document link.',
        isError: true,
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showDocumentMessage(
          'Unable to open document.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Open document error: $e');

      _showDocumentMessage(
        'Unable to open document.',
        isError: true,
      );
    }
  }

  // ============================================================
  // DELETE DOCUMENT
  // ============================================================

  Future<void> _deleteDocument(
    String documentId,
    Map<String, dynamic> document,
  ) async {
    final name =
        (document['name'] ?? 'this document').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Document?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePath =
          (document['storagePath'] ?? '').toString();

      if (storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(storagePath)
              .delete();
        } catch (e) {
          debugPrint('Storage delete skipped: $e');
        }
      }

      await FirebaseFirestore.instance
          .collection('staff')
          .doc(widget.staffId)
          .collection('documents')
          .doc(documentId)
          .delete();

      if (!mounted) return;

      _showDocumentMessage('Document deleted.');
    } catch (e) {
      debugPrint('Delete document error: $e');

      if (!mounted) return;

      _showDocumentMessage(
        'Failed to delete document.',
        isError: true,
      );
    }
  }

  void _showDocumentMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Colors.redAccent
              : const Color(0xff0F4C75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // DOCUMENTS SECTION
  // ============================================================

  Widget _documentsSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xffE9EEF4),
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
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xff0F4C75).withOpacity(.12),
                      const Color(0xff3282B8).withOpacity(.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  color: Color(0xff0F4C75),
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
                        color: Color(0xff17202A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Upload and manage your documents',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xff94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          InkWell(
            onTap: _uploading ? null : _uploadDocument,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff0F4C75),
                    Color(0xff3282B8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff0F4C75).withOpacity(.18),
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
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _uploading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.cloud_upload_outlined,
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
                          _uploading
                              ? 'Uploading document...'
                              : 'Upload Document',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _uploading
                              ? '${(_uploadProgress * 100).toStringAsFixed(0)}% uploaded'
                              : 'PDF, DOC, DOCX, JPG, PNG',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),

          if (_uploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 6,
                backgroundColor: const Color(0xffE8EEF3),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xff0F4C75),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('staff')
                .doc(widget.staffId)
                .collection('documents')
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xff0F4C75),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unable to load documents.',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final documents = snapshot.data?.docs ?? [];

              if (documents.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 25,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF8FAFC),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: const Color(0xffE8EEF3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xffEAF4FB),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.folder_open_outlined,
                          color: Color(0xff0F4C75),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Documents Yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff17202A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Upload your documents using the button above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff94A3B8),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: documents.map((doc) {
                  final data = doc.data();

                  final name =
                      (data['name'] ?? 'Document').toString();
                  final size = _formatFileSize(data['size']);
                  final date =
                      _formatDocumentDate(data['uploadedAt']);
                  final extension = _fileExtension(name);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xffE8EEF3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: extension == 'pdf'
                                ? Colors.red.withOpacity(.08)
                                : const Color(0xffEAF4FB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _documentIcon(name),
                            color: extension == 'pdf'
                                ? Colors.redAccent
                                : const Color(0xff0F4C75),
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 12),

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
                                  color: Color(0xff17202A),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 7,
                                crossAxisAlignment:
                                    WrapCrossAlignment.center,
                                children: [
                                  if (extension.isNotEmpty)
                                    Text(
                                      extension.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff0F4C75),
                                      ),
                                    ),
                                  if (size.isNotEmpty)
                                    Text(
                                      '• $size',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xff8A94A6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (date.isNotEmpty)
                                    Text(
                                      '• $date',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xff8A94A6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 7),

                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => _openDocument(data),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xffEAF4FB),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.visibility_outlined,
                                color: Color(0xff0F4C75),
                                size: 19,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => _deleteDocument(
                              doc.id,
                              data,
                            ),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(.07),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 19,
                              ),
                            ),
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('staff')
          .doc(widget.staffId)
          .snapshots(),
      builder: (context, snapshot) {
        // ======================================================
        // LOADING
        // ======================================================

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xffF5F7FB),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xff0F4C75),
              ),
            ),
          );
        }

        // ======================================================
        // ERROR
        // ======================================================

        if (snapshot.hasError) {
          return _errorView();
        }

        // ======================================================
        // NOT FOUND
        // ======================================================

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _notFoundView();
        }

        // ======================================================
        // FIRESTORE DATA
        // ======================================================

        final data = snapshot.data!.data() ?? {};

        final name = _value(data, 'name');
        final phone = _value(data, 'phone');
        final alternatePhone =
            _value(data, 'alternatePhone');
        final email = _value(data, 'loginEmail');

        final gender = _value(data, 'gender');
        final dob = _value(data, 'dateOfBirth');
        final bloodGroup = _value(data, 'bloodGroup');
        final address = _value(data, 'address');

        final aadhar = _value(data, 'aadharNumber');
        final pan = _value(data, 'panNumber');

        final qualifications =
            _value(data, 'qualifications');
        final experience =
            _value(data, 'experienceYears');
        final staffType =
            _value(data, 'staffType');
        final shiftPreference =
            _value(data, 'shiftPreference');
        final shiftType =
            _value(data, 'shiftType');
        final joiningDate =
            _value(data, 'joiningDate');

        final emergencyName =
            _value(data, 'emergencyContactName');
        final emergencyPhone =
            _value(data, 'emergencyContactPhone');
        final relation =
            _value(data, 'relation');

        final bankName =
            _value(data, 'bankName');
        final bankAccount =
            _value(data, 'bankAccountNumber');
        final bankIfsc =
            _value(data, 'bankIfsc');
        final upiId =
            _value(data, 'upiId');

        final services =
            data['servicesOffered'];

        final isActive =
            data['active'] == true;

        final isAvailable =
            data['available'] == true;

        final firstLetter = name.isNotEmpty
            ? name.substring(0, 1).toUpperCase()
            : 'N';

        // ======================================================
        // SERVICES
        // ======================================================

        List<String> servicesList = [];

        if (services is List) {
          servicesList = services
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        // ======================================================
        // MAIN SCREEN
        // ======================================================

        return Scaffold(
          backgroundColor: const Color(0xffF5F7FB),

          body: RefreshIndicator(
            color: const Color(0xff0F4C75),

            onRefresh: () async {
              await FirebaseFirestore.instance
                  .collection('staff')
                  .doc(widget.staffId)
                  .get();
            },

            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ==================================================
                // PREMIUM HEADER
                // ==================================================

                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xff0F4C75),
                          Color(0xff145DA0),
                          Color(0xff3282B8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          26,
                        ),
                        child: Column(
                          children: [
                            // ======================================
                            // TOP BAR
                            // ======================================

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
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(.14),
                                    borderRadius:
                                        BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(.18),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration:
                                            BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive
                                              ? const Color(
                                                  0xff4ADE80,
                                                )
                                              : const Color(
                                                  0xffF87171,
                                                ),
                                        ),
                                      ),

                                      const SizedBox(width: 6),

                                      Text(
                                        isActive
                                            ? 'Active'
                                            : 'Inactive',
                                        style:
                                            const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // ======================================
                            // AVATAR
                            // ======================================

                            Stack(
                              alignment:
                                  Alignment.bottomRight,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(.18),
                                        blurRadius: 25,
                                        offset:
                                            const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 52,
                                    backgroundColor:
                                        const Color(0xffE8F1F8),
                                    child: Text(
                                      firstLetter,
                                      style:
                                          const TextStyle(
                                        fontSize: 40,
                                        fontWeight:
                                            FontWeight.w900,
                                        color:
                                            Color(0xff0F4C75),
                                      ),
                                    ),
                                  ),
                                ),

                                Container(
                                  width: 27,
                                  height: 27,
                                  decoration:
                                      BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? const Color(
                                            0xff22C55E,
                                          )
                                        : const Color(
                                            0xffEF4444,
                                          ),
                                    border: Border.all(
                                      color:
                                          const Color(
                                              0xff0F4C75),
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.check
                                        : Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ======================================
                            // NAME
                            // ======================================

                            Text(
                              name.isEmpty
                                  ? 'Nurse'
                                  : name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.4,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              staffType.isEmpty
                                  ? 'Nurse'
                                  : _capitalize(
                                      staffType,
                                    ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ======================================
                            // STATUS BADGES
                            // ======================================

                            Wrap(
                              alignment:
                                  WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _statusBadge(
                                  label: isActive
                                      ? 'Active'
                                      : 'Inactive',
                                  dotColor: isActive
                                      ? const Color(
                                          0xff4ADE80,
                                        )
                                      : const Color(
                                          0xffF87171,
                                        ),
                                ),

                                _statusBadge(
                                  label: isAvailable
                                      ? 'Available'
                                      : 'Unavailable',
                                  dotColor: isAvailable
                                      ? const Color(
                                          0xff4ADE80,
                                        )
                                      : const Color(
                                          0xffFBBF24,
                                        ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // ======================================
                            // QUICK INFO
                            // ======================================

                            Row(
                              children: [
                                _quickInfo(
                                  icon:
                                      Icons.phone_outlined,
                                  label: phone.isEmpty
                                      ? 'Phone'
                                      : 'Phone',
                                ),

                                const SizedBox(width: 10),

                                _quickInfo(
                                  icon: Icons
                                      .medical_services_outlined,
                                  label: 'Nurse',
                                ),

                                const SizedBox(width: 10),

                                _quickInfo(
                                  icon: Icons
                                      .workspace_premium_outlined,
                                  label: experience.isEmpty
                                      ? 'Experience'
                                      : '$experience Years',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // CONTENT
                // ==================================================

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
                        // CONTACT
                        // ==========================================

                        _sectionCard(
                          title: 'Contact Information',
                          icon:
                              Icons.contact_page_outlined,
                          children: [
                            _infoItem(
                              icon:
                                  Icons.phone_outlined,
                              title: 'Phone Number',
                              value: phone,
                            ),

                            _infoItem(
                              icon:
                                  Icons.phone_android_outlined,
                              title: 'Alternate Phone',
                              value:
                                  alternatePhone,
                            ),

                            _infoItem(
                              icon:
                                  Icons.email_outlined,
                              title: 'Email Address',
                              value: email,
                            ),

                            _infoItem(
                              icon:
                                  Icons.location_on_outlined,
                              title: 'Address',
                              value: address,
                            ),
                          ],
                        ),

                        // ==========================================
                        // PERSONAL
                        // ==========================================

                        _sectionCard(
                          title: 'Personal Details',
                          icon:
                              Icons.person_outline_rounded,
                          children: [
                            _infoItem(
                              icon: Icons.wc_outlined,
                              title: 'Gender',
                              value: gender.isEmpty
                                  ? ''
                                  : _capitalize(
                                      gender,
                                    ),
                            ),

                            _infoItem(
                              icon: Icons.cake_outlined,
                              title: 'Date of Birth',
                              value: dob,
                            ),

                            _infoItem(
                              icon:
                                  Icons.bloodtype_outlined,
                              title: 'Blood Group',
                              value: bloodGroup,
                            ),

                            _infoItem(
                              icon:
                                  Icons.credit_card_outlined,
                              title: 'Aadhaar Number',
                              value: aadhar,
                              sensitive: true,
                            ),

                            _infoItem(
                              icon: Icons.badge_outlined,
                              title: 'PAN Number',
                              value: pan,
                              sensitive: true,
                            ),
                          ],
                        ),

                        // ==========================================
                        // PROFESSIONAL
                        // ==========================================

                        _sectionCard(
                          title:
                              'Professional Information',
                          icon:
                              Icons.medical_services_outlined,
                          children: [
                            _infoItem(
                              icon: Icons.school_outlined,
                              title: 'Qualifications',
                              value: qualifications,
                            ),

                            _infoItem(
                              icon: Icons
                                  .workspace_premium_outlined,
                              title: 'Experience',
                              value: experience.isEmpty
                                  ? ''
                                  : '$experience Years',
                            ),

                            _infoItem(
                              icon: Icons.badge_outlined,
                              title: 'Staff Type',
                              value: staffType.isEmpty
                                  ? ''
                                  : _capitalize(
                                      staffType,
                                    ),
                            ),

                            _infoItem(
                              icon:
                                  Icons.schedule_outlined,
                              title: 'Shift Preference',
                              value:
                                  shiftPreference.isEmpty
                                      ? ''
                                      : _capitalize(
                                          shiftPreference,
                                        ),
                            ),

                            _infoItem(
                              icon:
                                  Icons.swap_horiz_outlined,
                              title: 'Shift Type',
                              value: shiftType.isEmpty
                                  ? ''
                                  : _capitalize(
                                      shiftType,
                                    ),
                            ),

                            _infoItem(
                              icon:
                                  Icons.calendar_today_outlined,
                              title: 'Joining Date',
                              value: joiningDate,
                            ),
                          ],
                        ),

                        // ==========================================
                        // SERVICES
                        // ==========================================

                        if (servicesList.isNotEmpty)
                          _sectionCard(
                            title: 'Services Offered',
                            icon: Icons
                                .health_and_safety_outlined,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    servicesList.map(
                                  (service) {
                                    return Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 13,
                                        vertical: 9,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        gradient:
                                            LinearGradient(
                                          colors: [
                                            const Color(
                                              0xffEAF4FB,
                                            ),
                                            const Color(
                                              0xffF2F8FC,
                                            ),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          30,
                                        ),
                                        border:
                                            Border.all(
                                          color:
                                              const Color(
                                            0xffCFE4F2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons
                                                .check_circle_outline,
                                            size: 15,
                                            color:
                                                Color(
                                              0xff0F4C75,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 6,
                                          ),
                                          Text(
                                            _capitalize(
                                                service),
                                            style:
                                                const TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                              color:
                                                  Color(
                                                0xff0F4C75,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ).toList(),
                              ),
                            ],
                          ),

                        // ==========================================
                        // EMERGENCY
                        // ==========================================

                        _sectionCard(
                          title: 'Emergency Contact',
                          icon:
                              Icons.emergency_outlined,
                          children: [
                            _infoItem(
                              icon:
                                  Icons.person_outline,
                              title: 'Contact Name',
                              value: emergencyName,
                            ),

                            _infoItem(
                              icon:
                                  Icons.phone_in_talk_outlined,
                              title: 'Contact Phone',
                              value: emergencyPhone,
                            ),

                            _infoItem(
                              icon:
                                  Icons.people_outline,
                              title: 'Relation',
                              value: relation,
                            ),
                          ],
                        ),

                        // ==========================================
                        // BANK
                        // ==========================================

                        _sectionCard(
                          title: 'Bank & Payment',
                          icon:
                              Icons.account_balance_outlined,
                          children: [
                            _infoItem(
                              icon:
                                  Icons.account_balance,
                              title: 'Bank Name',
                              value: bankName,
                            ),

                            _infoItem(
                              icon:
                                  Icons.credit_card,
                              title: 'Bank Account',
                              value: bankAccount,
                              sensitive: true,
                            ),

                            _infoItem(
                              icon:
                                  Icons.numbers_outlined,
                              title: 'IFSC Code',
                              value: bankIfsc,
                            ),

                            _infoItem(
                              icon: Icons
                                  .account_balance_wallet_outlined,
                              title: 'UPI ID',
                              value: upiId,
                            ),
                          ],
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
                          margin:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),
                          padding:
                              const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isActive
                                  ? [
                                      const Color(
                                        0xffF0FDF4,
                                      ),
                                      const Color(
                                        0xffECFDF5,
                                      ),
                                    ]
                                  : [
                                      const Color(
                                        0xffFEF2F2,
                                      ),
                                      const Color(
                                        0xffFFF1F2,
                                      ),
                                    ],
                            ),
                            borderRadius:
                                BorderRadius.circular(22),
                            border: Border.all(
                              color: isActive
                                  ? const Color(
                                      0xffBBF7D0,
                                    )
                                  : const Color(
                                      0xffFECACA,
                                    ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration:
                                    BoxDecoration(
                                  color: isActive
                                      ? const Color(
                                          0xffDCFCE7,
                                        )
                                      : const Color(
                                          0xffFEE2E2,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons
                                          .verified_user_rounded
                                      : Icons
                                          .gpp_bad_rounded,
                                  color: isActive
                                      ? const Color(
                                          0xff16A34A,
                                        )
                                      : const Color(
                                          0xffDC2626,
                                        ),
                                  size: 23,
                                ),
                              ),

                              const SizedBox(width: 13),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      isActive
                                          ? 'Account is Active'
                                          : 'Account is Inactive',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w900,
                                        color: isActive
                                            ? const Color(
                                                0xff166534,
                                              )
                                            : const Color(
                                                0xff991B1B,
                                              ),
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 4),

                                    Text(
                                      isActive
                                          ? 'You currently have access to the application.'
                                          : 'Please contact the admin to activate your account.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: isActive
                                            ? const Color(
                                                0xff4D7C5A,
                                              )
                                            : const Color(
                                                0xff991B1B,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'BMM Workforce • Employee Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 5),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge({
    required String label,
    required Color dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),

          const SizedBox(width: 7),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}