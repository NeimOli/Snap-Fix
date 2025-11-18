import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isPermissionGranted = false;
  bool _isCapturing = false;
  bool _isRearCameraSelected = true;
  bool _isInitializingCamera = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    _initializeCamera();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _isPermissionGranted = false;
          _isInitializingCamera = false;
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No camera found on this device.';
          _isInitializingCamera = false;
        });
        return;
      }

      _availableCameras = cameras;
      await _startCamera();
      setState(() {
        _isPermissionGranted = true;
        _isInitializingCamera = false;
      });
    } catch (error) {
      setState(() {
        _cameraError = 'Failed to initialize camera: $error';
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _startCamera() async {
    final camera = _selectCamera();
    if (camera == null) {
      setState(() {
        _cameraError = 'Unable to access camera.';
      });
      return;
    }
    await _cameraController?.dispose();
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  CameraDescription? _selectCamera() {
    if (_availableCameras.isEmpty) return null;

    final preferredDirection = _isRearCameraSelected ? CameraLensDirection.back : CameraLensDirection.front;
    try {
      return _availableCameras.firstWhere((camera) => camera.lensDirection == preferredDirection);
    } catch (_) {
      return _availableCameras.first;
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) return;
    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
      _isInitializingCamera = true;
    });
    await _startCamera();
    setState(() {
      _isInitializingCamera = false;
    });
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    setState(() {
      _isCapturing = true;
    });
    try {
      final XFile photo = await _cameraController!.takePicture();
      // TODO: send the captured image to backend AI analysis
      if (!mounted) return;
      context.go('/results', extra: {'imagePath': photo.path});
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Widget _buildCameraPreview() {
    if (!_isPermissionGranted) {
      return _buildPermissionView();
    }

    if (_isInitializingCamera) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_cameraError != null) {
      return Center(
        child: Text(
          _cameraError!,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return CameraPreview(_cameraController!);
  }

  Widget _buildPermissionView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1F1F1F),
            Color(0xFF2F2F2F),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 80, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Needed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'SnapFix needs camera access to analyze problems.\nPlease grant permission to continue.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final status = await Permission.camera.request();
                  if (status.isGranted) {
                    _initializeCamera();
                  } else if (status.isPermanentlyDenied) {
                    await openAppSettings();
                  } else {
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraPreview()),
          _buildGradientOverlay(),
          _buildTopControls(context),
          if (_isPermissionGranted && _cameraController != null && _cameraController!.value.isInitialized)
            _buildFocusIndicator(),
          _buildBottomControls(context),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black54,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => context.pop(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SnapFix',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildIconButton(
                  icon: Icons.flash_off,
                  onTap: () {},
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusIndicator() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  _buildCornerIndicator(alignment: Alignment.topLeft),
                  _buildCornerIndicator(alignment: Alignment.topRight),
                  _buildCornerIndicator(alignment: Alignment.bottomLeft),
                  _buildCornerIndicator(alignment: Alignment.bottomRight),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCornerIndicator({required Alignment alignment}) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconButton(
                    icon: Icons.image,
                    onTap: () {},
                    shape: BoxShape.rectangle,
                  ),
                  GestureDetector(
                    onTap: _isCapturing ? null : _capturePhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isCapturing ? 60 : 80,
                      height: _isCapturing ? 60 : 80,
                      decoration: BoxDecoration(
                        color: _isCapturing ? Colors.red : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Icon(
                        _isCapturing ? Icons.stop : Icons.camera_alt,
                        color: _isCapturing ? Colors.white : Colors.black,
                        size: 28,
                      ),
                    ),
                  ),
                  _buildIconButton(
                    icon: Icons.flip_camera_ios,
                    onTap: _switchCamera,
                    shape: BoxShape.circle,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Position the problem in the frame and tap to capture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: shape == BoxShape.circle ? 50 : 48,
        height: shape == BoxShape.circle ? 50 : 48,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(12) : null,
          shape: shape,
          border: shape == BoxShape.rectangle ? Border.all(color: Colors.white24) : null,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
