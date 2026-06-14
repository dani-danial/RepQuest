import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'models/boss.dart';
import 'models/detected_pose.dart';
import 'pose_skeleton_painter.dart' as painter;
import 'utils/landmark_smoother.dart';
import 'utils/pose_tracking_config.dart';

enum PushUpState { up, down }
enum CharacterClass { warrior, rogue, mage }

class FloatingDamage {
  final String text;
  final double offsetLeft;
  final Color color;
  final int id;
  FloatingDamage(this.text, {required this.color, required this.offsetLeft, required this.id});
}

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

  // RPG Boss List
  static const List<Boss> bosses = [
    Boss(name: "Goblin", maxHp: 5, imagePath: "assets/images/goblin.png", expReward: 30),
    Boss(name: "Orc Warrior", maxHp: 10, imagePath: "assets/images/orc.png", expReward: 60),
    Boss(name: "Stone Golem", maxHp: 15, imagePath: "assets/images/golem.png", expReward: 100),
    Boss(name: "Red Dragon", maxHp: 25, imagePath: "assets/images/dragon.png", expReward: 200),
  ];
  int currentBossIndex = 0;
  Boss get currentBoss => bosses[currentBossIndex];
  
  int enemyCurrentHp = 5;
  bool shouldShake = false;
  List<FloatingDamage> floatingDamages = [];
  int _nextDamageId = 0;

  // Player RPG stats
  int playerLevel = 1;
  int playerExp = 0;
  int get expNeededForNextLevel => playerLevel * 50;
  bool showLevelUpOverlay = false;

  // RPG Expansion Stats
  CharacterClass characterClass = CharacterClass.warrior;
  bool hasShield = true;
  int mageSpellCharge = 0;
  int playerHp = 10;
  static const int maxPlayerHp = 10;
  bool isDefeated = false;
  bool showRedFlash = false;
  int highestBossUnlocked = 0;

  // Workout Routine Sets & Campfire Rest
  static const List<int> targetReps = [5, 4, 3];
  int currentSetIndex = 0;
  int setRepsCount = 0;
  bool isResting = false;
  int restSecondsRemaining = 0;
  Timer? _restTimer;
  bool isWorkoutComplete = false;

  bool get isVictory => enemyCurrentHp <= 0;

  void resetBattle() {
    repCount = 0;
    currentState = PushUpState.up;
    feedback = "PUSH UP";
    currentBossIndex = 0;
    enemyCurrentHp = currentBoss.maxHp;
    _downConfirmCount = 0;
    _upConfirmCount = 0;
    _smoothedAngle = null;
    _smoothedBodyAngle = null;
    currentLandmarks.clear();
    floatingDamages.clear();
    shouldShake = false;
    currentSetIndex = 0;
    setRepsCount = 0;
    isResting = false;
    isWorkoutComplete = false;
    _restTimer?.cancel();

    // Reset HP & Shield
    playerHp = maxPlayerHp;
    isDefeated = false;
    showRedFlash = false;
    mageSpellCharge = 0;
    hasShield = (characterClass == CharacterClass.warrior);

    notifyListeners();
  }

  void nextBoss() {
    if (currentBossIndex < bosses.length - 1) {
      currentBossIndex++;
    } else {
      currentBossIndex = 0; // Wrap around
    }
    enemyCurrentHp = currentBoss.maxHp;
    feedback = "LOWER BODY";
    notifyListeners();
  }

  void selectClass(CharacterClass newClass) {
    characterClass = newClass;
    hasShield = (newClass == CharacterClass.warrior);
    mageSpellCharge = 0;
    notifyListeners();
  }

  void selectBoss(int index) {
    if (index <= highestBossUnlocked && index < bosses.length) {
      currentBossIndex = index;
      enemyCurrentHp = currentBoss.maxHp;
      feedback = "LOWER BODY";
      
      // Reset combat variables for this boss
      hasShield = (characterClass == CharacterClass.warrior);
      mageSpellCharge = 0;
      notifyListeners();
    }
  }

  void drinkHealthPotion() {
    if (playerHp < maxPlayerHp) {
      playerHp = maxPlayerHp;
      floatingDamages.add(
        FloatingDamage(
          "+10 HP (HEALED!)",
          color: Colors.greenAccent,
          offsetLeft: (math.Random().nextDouble() * 60) - 30,
          id: _nextDamageId++,
        ),
      );
      final currentId = _nextDamageId - 1;
      Future.delayed(const Duration(milliseconds: 800), () {
        floatingDamages.removeWhere((d) => d.id == currentId);
        notifyListeners();
      });
      notifyListeners();
    }
  }

  void reviveAndRetry() {
    playerHp = maxPlayerHp;
    isDefeated = false;
    showRedFlash = false;
    enemyCurrentHp = currentBoss.maxHp;
    hasShield = (characterClass == CharacterClass.warrior);
    mageSpellCharge = 0;
    setRepsCount = 0;
    currentState = PushUpState.up;
    feedback = "LOWER BODY";
    notifyListeners();
  }

  void _addExp(int amount) {
    playerExp += amount;
    while (playerExp >= expNeededForNextLevel) {
      playerExp -= expNeededForNextLevel;
      playerLevel++;
      showLevelUpOverlay = true;
    }
  }

  void dismissLevelUp() {
    showLevelUpOverlay = false;
    notifyListeners();
  }

  void _damageEnemy(int amount, {String? customText, Color? customColor}) {
    if (enemyCurrentHp <= 0) return;

    if (amount > 0) {
      enemyCurrentHp -= amount;
      shouldShake = true;
      String damageText = amount == 2 ? "CRITICAL! -2 HP" : "-$amount HP";
      if (customText != null) damageText = customText;
      Color damageColor = amount == 2 ? Colors.amber : Colors.redAccent;
      if (customColor != null) damageColor = customColor;

      floatingDamages.add(
        FloatingDamage(
          damageText,
          color: damageColor,
          offsetLeft: (math.Random().nextDouble() * 60) - 30,
          id: _nextDamageId++,
        ),
      );
      final currentId = _nextDamageId - 1;
      Future.delayed(const Duration(milliseconds: 800), () {
        floatingDamages.removeWhere((d) => d.id == currentId);
        notifyListeners();
      });
      Future.delayed(const Duration(milliseconds: 250), () {
        shouldShake = false;
        notifyListeners();
      });
    } else {
      floatingDamages.add(
        FloatingDamage(
          "BLOCKED!",
          color: Colors.grey,
          offsetLeft: (math.Random().nextDouble() * 60) - 30,
          id: _nextDamageId++,
        ),
      );
      final currentId = _nextDamageId - 1;
      Future.delayed(const Duration(milliseconds: 800), () {
        floatingDamages.removeWhere((d) => d.id == currentId);
        notifyListeners();
      });
    }

    if (enemyCurrentHp <= 0) {
      enemyCurrentHp = 0;
      _addExp(currentBoss.expReward);
      feedback = "VICTORY!";
      
      // Advance stage unlock
      if (currentBossIndex == highestBossUnlocked && highestBossUnlocked < bosses.length - 1) {
        highestBossUnlocked++;
      }
    }
    notifyListeners();
  }

  void _triggerBossCounterAttack() {
    if (isDefeated) return;

    if (characterClass == CharacterClass.warrior && hasShield) {
      hasShield = false;
      floatingDamages.add(
        FloatingDamage(
          "SHIELD BLOCK!",
          color: Colors.lightBlueAccent,
          offsetLeft: (math.Random().nextDouble() * 60) - 30,
          id: _nextDamageId++,
        ),
      );
      final currentId = _nextDamageId - 1;
      Future.delayed(const Duration(milliseconds: 800), () {
        floatingDamages.removeWhere((d) => d.id == currentId);
        notifyListeners();
      });
    } else {
      playerHp -= 1;
      showRedFlash = true;
      floatingDamages.add(
        FloatingDamage(
          "-1 Player HP",
          color: Colors.red,
          offsetLeft: (math.Random().nextDouble() * 60) - 30,
          id: _nextDamageId++,
        ),
      );
      final currentId = _nextDamageId - 1;
      Future.delayed(const Duration(milliseconds: 800), () {
        floatingDamages.removeWhere((d) => d.id == currentId);
        notifyListeners();
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        showRedFlash = false;
        notifyListeners();
      });

      if (playerHp <= 0) {
        playerHp = 0;
        isDefeated = true;
        feedback = "DEFEATED!";
      }
    }
    notifyListeners();
  }

  void _onRepCompleted(int damageAmount) {
    if (damageAmount == 0) {
      _triggerBossCounterAttack();
      return;
    }

    repCount++;
    setRepsCount++;

    var finalDamage = damageAmount;
    String? customText;
    Color? customColor;

    if (characterClass == CharacterClass.rogue && damageAmount == 2) {
      finalDamage = 3;
      customText = "SNEAK ATTACK! -3 HP";
      customColor = Colors.orangeAccent;
    }

    _damageEnemy(finalDamage, customText: customText, customColor: customColor);

    if (characterClass == CharacterClass.mage) {
      mageSpellCharge++;
      if (mageSpellCharge >= 3) {
        mageSpellCharge = 0;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (enemyCurrentHp > 0) {
            _damageEnemy(2, customText: "FIREBALL! -2 HP", customColor: Colors.purpleAccent);
          }
        });
      }
    }

    if (setRepsCount >= targetReps[currentSetIndex]) {
      if (currentSetIndex < targetReps.length - 1) {
        isResting = true;
        restSecondsRemaining = 20;
        _restTimer?.cancel();
        _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (restSecondsRemaining > 1) {
            restSecondsRemaining--;
            notifyListeners();
          } else {
            timer.cancel();
            isResting = false;
            currentSetIndex++;
            setRepsCount = 0;
            feedback = "LOWER BODY";
            notifyListeners();
          }
        });
      } else {
        isWorkoutComplete = true;
        feedback = "WORKOUT COMPLETE!";
      }
    }
  }

  void processPose(DetectedPose pose) {
    if (isVictory || isWorkoutComplete || isResting || isDefeated) return;
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
        currentState = PushUpState.up;
        _onRepCompleted(isBackStraight ? 2 : 0);
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
        currentState = PushUpState.up;
        _onRepCompleted(1);
        feedback = "LOWER BODY";
      }
    } else {
      _downConfirmCount = 0;
      _upConfirmCount = 0;
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
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