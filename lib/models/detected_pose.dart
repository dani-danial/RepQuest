/// Platform-agnostic pose landmarks (MediaPipe index scheme).
class DetectedLandmark {
  final double x;
  final double y;
  final double visibility;

  const DetectedLandmark({
    required this.x,
    required this.y,
    this.visibility = 1.0,
  });
}

class DetectedPose {
  final Map<int, DetectedLandmark> landmarks;

  const DetectedPose({required this.landmarks});

  static const int leftShoulder = 11;
  static const int leftElbow = 13;
  static const int leftWrist = 15;
  static const int rightShoulder = 12;
  static const int rightElbow = 14;
  static const int rightWrist = 16;
}
