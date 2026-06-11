import '../models/detected_pose.dart';

/// Exponential moving average filter for pose landmarks.
class LandmarkSmoother {
  LandmarkSmoother({this.alpha = 0.45});

  /// Higher = snappier, lower = smoother overlay.
  final double alpha;

  final Map<int, DetectedLandmark> _previous = {};

  DetectedPose smooth(DetectedPose raw) {
    final smoothed = <int, DetectedLandmark>{};

    for (final entry in raw.landmarks.entries) {
      final current = entry.value;
      final prev = _previous[entry.key];

      if (prev == null || current.visibility < 0.35) {
        smoothed[entry.key] = current;
        continue;
      }

      smoothed[entry.key] = DetectedLandmark(
        x: prev.x + alpha * (current.x - prev.x),
        y: prev.y + alpha * (current.y - prev.y),
        visibility: current.visibility,
      );
    }

    _previous
      ..clear()
      ..addAll(smoothed);

    return DetectedPose(landmarks: smoothed);
  }

  void reset() => _previous.clear();
}
