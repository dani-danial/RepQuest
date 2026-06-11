import 'package:web/web.dart' as web;

import '../models/detected_pose.dart';
import 'mediapipe_web.dart' as mp;

class PoseDetectorService {
  Future<void> initialize() => mp.ensureMediaPipeInitialized();

  Future<void> attachVideo(web.HTMLVideoElement video) =>
      mp.attachCameraVideo(video);

  Future<DetectedPose?> detectVideoFrame() async {
    final points = await mp.detectVideoFrame();
    return _toDetectedPose(points);
  }

  DetectedPose? _toDetectedPose(List<Map<String, double>>? points) {
    if (points == null || points.isEmpty) return null;

    final landmarks = <int, DetectedLandmark>{};
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      landmarks[i] = DetectedLandmark(
        x: point['x']!,
        y: point['y']!,
        visibility: point['visibility'] ?? 1.0,
      );
    }

    return DetectedPose(landmarks: landmarks);
  }

  void dispose() {
    mp.stopCameraVideo();
  }
}
