// lib/screens/attendance_camera_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class AttendanceCameraScreen extends StatefulWidget {
  const AttendanceCameraScreen({super.key});

  @override
  State<AttendanceCameraScreen> createState() => _AttendanceCameraScreenState();
}

class _AttendanceCameraScreenState extends State<AttendanceCameraScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCapturing = false;
  int _selectedIndex = 0; // which camera we are using (0 = first in list)

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Prefer back camera first, fallback to first available
      int backIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _selectedIndex = backIndex != -1 ? backIndex : 0;

      await _initControllerForIndex(_selectedIndex);
    } catch (e) {
      debugPrint('[AttendanceCamera] Error initializing cameras: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open camera: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _initControllerForIndex(int index) async {
    try {
      final camera = _cameras[index];

      final oldController = _controller;
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();

      // Dispose old controller *after* swapping
      await oldController?.dispose();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[AttendanceCamera] Error init controller: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch camera: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() => _isCapturing = true);
    try {
      await _initializeControllerFuture;
      final pic = await controller.takePicture();
      if (!mounted) return;

      // Return the captured file to previous screen
      Navigator.pop(context, pic);
    } catch (e) {
      debugPrint('[AttendanceCamera] Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      // Only one camera available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other camera to switch')),
      );
      return;
    }

    final newIndex = (_selectedIndex + 1) % _cameras.length;
    setState(() {
      _selectedIndex = newIndex;
    });
    await _initControllerForIndex(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final currentCamera = (_cameras.isNotEmpty && _selectedIndex < _cameras.length)
        ? _cameras[_selectedIndex]
        : null;

    final isFront = currentCamera?.lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Capture Photo'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _switchCamera,
              tooltip: 'Switch camera',
              icon: Icon(isFront ? Icons.camera_rear : Icons.camera_front),
            ),
        ],
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Stack(
                  children: [
                    Center(child: CameraPreview(controller)),
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: FloatingActionButton(
                          onPressed: _isCapturing ? null : _takePicture,
                          child: _isCapturing
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.camera_alt),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
