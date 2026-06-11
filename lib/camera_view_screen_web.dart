import 'dart:ui_web' as ui_web;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'pushup_counter_controller.dart';
import 'pose_skeleton_painter.dart';
import 'services/pose_detector_service_web.dart';

class CameraViewScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraViewScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  late final String _viewType;
  late final web.HTMLVideoElement _videoElement;
  late PoseDetectorService _poseDetectorService;

  bool _isProcessing = false;
  bool _isRunning = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'repquest-camera-$hashCode';
    _videoElement = web.document.createElement('video') as web.HTMLVideoElement;
    _poseDetectorService = PoseDetectorService();

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _videoElement,
    );

    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Loading pose model...';
    });

    try {
      await _poseDetectorService.initialize();
      if (!mounted) return;

      setState(() => _statusMessage = 'Starting camera...');
      await _poseDetectorService.attachVideo(_videoElement);
      if (!mounted) return;

      setState(() {
        _statusMessage = null;
        _errorMessage = null;
      });

      _startDetectionLoop();
    } catch (e) {
      debugPrint('Web initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize: $e';
          _statusMessage = null;
        });
      }
    }
  }

  void _startDetectionLoop() {
    if (_isRunning) return;
    _isRunning = true;

    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  Future<void> _onFrame(Duration timestamp) async {
    if (!mounted || !_isRunning) return;

    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);

    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final detected = await _poseDetectorService.detectVideoFrame();
      if (detected != null && mounted) {
        Provider.of<PushupCounterController>(context, listen: false)
            .processPose(detected);
      }
    } catch (e) {
      debugPrint('Web detection error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _isRunning = false;
    _poseDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _ErrorScaffold(
        message: _errorMessage!,
        onRetry: _initialize,
      );
    }

    if (_statusMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: PoseSkeletonPainter(
                    landmarks: controller.currentLandmarks,
                    isFrontCamera: true, // Web is usually front camera mirrored
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
                    style: const TextStyle(
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
  final VoidCallback onRetry;

  const _ErrorScaffold({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}