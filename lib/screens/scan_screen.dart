import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/analysis_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _DescriptionInput extends StatelessWidget {
  const _DescriptionInput({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      maxLines: 3,
      decoration: InputDecoration(
        hintText: enabled
            ? 'Describe the problem briefly (e.g. leaking pipe, broken hinge)'
            : 'Capture/select an image to enable description',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }
}

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({
    required this.isAnalyzing,
    required this.enabled,
    required this.onPressed,
  });

  final bool isAnalyzing;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled && !isAnalyzing ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: isAnalyzing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_fix_high_outlined, color: Colors.white),
        label: Text(
          isAnalyzing ? 'Analyzing...' : 'Analyze Problem',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.image,
    required this.onClear,
  });

  final File image;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.file(image, height: 150, width: double.infinity, fit: BoxFit.cover),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisResultCard extends StatelessWidget {
  const _AnalysisResultCard({this.result});

  final AnalysisResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Your step-by-step solution will appear here after analysis.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Steps',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (result!.steps.isEmpty)
            Text(result!.summary, style: const TextStyle(color: Colors.white70))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...result!.steps.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            entry.value.trim(),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2432), Color(0xFF131A24)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 70),
          SizedBox(height: 12),
          Text(
            'Camera preview will appear here once enabled.',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _CameraErrorState extends StatelessWidget {
  const _CameraErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  bool _cameraGranted = false;
  bool _checkingPermission = false;
  bool _permanentlyDenied = false;
  bool _initializingCamera = false;
  CameraController? _cameraController;
  String? _cameraError;
  final ImagePicker _imagePicker = ImagePicker();
  List<CameraDescription> _availableCameras = [];
  CameraDescription? _currentCamera;
  CameraDescription? _frontCamera;
  CameraDescription? _backCamera;
  File? _selectedImage;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isAnalyzing = false;
  AnalysisResult? _analysisResult;
  String? _analysisError;

  bool get _isCameraReady => _cameraController?.value.isInitialized ?? false;

  Future<void> _requestCameraPermission() async {
    setState(() => _checkingPermission = true);
    final status = await Permission.camera.request();
    final permanentlyDenied = status.isPermanentlyDenied;
    setState(() {
      _cameraGranted = status.isGranted;
      _permanentlyDenied = permanentlyDenied;
      _checkingPermission = false;
    });

    if (status.isGranted) {
      await _initializeCamera();
    } else {
      await _disposeCameraController();
    }

    if (permanentlyDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable camera access in system settings to continue.'),
          ),
        );
      }
      await openAppSettings();
    }
  }

  Future<bool> _requestGalleryPermission() async {
    final permissionsToTry = Platform.isIOS
        ? [Permission.photos]
        : [Permission.photos, Permission.storage];

    for (final permission in permissionsToTry) {
      var status = await permission.status;

      if (status.isGranted) {
        return true;
      }

      status = await permission.request();

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          final message = permission == Permission.photos
              ? 'Photos access is required to choose from your gallery. Enable it in settings.'
              : 'Storage access is required to choose from your gallery. Enable it in settings.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
            ),
          );
        }
        await openAppSettings();
        return false;
      }
    }

    return false;
  }

  Future<void> _handlePickFromGallery() async {
    final hasPermission = await _requestGalleryPermission();
    if (!hasPermission || !mounted) return;

    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null || !mounted) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
        _analysisResult = null;
        _analysisError = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $error')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkPermissionOnLoad(promptIfDenied: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionOnLoad();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _disposeCameraController();
    }
  }

  Future<void> _checkPermissionOnLoad({bool promptIfDenied = false}) async {
    if (_checkingPermission) return;
    final status = await Permission.camera.status;
    if (mounted) {
      setState(() {
        _cameraGranted = status.isGranted;
        _permanentlyDenied = status.isPermanentlyDenied;
      });
    }

    if (status.isGranted) {
      if (!_isCameraReady) {
        await _initializeCamera();
      }
      return;
    }

    if (status.isPermanentlyDenied) {
      return;
    }

    if (promptIfDenied && !_checkingPermission) {
      await _requestCameraPermission();
    }
  }

  Future<void> _initializeCamera({CameraDescription? cameraDescription}) async {
    if (!_cameraGranted || _initializingCamera) return;

    setState(() {
      _initializingCamera = true;
      _cameraError = null;
    });

    final previousController = _cameraController;

    try {
      final cameras = _availableCameras.isNotEmpty ? _availableCameras : await availableCameras();
      _availableCameras = cameras;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No cameras available on this device.');
      }

      _frontCamera = _findCameraByDirection(cameras, CameraLensDirection.front) ?? _frontCamera;
      _backCamera = _findCameraByDirection(cameras, CameraLensDirection.back) ?? _backCamera ?? cameras.first;

      CameraDescription selectedCamera;
      if (cameraDescription != null) {
        selectedCamera = cameraDescription;
      } else if (_currentCamera != null) {
        selectedCamera = _currentCamera!;
      } else {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      await previousController?.dispose();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _currentCamera = selectedCamera;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Unable to access camera: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initializingCamera = false;
        });
      }
    }
  }

  Future<void> _disposeCameraController() async {
    final controller = _cameraController;
    if (controller != null) {
      setState(() {
        _cameraController = null;
      });
      await controller.dispose();
    }
  }

  Future<void> _handleSwitchCamera() async {
    if (!_cameraGranted) {
      await _requestCameraPermission();
      return;
    }

    if (_initializingCamera) {
      return;
    }

    try {
      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
      }

      _frontCamera = _findCameraByDirection(_availableCameras, CameraLensDirection.front) ?? _frontCamera;
      _backCamera = _findCameraByDirection(_availableCameras, CameraLensDirection.back) ?? _backCamera ?? (_availableCameras.isNotEmpty ? _availableCameras.first : null);

      if (_frontCamera == null && _backCamera == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available to switch.')),
          );
        }
        return;
      }

      CameraDescription? nextCamera;
      if (_currentCamera?.lensDirection == CameraLensDirection.front) {
        nextCamera = _backCamera ?? _currentCamera;
      } else {
        nextCamera = _frontCamera ?? _backCamera ?? _currentCamera;
      }

      if (nextCamera == null || nextCamera == _currentCamera) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to switch camera.')),
          );
        }
        return;
      }

      await _initializeCamera(cameraDescription: nextCamera);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to switch camera: $error')),
      );
    }
  }

  Future<void> _handleCapture() async {
    if (!_isCameraReady || _cameraController == null) return;
    try {
      final capture = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _selectedImage = File(capture.path);
        _analysisResult = null;
        _analysisError = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture image: $error')),
      );
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or select an image first.')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the problem before analyzing.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      final result = await AnalysisService.instance.analyzeImage(
        image: _selectedImage!,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _analysisResult = result;
      });

      final description = _descriptionController.text.trim();
      context.push(
        '/results',
        extra: <String, dynamic>{
          'imagePath': _selectedImage!.path,
          'analysisResult': <String, dynamic>{
            'problem': description.isEmpty ? 'Detected problem' : description,
            'cause': result.summary,
            'solution': result.steps,
            'tools': const <String>[],
            'difficulty': 'Medium',
            'estimatedTime': '30-60 minutes',
            'safety': const <String>[],
          },
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analysisError = error.toString();
        _analysisResult = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Widget _buildCameraViewport() {
    if (!_cameraGranted) {
      return const _CameraPlaceholder();
    } else if (_cameraError != null) {
      return _CameraErrorState(
        message: _cameraError!,
        onRetry: _initializeCamera,
      );
    } else if (_initializingCamera || !_isCameraReady) {
      return const _CameraLoading();
    } else {
      return CameraPreview(_cameraController!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraViewport()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      if (!_cameraGranted)
                        _PermissionBanner(
                          permanentlyDenied: _permanentlyDenied,
                          onRequest: _cameraGranted || _checkingPermission ? null : _requestCameraPermission,
                        ),
                      _TopControls(
                        onBack: () => context.pop(),
                        onOpenGallery: () {
                          _handlePickFromGallery();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImage != null)
                        _SelectedImagePreview(
                          image: _selectedImage!,
                          onClear: () {
                            setState(() {
                              _selectedImage = null;
                              _analysisResult = null;
                              _analysisError = null;
                            });
                          },
                        ),
                      const SizedBox(height: 12),
                      _DescriptionInput(
                        controller: _descriptionController,
                        enabled: _selectedImage != null && !_isAnalyzing,
                      ),
                      const SizedBox(height: 12),
                      _AnalyzeButton(
                        isAnalyzing: _isAnalyzing,
                        enabled: !_isAnalyzing && _selectedImage != null,
                        onPressed: _analyzeImage,
                      ),
                      if (_analysisError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _analysisError!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AnalysisResultCard(result: _analysisResult),
                            const SizedBox(height: 16),
                            _InstructionBubble(),
                            const SizedBox(height: 16),
                            _BottomControls(
                              captureEnabled: _isCameraReady && !_initializingCamera,
                              onRequestPermission:
                                  _cameraGranted && !_permanentlyDenied ? null : _requestCameraPermission,
                              onCapture: _isCameraReady ? _handleCapture : null,
                              onOpenGallery: _handlePickFromGallery,
                              onSwitchCamera: _handleSwitchCamera,
                            ),
                          ],
                        ),
                      ),
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
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({
    required this.permanentlyDenied,
    required this.onRequest,
  });

  final bool permanentlyDenied;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x33FFB347),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text(
                'Camera permission required',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            permanentlyDenied
                ? 'Camera access is blocked. Use system settings to grant permission.'
                : 'We need access to your camera to capture problems.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(permanentlyDenied ? 'Open Settings' : 'Enable Camera Access'),
          ),
        ],
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({required this.onBack, required this.onOpenGallery});

  final VoidCallback onBack;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleButton(icon: Icons.arrow_back, onTap: onBack),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'SnapFix',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        _CircleButton(icon: Icons.grid_view, onTap: onOpenGallery),
      ],
    );
  }
}

class _InstructionBubble extends StatelessWidget {
  const _InstructionBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Position the problem in the frame and tap to capture',
        style: TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.captureEnabled,
    required this.onRequestPermission,
    required this.onCapture,
    required this.onOpenGallery,
    required this.onSwitchCamera,
  });

  final bool captureEnabled;
  final VoidCallback? onRequestPermission;
  final VoidCallback? onCapture;
  final Future<void> Function()? onOpenGallery;
  final Future<void> Function()? onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withOpacity(0.4);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleButton(
          icon: Icons.photo_library_outlined,
          color: inactiveColor,
          onTap: () {
            onOpenGallery?.call();
          },
        ),
        GestureDetector(
          onTap: captureEnabled ? onCapture : onRequestPermission,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: captureEnabled ? Colors.white : inactiveColor,
            ),
            child: Icon(
              Icons.camera_alt,
              size: 34,
              color: captureEnabled ? Colors.black : Colors.white,
            ),
          ),
        ),
        _CircleButton(
          icon: Icons.cameraswitch,
          color: captureEnabled ? Colors.white.withOpacity(0.9) : inactiveColor,
          onTap: captureEnabled
              ? () {
                  onSwitchCamera?.call();
                }
              : null,
        ),
      ],
    );
  }
}

CameraDescription? _findCameraByDirection(
  List<CameraDescription> cameras,
  CameraLensDirection direction,
) {
  for (final camera in cameras) {
    if (camera.lensDirection == direction) {
      return camera;
    }
  }
  return null;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color ?? Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
