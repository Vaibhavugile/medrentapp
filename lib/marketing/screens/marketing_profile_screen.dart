import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketingProfileScreen extends StatefulWidget {
  final String marketingId;

  const MarketingProfileScreen({
    super.key,
    required this.marketingId,
  });

  @override
  State<MarketingProfileScreen> createState() => _MarketingProfileScreenState();
}

class _MarketingProfileScreenState extends State<MarketingProfileScreen> {
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

  String _salaryText(Map<String, dynamic> data) {
    final salary = data['salaryMonthly'];

    if (salary == null) return '';

    final amount = salary is num
        ? '₹${salary.toStringAsFixed(0)}'
        : '₹$salary';

    return amount;
  }

  // ============================================================
  // SMALL INFO ITEM
  // ============================================================

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xffe8edf3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xff0F4C75).withOpacity(.09),
              borderRadius: BorderRadius.circular(12),
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff17202A),
                  ),
                ),
              ],
            ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xffedf0f4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xff0F4C75).withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xff0F4C75),
                  size: 19,
                ),
              ),

              const SizedBox(width: 10),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff17202A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTION
  // ============================================================

  Widget _quickAction({
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.13),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(.14),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 21,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ============================================================
  // DOCUMENT HELPERS
  // ============================================================

  String _fileExtension(String name) {
    final index = name.lastIndexOf('.');
    if (index == -1 || index == name.length - 1) return '';
    return name.substring(index + 1).toLowerCase();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDocumentDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }
    return 'Just uploaded';
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
        allowedExtensions: [
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
        _showDocumentMessage(
          'Unable to read the selected file.',
          isError: true,
        );
        return;
      }

      const maxSize = 15 * 1024 * 1024;

      if (file.bytes!.length > maxSize) {
        _showDocumentMessage(
          'File size must be 15 MB or less.',
          isError: true,
        );
        return;
      }

      final originalName = file.name.trim().isEmpty
          ? 'document'
          : file.name.trim();

      final safeFileName = originalName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );

      final extension = _fileExtension(originalName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final storagePath =
          'marketing-documents/${widget.marketingId}/'
          '$timestamp-$safeFileName';

      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = storageRef.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _contentType(extension),
        ),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;

        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;

        setState(() {
          _uploadProgress =
              total > 0 ? transferred / total : 0;
        });
      });

      await uploadTask;

      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('marketing')
          .doc(widget.marketingId)
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
        _uploadProgress = 0;
      });

      _showDocumentMessage(
        'Document uploaded successfully.',
      );
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
    String extension,
  ) async {
    try {
      final uri = Uri.tryParse(url);

      if (uri == null) {
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
          'Unable to open this document.',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showDocumentMessage(
        'Unable to open this document.',
        isError: true,
      );
    }
  }

  Future<void> _deleteDocument(
    String documentId,
    Map<String, dynamic> document,
  ) async {
    final name = (document['name'] ?? 'this document').toString();

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
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePath = document['storagePath']?.toString();

      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(storagePath)
              .delete();
        } catch (_) {
          // Continue deleting the Firestore record even if
          // the storage object has already been removed.
        }
      }

      await FirebaseFirestore.instance
          .collection('marketing')
          .doc(widget.marketingId)
          .collection('documents')
          .doc(documentId)
          .delete();

      if (!mounted) return;

      _showDocumentMessage(
        'Document deleted successfully.',
      );
    } catch (_) {
      if (!mounted) return;

      _showDocumentMessage(
        'Unable to delete the document.',
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
          backgroundColor:
              isError ? Colors.red.shade700 : const Color(0xff0F4C75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          color: const Color(0xffedf0f4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xff0F4C75).withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  color: Color(0xff0F4C75),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff17202A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Upload and manage your documents',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xff64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _uploading ? null : _uploadDocument,
                  borderRadius: BorderRadius.circular(13),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _uploading
                            ? [
                                Colors.grey.shade400,
                                Colors.grey.shade500,
                              ]
                            : const [
                                Color(0xff0F4C75),
                                Color(0xff3282B8),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _uploading
                              ? Icons.hourglass_top_rounded
                              : Icons.upload_file_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _uploading ? 'Uploading' : 'Upload',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_uploading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: _uploadProgress > 0
                    ? _uploadProgress
                    : null,
                backgroundColor: const Color(0xffE8EEF4),
                color: const Color(0xff0F4C75),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _uploadProgress > 0
                  ? 'Uploading ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                  : 'Preparing upload...',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),

          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('marketing')
                .doc(widget.marketingId)
                .collection('documents')
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff7f7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xfffee2e2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xffDC2626),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unable to load documents.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff991B1B),
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
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xffE8EDF3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xffE8F1F8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.folder_open_outlined,
                          color: Color(0xff0F4C75),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No documents yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff17202A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload your documents using the button above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff64748B),
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
                  final extension =
                      (data['extension'] ?? _fileExtension(name))
                          .toString();
                  final url =
                      (data['downloadUrl'] ?? '').toString();
                  final storagePath =
                      (data['storagePath'] ?? '').toString();
                  final size = data['size'] is num
                      ? (data['size'] as num).toInt()
                      : 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xffE8EDF3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xffE8F1F8),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            _documentIcon(extension),
                            color: const Color(0xff0F4C75),
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
                                  color: Color(0xff17202A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (extension.isNotEmpty)
                                    extension.toUpperCase(),
                                  if (size > 0)
                                    _formatFileSize(size),
                                  _formatDocumentDate(
                                    data['uploadedAt'],
                                  ),
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xff64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        IconButton(
                          tooltip: 'View',
                          onPressed: url.isEmpty
                              ? null
                              : () => _openDocument(
                                    url,
                                    name,
                                    extension,
                                  ),
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: Color(0xff0F4C75),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _deleteDocument(
                            doc.id,
                            {
                              ...data,
                              'storagePath': storagePath,
                            },
                          ),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Colors.red.shade600,
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
          .collection('marketing')
          .doc(widget.marketingId)
          .snapshots(),

      builder: (context, snapshot) {
        // ======================================================
        // LOADING
        // ======================================================

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xfff5f7fb),
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
          return Scaffold(
            backgroundColor: const Color(0xfff5f7fb),
            appBar: AppBar(
              title: const Text(
                'Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 38,
                        color: Colors.red.shade400,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Unable to load profile',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Please try again later.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ======================================================
        // NOT FOUND
        // ======================================================

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xfff5f7fb),
            appBar: AppBar(
              title: const Text(
                'Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              elevation: 0,
            ),
            body: const Center(
              child: Text(
                'Profile not found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        // ======================================================
        // FIRESTORE DATA
        // ======================================================

        final data = snapshot.data!.data() ?? {};

        final name = _value(data, 'name');
        final role = _value(data, 'role');
        final phone = _value(data, 'phone');
        final email = _value(data, 'loginEmail');
        final branchId = _value(data, 'branchId');

        final salary = _salaryText(data);

        final isActive = data['active'] == true;

        final firstLetter = name.isNotEmpty
            ? name.substring(0, 1).toUpperCase()
            : 'M';

        // ======================================================
        // MAIN SCREEN
        // ======================================================

        return Scaffold(
          backgroundColor: const Color(0xfff5f7fb),

         

          body: RefreshIndicator(
            color: const Color(0xff0F4C75),

            onRefresh: () async {
              await FirebaseFirestore.instance
                  .collection('marketing')
                  .doc(widget.marketingId)
                  .get();
            },

            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              child: Column(
                children: [
                  // ==================================================
                  // PREMIUM HEADER
                  // ==================================================

                  Container(
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
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        24,
                      ),

                      child: Column(
                        children: [
                          // Avatar
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(.95),
                                ),

                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor:
                                      const Color(0xffE8F1F8),

                                  child: Text(
                                    firstLetter,

                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xff0F4C75),
                                    ),
                                  ),
                                ),
                              ),

                              Container(
                                width: 23,
                                height: 23,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? const Color(0xff22C55E)
                                      : const Color(0xffEF4444),

                                  border: Border.all(
                                    color: const Color(0xff0F4C75),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 13),

                          // Name
                          Text(
                            name.isEmpty ? 'Marketing Executive' : name,

                            textAlign: TextAlign.center,

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            role.isEmpty
                                ? 'Marketing Executive'
                                : _capitalize(role),

                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 13),

                          // Status
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),

                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.13),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(.15),
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
                                    color: isActive
                                        ? const Color(0xff4ADE80)
                                        : const Color(0xffF87171),
                                  ),
                                ),

                                const SizedBox(width: 7),

                                Text(
                                  isActive
                                      ? 'Active Account'
                                      : 'Inactive Account',

                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        //   const SizedBox(height: 18),

                        //   // Quick actions
                        //   Row(
                        //     children: [
                        //       _quickAction(
                        //         icon: Icons.phone_outlined,
                        //         label: 'Phone',
                        //       ),

                        //       const SizedBox(width: 10),

                        //       _quickAction(
                        //         icon: Icons.email_outlined,
                        //         label: 'Email',
                        //       ),

                        //       const SizedBox(width: 10),

                        //       _quickAction(
                        //         icon: Icons.badge_outlined,
                        //         label: 'Employee',
                        //       ),
                        //     ],
                        //   ),
                        ],
                      ),
                    ),
                  ),

                  // ==================================================
                  // CONTENT
                  // ==================================================

                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      30,
                    ),

                    child: Column(
                      children: [
                        // ==================================================
                        // CONTACT
                        // ==================================================

                        _sectionCard(
                          title: 'Contact Information',
                          icon: Icons.contact_page_outlined,

                          children: [
                            _infoItem(
                              icon: Icons.phone_outlined,
                              title: 'Phone Number',
                              value: phone,
                            ),

                            _infoItem(
                              icon: Icons.email_outlined,
                              title: 'Email Address',
                              value: email,
                            ),
                          ],
                        ),

                        // ==================================================
                        // WORK
                        // ==================================================

                        _sectionCard(
                          title: 'Work Information',
                          icon: Icons.work_outline,

                          children: [
                            _infoItem(
                              icon: Icons.badge_outlined,
                              title: 'Role',
                              value: role.isEmpty
                                  ? ''
                                  : _capitalize(role),
                            ),

                            if (branchId.isNotEmpty)
                              _infoItem(
                                icon: Icons.account_balance_outlined,
                                title: 'Branch',
                                value: branchId,
                              ),
                          ],
                        ),

                        // ==================================================
                        // SALARY CARD
                        // ==================================================

                        if (salary.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),

                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xff0F4C75),
                                  Color(0xff3282B8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),

                              borderRadius: BorderRadius.circular(22),

                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff0F4C75)
                                      .withOpacity(.20),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),

                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,

                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.14),
                                    borderRadius:
                                        BorderRadius.circular(15),
                                  ),

                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),

                                const SizedBox(width: 15),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Monthly Salary',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),

                                      const SizedBox(height: 3),

                                      Text(
                                        salary,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 25,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Icon(
                                  Icons.payments_outlined,
                                  color: Colors.white54,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),

                        // ==================================================
                        // MY DOCUMENTS
                        // ==================================================

                        _documentsSection(),

                        // ==================================================
                        // ACCOUNT STATUS
                        // ==================================================

                        _sectionCard(
                          title: 'Account Status',
                          icon: Icons.verified_user_outlined,

                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),

                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xffF0FDF4)
                                    : const Color(0xffFEF2F2),

                                borderRadius: BorderRadius.circular(15),

                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xffBBF7D0)
                                      : const Color(0xffFECACA),
                                ),
                              ),

                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,

                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xffDCFCE7)
                                          : const Color(0xffFEE2E2),
                                      shape: BoxShape.circle,
                                    ),

                                    child: Icon(
                                      isActive
                                          ? Icons.check_circle_outline
                                          : Icons.cancel_outlined,

                                      color: isActive
                                          ? const Color(0xff16A34A)
                                          : const Color(0xffDC2626),

                                      size: 22,
                                    ),
                                  ),

                                  const SizedBox(width: 13),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isActive
                                              ? 'Account is Active'
                                              : 'Account is Inactive',

                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isActive
                                                ? const Color(0xff166534)
                                                : const Color(0xff991B1B),
                                          ),
                                        ),

                                        const SizedBox(height: 3),

                                        Text(
                                          isActive
                                              ? 'You currently have access to the application.'
                                              : 'Please contact the admin to activate your account.',

                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isActive
                                                ? const Color(0xff4D7C5A)
                                                : const Color(0xff991B1B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        // Footer
                        Text(
                          'Employee Profile',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
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
  }
}