import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pushup_counter_controller.dart';
import 'pose_skeleton_painter.dart';
import 'services/pose_detector_service_mobile.dart';

class CameraViewScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraViewScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  CameraController? _cameraController;
  late PoseDetectorService _poseDetectorService;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _poseDetectorService = PoseDetectorService();
    _initializeCamera();
  }

  ImageFormatGroup _imageFormatGroup() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return ImageFormatGroup.nv21;
      case TargetPlatform.iOS:
        return ImageFormatGroup.bgra8888;
      default:
        return ImageFormatGroup.unknown;
    }
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _errorMessage = 'No camera found on this device.');
      return;
    }

    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: _imageFormatGroup(),
    );

    try {
      await controller.initialize();
      await controller.startImageStream(_processCameraImage);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      await controller.dispose();
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start camera: $e');
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _cameraController == null) return;
    _isProcessing = true;

    try {
      final detected = await _poseDetectorService.processCameraImage(
        image,
        _cameraController!.description,
      );
      if (detected != null && mounted) {
        Provider.of<PushupCounterController>(context, listen: false)
            .processPose(detected);
      }
    } catch (e) {
      debugPrint('Camera processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _ErrorScaffold(message: _errorMessage!);
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return _TrackingOverlay(
      cameraController: _cameraController!,
    );
  }
}

class _TrackingOverlay extends StatelessWidget {
  final CameraController cameraController;

  const _TrackingOverlay({required this.cameraController});

  @override
  Widget build(BuildContext context) {
    final isFrontCamera =
        cameraController.description.lensDirection == CameraLensDirection.front;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(cameraController),
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: PoseSkeletonPainter(
                    landmarks: controller.currentLandmarks,
                    isFrontCamera: isFrontCamera,
                  ),
                ),
              );
            },
          ),
          const _HudOverlay(),
        ],
      ),
    );
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<PushupCounterController>(
        builder: (context, controller, child) {
          final isWarning = controller.feedback == "FIX YOUR BACK!";
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              // Doodly Feedback Banner
              CustomPaint(
                painter: _DoodlyBoxPainter(
                  color: isWarning ? Colors.redAccent : Colors.amberAccent,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  child: Text(
                    controller.feedback,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontFamily: 'Comic Sans MS', // Fallback playful font
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Doodly Counter
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: _DoodlyCirclePainter(),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Center(
                        child: Text(
                          '${controller.repCount}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 60,
                            fontFamily: 'Comic Sans MS',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }
}

// Custom Painter for a sketchy box
class _DoodlyBoxPainter extends CustomPainter {
  final Color color;
  _DoodlyBoxPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw an imperfect rectangle
    final path = Path()
      ..moveTo(5, 5)
      ..lineTo(size.width - 2, -2)
      ..lineTo(size.width + 4, size.height - 4)
      ..lineTo(-3, size.height + 2)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for a sketchy circle
class _DoodlyCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = Colors.black..strokeWidth = 4..style = PaintingStyle.stroke;

    canvas.drawCircle(center, size.width / 2, paint);
    
    // Draw sketchy offset rings
    canvas.drawCircle(center + const Offset(-2, 2), size.width / 2 + 2, strokePaint..strokeWidth = 2);
    canvas.drawCircle(center + const Offset(1, -1), size.width / 2 - 1, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorScaffold extends StatelessWidget {
  final String message;

  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
