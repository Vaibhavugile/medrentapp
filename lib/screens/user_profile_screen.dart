import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _uploading = false;
  double _uploadProgress = 0;

  final ImagePicker _imagePicker = ImagePicker();

  bool _uploadingProfilePhoto = false;
  double _profilePhotoUploadProgress = 0;

  // ============================================================
  // HELPERS
  // ============================================================

  String _value(
    dynamic value, {
    String fallback = 'Not provided',
  }) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  String _capitalize(String value) {
    if (value.trim().isEmpty) return value;

    return value
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                  '${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _salaryText(dynamic salary) {
    if (salary == null) return 'Not provided';

    if (salary is num) {
      if (salary == 0) return 'Not provided';

      return '₹${salary.toStringAsFixed(0)} / month';
    }

    final text = salary.toString().trim();

    if (text.isEmpty || text == '0') {
      return 'Not provided';
    }

    return '₹$text / month';
  }

  String _initial(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) return 'U';

    return cleanName.substring(0, 1).toUpperCase();
  }

  String _fileExtension(String fileName) {
    final parts = fileName.split('.');

    if (parts.length < 2) {
      return '';
    }

    return parts.last.toLowerCase();
  }

  IconData _documentIcon(String fileName) {
    final extension = _fileExtension(fileName);

    switch (extension) {
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

  String _formatFileSize(dynamic bytes) {
    if (bytes == null) return '';

    final size = int.tryParse(bytes.toString()) ?? 0;

    if (size <= 0) return '';

    if (size < 1024) {
      return '$size B';
    }

    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }

    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    if (value.trim().isEmpty || value == 'Not provided') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF4CA1AF),
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
                    color: Color(0xFF8A94A6),
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
                    height: 1.25,
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
    final visibleChildren = children
        .where(
          (child) => child is! SizedBox || child.height != 0,
        )
        .toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9EEF5),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.045),
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
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEAF7F8),
                      Color(0xFFF2FAFB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF4CA1AF),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...visibleChildren,
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge({
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withOpacity(.17)
            : Colors.red.withOpacity(.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(.25),
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
          const SizedBox(width: 8),
          Text(
            active ? 'ACTIVE ACCOUNT' : 'INACTIVE ACCOUNT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
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
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    );
  }

  // ============================================================
  // PROFILE PHOTO
  // ============================================================

  String _profilePhotoUrl(Map<String, dynamic> data) {
    final candidates = [
      data['profilePhotoUrl'],
      data['photoUrl'],
      data['profilePhoto'],
      data['photo'],
      data['avatarUrl'],
      data['imageUrl'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') {
        return value;
      }
    }

    return '';
  }

  String _profilePhotoStoragePath(Map<String, dynamic> data) {
    final candidates = [
      data['profilePhotoStoragePath'],
      data['photoStoragePath'],
      data['avatarStoragePath'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') {
        return value;
      }
    }

    return '';
  }

  Future<void> _showProfilePhoto() async {
    // The actual URL is resolved from the live Firestore document in build.
    // This method is intentionally opened through _openProfilePhoto.
  }

  Future<void> _openProfilePhoto(String url) async {
    if (url.trim().isEmpty) {
      await _showProfilePhotoOptions();
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Profile Photo',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 54,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Unable to load profile photo',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showProfilePhotoOptions() async {
    if (_uploadingProfilePhoto) return;

    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9E0E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'View or update your profile picture',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A94A6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                _photoActionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select a photo from your device',
                  onTap: () => Navigator.pop(sheetContext, 'gallery'),
                ),
                const SizedBox(height: 9),
                _photoActionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a Photo',
                  subtitle: 'Use your device camera',
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
                const SizedBox(height: 9),
                _photoActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Remove Photo',
                  subtitle: 'Remove the current profile picture',
                  destructive: true,
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'gallery':
        await _pickProfilePhoto(ImageSource.gallery);
        break;
      case 'camera':
        await _pickProfilePhoto(ImageSource.camera);
        break;
      case 'remove':
        await _removeProfilePhoto();
        break;
    }
  }

  Widget _photoActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final iconColor =
        destructive ? Colors.redAccent : const Color(0xFF4CA1AF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: destructive
                ? Colors.red.withOpacity(.045)
                : const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: destructive
                  ? Colors.red.withOpacity(.10)
                  : const Color(0xFFE8EEF3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: destructive
                      ? Colors.red.withOpacity(.08)
                      : const Color(0xFFEAF7F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: destructive
                            ? Colors.redAccent
                            : const Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A94A6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: destructive
                    ? Colors.redAccent.withOpacity(.65)
                    : const Color(0xFF9AA6B5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    if (_uploadingProfilePhoto) return;

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (bytes.isEmpty) {
        _showMessage(
          'Unable to read the selected image.',
          isError: true,
        );
        return;
      }

      const maxBytes = 10 * 1024 * 1024;

      if (bytes.length > maxBytes) {
        _showMessage(
          'Profile photo must be smaller than 10 MB.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _uploadingProfilePhoto = true;
        _profilePhotoUploadProgress = 0;
      });

      final extension = _fileExtension(picked.name).isEmpty
          ? 'jpg'
          : _fileExtension(picked.name);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'user-profile-photos/${widget.userId}/$timestamp-profile.$extension';

      final storageRef =
          FirebaseStorage.instance.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: _contentType(picked.name),
      );

      final uploadTask = storageRef.putData(
        bytes,
        metadata,
      );

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (!mounted) return;

          final total = snapshot.totalBytes;

          if (total > 0) {
            setState(() {
              _profilePhotoUploadProgress =
                  snapshot.bytesTransferred / total;
            });
          }
        },
      );

      final snapshot = await uploadTask;
      final downloadUrl =
          await snapshot.ref.getDownloadURL();

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);

      final currentSnapshot = await userRef.get();
      final currentData = currentSnapshot.data() ?? {};
      final oldStoragePath =
          _profilePhotoStoragePath(currentData);

      await userRef.update({
        'profilePhotoUrl': downloadUrl,
        'profilePhotoStoragePath': storagePath,
        'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (oldStoragePath.isNotEmpty &&
          oldStoragePath != storagePath) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(oldStoragePath)
              .delete();
        } catch (e) {
          debugPrint(
            'Old profile photo delete skipped/failed: $e',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _uploadingProfilePhoto = false;
        _profilePhotoUploadProgress = 0;
      });

      _showMessage('Profile photo updated successfully.');
    } catch (e) {
      debugPrint('Profile photo upload error: $e');

      if (!mounted) return;

      setState(() {
        _uploadingProfilePhoto = false;
        _profilePhotoUploadProgress = 0;
      });

      _showMessage(
        'Failed to update profile photo.',
        isError: true,
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    if (_uploadingProfilePhoto) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Remove Profile Photo?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Your current profile photo will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);

      final snapshot = await userRef.get();
      final data = snapshot.data() ?? {};
      final oldStoragePath =
          _profilePhotoStoragePath(data);

      if (oldStoragePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(oldStoragePath)
              .delete();
        } catch (e) {
          debugPrint(
            'Profile photo storage delete skipped/failed: $e',
          );
        }
      }

      await userRef.update({
        'profilePhotoUrl': FieldValue.delete(),
        'profilePhotoStoragePath': FieldValue.delete(),
        'profilePhotoUpdatedAt': FieldValue.delete(),
      });

      if (!mounted) return;

      _showMessage('Profile photo removed.');
    } catch (e) {
      debugPrint('Remove profile photo error: $e');

      if (!mounted) return;

      _showMessage(
        'Failed to remove profile photo.',
        isError: true,
      );
    }
  }

  Widget _profileAvatar({
    required String name,
    required bool active,
    required String photoUrl,
  }) {
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _uploadingProfilePhoto
              ? null
              : () async {
                  if (hasPhoto) {
                    await _openProfilePhoto(photoUrl);
                  } else {
                    await _showProfilePhotoOptions();
                  }
                },
          child: Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: Colors.white.withOpacity(.85),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(.22),
                ),
              ],
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasPhoto
                ? null
                : Center(
                    child: Text(
                      _initial(name),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4CA1AF),
                      ),
                    ),
                  ),
          ),
        ),

        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _uploadingProfilePhoto
                  ? null
                  : _showProfilePhotoOptions,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CA1AF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                      color: Colors.black.withOpacity(.18),
                    ),
                  ],
                ),
                child: _uploadingProfilePhoto
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
              ),
            ),
          ),
        ),

        Positioned(
          right: 1,
          bottom: 2,
          child: IgnorePointer(
            child: Transform.translate(
              offset: const Offset(0, 0),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoUploadProgress() {
    if (!_uploadingProfilePhoto) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _profilePhotoUploadProgress,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(.20),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Updating photo ${(_profilePhotoUploadProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UPLOAD DOCUMENT
  // ============================================================

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

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      final Uint8List? bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        _showMessage(
          'Unable to read the selected file.',
          isError: true,
        );
        return;
      }

      final fileName = file.name;

      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final safeFileName = fileName
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final storagePath =
          'user-documents/${widget.userId}/$timestamp-$safeFileName';

      final storageRef =
          FirebaseStorage.instance.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: _contentType(fileName),
      );

      final uploadTask = storageRef.putData(
        bytes,
        metadata,
      );

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (!mounted) return;

          final total = snapshot.totalBytes;

          if (total > 0) {
            setState(() {
              _uploadProgress =
                  snapshot.bytesTransferred / total;
            });
          }
        },
      );

      final snapshot = await uploadTask;

      final downloadUrl =
          await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('documents')
          .add({
        'name': fileName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'size': bytes.length,
        'extension': _fileExtension(fileName),
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });

      _showMessage(
        'Document uploaded successfully.',
      );
    } catch (e) {
      debugPrint('Document upload error: $e');

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });

      _showMessage(
        'Failed to upload document.',
        isError: true,
      );
    }
  }

  // ============================================================
  // CONTENT TYPE
  // ============================================================

  String _contentType(String fileName) {
    final extension = _fileExtension(fileName);

    switch (extension) {
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
  // OPEN DOCUMENT
  // ============================================================

  Future<void> _openDocument(
    Map<String, dynamic> document,
  ) async {
    final url = _value(
      document['downloadUrl'],
      fallback: '',
    );

    if (url.isEmpty) {
      _showMessage(
        'Document link is unavailable.',
        isError: true,
      );
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null) {
      _showMessage(
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
        _showMessage(
          'Unable to open document.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Open document error: $e');

      _showMessage(
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
            'Are you sure you want to delete '
            '"${_value(document['name'], fallback: 'this document')}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePath = _value(
        document['storagePath'],
        fallback: '',
      );

      if (storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(storagePath)
              .delete();
        } catch (e) {
          debugPrint(
            'Storage delete skipped/failed: $e',
          );
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('documents')
          .doc(documentId)
          .delete();

      if (!mounted) return;

      _showMessage(
        'Document deleted.',
      );
    } catch (e) {
      debugPrint('Delete document error: $e');

      if (!mounted) return;

      _showMessage(
        'Failed to delete document.',
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
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
              isError ? Colors.redAccent : const Color(0xFF2C3E50),
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
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9EEF5),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.045),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // HEADER
          // ------------------------------------------------------

          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEAF7F8),
                      Color(0xFFF2FAFB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
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
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Upload and manage your documents',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A94A6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ------------------------------------------------------
          // UPLOAD BUTTON
          // ------------------------------------------------------

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
                    Color(0xFF2C3E50),
                    Color(0xFF4CA1AF),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                    color: const Color(0xFF4CA1AF)
                        .withOpacity(.20),
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
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

          // ------------------------------------------------------
          // UPLOAD PROGRESS
          // ------------------------------------------------------

          if (_uploading) ...[
            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE8EEF3),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4CA1AF),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ------------------------------------------------------
          // DOCUMENT LIST
          // ------------------------------------------------------

          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('documents')
                .orderBy(
                  'uploadedAt',
                  descending: true,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF4CA1AF),
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

              final documents =
                  snapshot.data?.docs ?? [];

              // --------------------------------------------------
              // EMPTY
              // --------------------------------------------------

              if (documents.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 25,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: const Color(0xFFE8EEF3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F8),
                          borderRadius:
                              BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.folder_open_outlined,
                          color: Color(0xFF4CA1AF),
                          size: 28,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'No Documents Yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF172033),
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Upload your documents using the button above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A94A6),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // --------------------------------------------------
              // LIST
              // --------------------------------------------------

              return Column(
                children: documents.map((doc) {
                  final data = doc.data();

                  final name = _value(
                    data['name'],
                    fallback: 'Document',
                  );

                  final size =
                      _formatFileSize(data['size']);

                  final date =
                      _formatDate(data['uploadedAt']);

                  return _documentTile(
                    documentId: doc.id,
                    document: data,
                    name: name,
                    size: size,
                    date: date,
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
  // DOCUMENT TILE
  // ============================================================

  Widget _documentTile({
    required String documentId,
    required Map<String, dynamic> document,
    required String name,
    required String size,
    required String date,
  }) {
    final extension = _fileExtension(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE8EEF3),
        ),
      ),
      child: Row(
        children: [
          // ------------------------------------------------------
          // ICON
          // ------------------------------------------------------

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: extension == 'pdf'
                  ? Colors.red.withOpacity(.08)
                  : const Color(0xFFEAF7F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _documentIcon(name),
              color: extension == 'pdf'
                  ? Colors.redAccent
                  : const Color(0xFF4CA1AF),
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // ------------------------------------------------------
          // NAME
          // ------------------------------------------------------

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

                const SizedBox(height: 5),

                Row(
                  children: [
                    if (extension.isNotEmpty)
                      Text(
                        extension.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4CA1AF),
                        ),
                      ),

                    if (size.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      const Text(
                        '•',
                        style: TextStyle(
                          color: Color(0xFFB0BAC7),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        size,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF8A94A6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      const Text(
                        '•',
                        style: TextStyle(
                          color: Color(0xFFB0BAC7),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF8A94A6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ------------------------------------------------------
          // VIEW
          // ------------------------------------------------------

          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () {
                _openDocument(document);
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F8),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF4CA1AF),
                  size: 19,
                ),
              ),
            ),
          ),

          const SizedBox(width: 7),

          // ------------------------------------------------------
          // DELETE
          // ------------------------------------------------------

          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () {
                _deleteDocument(
                  documentId,
                  document,
                );
              },
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
  }

  // ============================================================
  // ERROR VIEW
  // ============================================================

  Widget _errorView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
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
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    color: Colors.black.withOpacity(.06),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Unable to Load Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
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
      backgroundColor: const Color(0xFFF5F7FB),
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
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    color: Colors.black.withOpacity(.06),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF4CA1AF).withOpacity(.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_off_outlined,
                      color: Color(0xFF4CA1AF),
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Profile Not Found',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Your profile information could not be found.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        // --------------------------------------------------------
        // LOADING
        // --------------------------------------------------------

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FB),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CA1AF),
              ),
            ),
          );
        }

        // --------------------------------------------------------
        // ERROR
        // --------------------------------------------------------

        if (snapshot.hasError) {
          return _errorView();
        }

        // --------------------------------------------------------
        // DOCUMENT CHECK
        // --------------------------------------------------------

        if (!snapshot.hasData ||
            !snapshot.data!.exists) {
          return _notFoundView();
        }

        final data =
            snapshot.data!.data() ?? {};

        // --------------------------------------------------------
        // DATA
        // --------------------------------------------------------

        final name = _value(
          data['name'],
          fallback: 'User',
        );

        final role = _value(
          data['role'],
          fallback: 'User',
        );

        final email = _value(
          data['email'],
        );

        final phone = _value(
          data['phone'],
        );

        final branchId = _value(
          data['branchId'],
        );

        final active = data['active'] == true;

        final salary = _salaryText(
          data['salaryMonthly'],
        );

        final displayRole =
            _capitalize(role);

        // --------------------------------------------------------
        // MAIN
        // --------------------------------------------------------

        return Scaffold(
          backgroundColor:
              const Color(0xFFF5F7FB),

          body: RefreshIndicator(
            color: const Color(0xFF4CA1AF),
            backgroundColor: Colors.white,

            onRefresh: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .get(
                    const GetOptions(
                      source: Source.server,
                    ),
                  );
            },

            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              slivers: [
                // =================================================
                // PREMIUM HEADER
                // =================================================

                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,

                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      22,
                    ),

                    decoration:
                        const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF172A3A),
                          Color(0xFF2C3E50),
                          Color(0xFF4CA1AF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.only(
                        bottomLeft:
                            Radius.circular(34),
                        bottomRight:
                            Radius.circular(34),
                      ),
                    ),

                    child: SafeArea(
                      bottom: false,

                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'My Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),

                              _statusBadge(
                                active: active,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // PROFILE PHOTO
                          _profileAvatar(
                            name: name,
                            active: active,
                            photoUrl: _profilePhotoUrl(data),
                          ),

                          _buildProfilePhotoUploadProgress(),

                          const SizedBox(height: 15),

                          Text(
                            name,
                            textAlign:
                                TextAlign.center,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.w900,
                              height: 1.15,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            displayRole,
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              _quickInfo(
                                icon: Icons
                                    .phone_outlined,
                                label: 'PHONE',
                                value:
                                    phone ==
                                            'Not provided'
                                        ? 'Not added'
                                        : phone,
                              ),

                              const SizedBox(width: 10),

                              _quickInfo(
                                icon: Icons
                                    .work_outline,
                                label: 'ROLE',
                                value:
                                    displayRole,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // =================================================
                // CONTENT
                // =================================================

                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    30,
                  ),

                  sliver: SliverList(
                    delegate:
                        SliverChildListDelegate(
                      [
                        // CONTACT
                        _sectionCard(
                          title:
                              'Contact Information',
                          icon: Icons
                              .contact_page_outlined,
                          children: [
                            _infoItem(
                              icon: Icons
                                  .phone_outlined,
                              title:
                                  'Phone Number',
                              value: phone,
                            ),

                            _infoItem(
                              icon: Icons
                                  .email_outlined,
                              title:
                                  'Email Address',
                              value: email,
                            ),
                          ],
                        ),

                        // WORK
                        _sectionCard(
                          title:
                              'Work Information',
                          icon: Icons
                              .work_outline,
                          children: [
                            _infoItem(
                              icon: Icons
                                  .badge_outlined,
                              title: 'Role',
                              value:
                                  displayRole,
                            ),

                            _infoItem(
                              icon: Icons
                                  .business_outlined,
                              title: 'Branch',
                              value: branchId,
                            ),
                          ],
                        ),

                        // SALARY
                        if (salary !=
                            'Not provided')
                          Container(
                            width:
                                double.infinity,
                            margin:
                                const EdgeInsets
                                    .only(
                              bottom: 16,
                            ),
                            padding:
                                const EdgeInsets.all(
                              21,
                            ),
                            decoration:
                                BoxDecoration(
                              gradient:
                                  const LinearGradient(
                                colors: [
                                  Color(0xFF172A3A),
                                  Color(0xFF2C3E50),
                                  Color(0xFF4CA1AF),
                                ],
                                begin:
                                    Alignment.topLeft,
                                end:
                                    Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                22,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 22,
                                  offset:
                                      const Offset(
                                    0,
                                    8,
                                  ),
                                  color: Colors.black
                                      .withOpacity(
                                    .10,
                                  ),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration:
                                      BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(
                                      .14,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      15,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .payments_outlined,
                                    color:
                                        Colors.white,
                                    size: 25,
                                  ),
                                ),

                                const SizedBox(
                                  width: 15,
                                ),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      const Text(
                                        'MONTHLY SALARY',
                                        style:
                                            TextStyle(
                                          color:
                                              Colors.white60,
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight
                                                  .w700,
                                          letterSpacing:
                                              .5,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 5,
                                      ),

                                      Text(
                                        salary,
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white,
                                          fontSize: 22,
                                          fontWeight:
                                              FontWeight
                                                  .w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // =================================================
                        // DOCUMENTS
                        // =================================================

                        _documentsSection(),

                        // =================================================
                        // ACCOUNT STATUS
                        // =================================================

                        _sectionCard(
                          title:
                              'Account Status',
                          icon: Icons
                              .verified_user_outlined,
                          children: [
                            _infoItem(
                              icon: active
                                  ? Icons
                                      .check_circle_outline
                                  : Icons
                                      .cancel_outlined,
                              title:
                                  'Account Status',
                              value: active
                                  ? 'Active'
                                  : 'Inactive',
                            ),
                          ],
                        ),

                        // FOOTER
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 4,
                            bottom: 8,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 42,
                                height: 4,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFDDE3EA,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 14,
                              ),

                              const Text(
                                'BMM Workforce',
                                style:
                                    TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: Color(
                                    0xFF4CA1AF,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 3,
                              ),

                              const Text(
                                'Secure workforce management',
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ],
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
    );
  }
}