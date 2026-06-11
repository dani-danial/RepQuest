/// Shared tuning for rep counting stability.
abstract final class PoseTrackingConfig {
  static const double visibilityThreshold = 0.55;

  /// Enter "down" when smoothed elbow angle drops below this.
  static const double downAngleThreshold = 100;

  /// Complete a rep when smoothed elbow angle rises above this.
  static const double upAngleThreshold = 155;

  /// Frames required before a state transition is accepted.
  static const int confirmFrames = 3;

  /// EMA factor for elbow angle (lower = smoother counting).
  static const double angleSmoothingAlpha = 0.35;
  static const double minBodyStraightAngle = 135.0;
}
