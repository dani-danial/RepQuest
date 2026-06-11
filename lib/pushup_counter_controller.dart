import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'models/detected_pose.dart';
import 'pose_skeleton_painter.dart' as painter;
import 'utils/landmark_smoother.dart';
import 'utils/pose_tracking_config.dart';

enum PushUpState { up, down }

class PushupCounterController extends ChangeNotifier {
  int repCount = 0;
  PushUpState currentState = PushUpState.up;
  String feedback = "PUSH UP";

  Map<int, painter.PoseLandmark> currentLandmarks = {};

  final LandmarkSmoother _landmarkSmoother = LandmarkSmoother(alpha: 0.5);

  double? _smoothedAngle;
  double? _smoothedBodyAngle; // NEW: Tracks if the back is straight
  
  int _downConfirmCount = 0;
  int _upConfirmCount = 0;

  void processPose(DetectedPose pose) {
    final smoothed = _landmarkSmoother.smooth(pose);

    currentLandmarks = {
      for (final entry in smoothed.landmarks.entries)
        entry.key: painter.PoseLandmark(x: entry.value.x, y: entry.value.y),
    };

    final arm = _selectBestArm(smoothed);
    final body = _selectBestBodySide(smoothed); // NEW: Get the body alignment

    if (arm != null) {
      // Calculate arm angle
      final armAngle = _calculateAngle(arm.shoulder, arm.elbow, arm.wrist);
      _smoothedAngle = _smoothedAngle == null
          ? armAngle
          : _smoothedAngle! +
              PoseTrackingConfig.angleSmoothingAlpha * (armAngle - _smoothedAngle!);

      if (body != null) {
        // Calculate body alignment angle (Shoulder -> Hip -> Knee)
        final bodyAngle = _calculateAngle(body.shoulder, body.hip, body.knee);
        _smoothedBodyAngle = _smoothedBodyAngle == null
            ? bodyAngle
            : _smoothedBodyAngle! + 
                PoseTrackingConfig.angleSmoothingAlpha * (bodyAngle - _smoothedBodyAngle!);

        _evaluateState(_smoothedAngle!, _smoothedBodyAngle!);
      } else {
        // Fallback: only track arm angle because lower body is not visible
        _smoothedBodyAngle = null;
        _evaluateStateNoBody(_smoothedAngle!);
      }
    } else {
      feedback = "POSITION NOT FULLY VISIBLE";
    }

    notifyListeners();
  }

  void _evaluateState(double armAngle, double bodyAngle) {
    final isBackStraight = bodyAngle >= PoseTrackingConfig.minBodyStraightAngle;

    if (!isBackStraight) {
      feedback = "FIX YOUR BACK!";
    } else if (feedback == "FIX YOUR BACK!") {
      // Clear the warning if back is now straight
      feedback = currentState == PushUpState.down ? "PUSH UP NOW!" : "LOWER BODY";
    }

    if (armAngle < PoseTrackingConfig.downAngleThreshold) {
      _downConfirmCount++;
      _upConfirmCount = 0;

      if (_downConfirmCount >= PoseTrackingConfig.confirmFrames &&
          currentState == PushUpState.up) {
        currentState = PushUpState.down;
        if (isBackStraight) {
          feedback = "PUSH UP NOW!";
        }
      }
    } else if (armAngle > PoseTrackingConfig.upAngleThreshold) {
      _upConfirmCount++;
      _downConfirmCount = 0;

      if (_upConfirmCount >= PoseTrackingConfig.confirmFrames &&
          currentState == PushUpState.down) {
        repCount++;
        currentState = PushUpState.up;
        if (isBackStraight) {
          feedback = "LOWER BODY";
        }
      }
    } else {
      _downConfirmCount = 0;
      _upConfirmCount = 0;
    }
  }

  void _evaluateStateNoBody(double armAngle) {
    // If the feedback was "FIX YOUR BACK!", clear it since we can't see the back anymore
    if (feedback == "FIX YOUR BACK!") {
      feedback = currentState == PushUpState.down ? "PUSH UP NOW!" : "LOWER BODY";
    }

    if (armAngle < PoseTrackingConfig.downAngleThreshold) {
      _downConfirmCount++;
      _upConfirmCount = 0;

      if (_downConfirmCount >= PoseTrackingConfig.confirmFrames &&
          currentState == PushUpState.up) {
        currentState = PushUpState.down;
        feedback = "PUSH UP NOW!";
      }
    } else if (armAngle > PoseTrackingConfig.upAngleThreshold) {
      _upConfirmCount++;
      _downConfirmCount = 0;

      if (_upConfirmCount >= PoseTrackingConfig.confirmFrames &&
          currentState == PushUpState.down) {
        repCount++;
        currentState = PushUpState.up;
        feedback = "LOWER BODY";
      }
    } else {
      _downConfirmCount = 0;
      _upConfirmCount = 0;
    }
  }

  _ArmLandmarks? _selectBestArm(DetectedPose pose) {
    final left = _armIfVisible(
      pose.landmarks[DetectedPose.leftShoulder],
      pose.landmarks[DetectedPose.leftElbow],
      pose.landmarks[DetectedPose.leftWrist],
    );
    final right = _armIfVisible(
      pose.landmarks[DetectedPose.rightShoulder],
      pose.landmarks[DetectedPose.rightElbow],
      pose.landmarks[DetectedPose.rightWrist],
    );

    if (left == null) return right;
    if (right == null) return left;

    final leftScore = left.shoulder.visibility +
        left.elbow.visibility +
        left.wrist.visibility;
    final rightScore = right.shoulder.visibility +
        right.elbow.visibility +
        right.wrist.visibility;

    return leftScore >= rightScore ? left : right;
  }

  _ArmLandmarks? _armIfVisible(
    DetectedLandmark? shoulder,
    DetectedLandmark? elbow,
    DetectedLandmark? wrist,
  ) {
    if (shoulder == null || elbow == null || wrist == null) return null;

    final threshold = PoseTrackingConfig.visibilityThreshold;
    if (shoulder.visibility < threshold ||
        elbow.visibility < threshold ||
        wrist.visibility < threshold) {
      return null;
    }

    return _ArmLandmarks(
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
    );
  }

  // NEW: Helper methods to extract hip and knee points
  _BodyLandmarks? _selectBestBodySide(DetectedPose pose) {
    final left = _bodyIfVisible(
      pose.landmarks[DetectedPose.leftShoulder],
      pose.landmarks[23], // 23 is Left Hip in MediaPipe
      pose.landmarks[25], // 25 is Left Knee in MediaPipe
    );
    final right = _bodyIfVisible(
      pose.landmarks[DetectedPose.rightShoulder],
      pose.landmarks[24], // 24 is Right Hip in MediaPipe
      pose.landmarks[26], // 26 is Right Knee in MediaPipe
    );
    
    // Return whichever side is visible
    return left ?? right; 
  }

  // NEW: Check if the body parts are visible
  _BodyLandmarks? _bodyIfVisible(
    DetectedLandmark? shoulder, 
    DetectedLandmark? hip, 
    DetectedLandmark? knee
  ) {
    if (shoulder == null || hip == null || knee == null) return null;
    final threshold = PoseTrackingConfig.visibilityThreshold;
    
    if (shoulder.visibility < threshold || 
        hip.visibility < threshold || 
        knee.visibility < threshold) {
      return null;
    }
    
    return _BodyLandmarks(shoulder: shoulder, hip: hip, knee: knee);
  }

  double _calculateAngle(
    DetectedLandmark first,
    DetectedLandmark middle,
    DetectedLandmark last,
  ) {
    final radians = math.atan2(last.y - middle.y, last.x - middle.x) -
        math.atan2(first.y - middle.y, first.x - middle.x);

    var degrees = (radians * 180.0 / math.pi).abs();
    if (degrees > 180.0) {
      degrees = 360.0 - degrees;
    }
    return degrees;
  }
}

class _ArmLandmarks {
  final DetectedLandmark shoulder;
  final DetectedLandmark elbow;
  final DetectedLandmark wrist;

  const _ArmLandmarks({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
  });
}

// NEW: Class to hold body landmarks
class _BodyLandmarks {
  final DetectedLandmark shoulder;
  final DetectedLandmark hip;
  final DetectedLandmark knee;

  const _BodyLandmarks({
    required this.shoulder,
    required this.hip,
    required this.knee,
  });
}