import 'dart:math' as math;
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
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              if (controller.showRedFlash) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                      width: 10,
                    ),
                    color: Colors.red.withValues(alpha: 0.15),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              if (controller.isDefeated) {
                return const _DefeatOverlay();
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              if (controller.isVictory) {
                return const _VictoryOverlay();
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              if (controller.isResting) {
                return const _CampfireRestOverlay();
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              if (controller.isWorkoutComplete) {
                return const _WorkoutCompleteOverlay();
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer<PushupCounterController>(
            builder: (context, controller, child) {
              if (controller.showLevelUpOverlay) {
                return const _LevelUpOverlay();
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  const _VictoryOverlay();

  @override
  Widget build(BuildContext context) {
    return Consumer<PushupCounterController>(
      builder: (context, controller, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amberAccent, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      controller.currentBoss.imagePath,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.6),
                      colorBlendMode: BlendMode.darken,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'VICTORY!',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 40,
                    fontFamily: 'Comic Sans MS',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You defeated the ${controller.currentBoss.name}!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  '+${controller.currentBoss.expReward} EXP REWARDED',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.resetBattle();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.white24, width: 1.5),
                        ),
                      ),
                      child: const Text(
                        'RESET GAME',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: () {
                        controller.nextBoss();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'NEXT STAGE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CampfireRestOverlay extends StatelessWidget {
  const _CampfireRestOverlay();

  @override
  Widget build(BuildContext context) {
    return Consumer<PushupCounterController>(
      builder: (context, controller, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🔥',
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CAMPFIRE REST',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 32,
                    fontFamily: 'Comic Sans MS',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Resting by the fire to recover stamina. Prep for the next set!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: controller.playerHp < PushupCounterController.maxPlayerHp
                      ? () {
                          controller.drinkHealthPotion();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: controller.playerHp < PushupCounterController.maxPlayerHp
                            ? Colors.greenAccent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  icon: const Text('🧪', style: TextStyle(fontSize: 16)),
                  label: Text(
                    controller.playerHp < PushupCounterController.maxPlayerHp
                        ? 'DRINK HEALTH POTION'
                        : 'HP IS FULL',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 30),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: controller.restSecondsRemaining / 20,
                        strokeWidth: 8,
                        color: Colors.orangeAccent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    Text(
                      '${controller.restSecondsRemaining}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 45),
                Text(
                  'NEXT UP: SET ${controller.currentSetIndex + 2} (${PushupCounterController.targetReps[controller.currentSetIndex + 1]} REPS)',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkoutCompleteOverlay extends StatelessWidget {
  const _WorkoutCompleteOverlay();

  @override
  Widget build(BuildContext context) {
    return Consumer<PushupCounterController>(
      builder: (context, controller, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.95),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🏆',
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 20),
                const Text(
                  'WORKOUT COMPLETE!',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 36,
                    fontFamily: 'Comic Sans MS',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You completed all sets successfully!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    controller.resetBattle();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'RESTART SESSION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LevelUpOverlay extends StatelessWidget {
  const _LevelUpOverlay();

  @override
  Widget build(BuildContext context) {
    return Consumer<PushupCounterController>(
      builder: (context, controller, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '⭐',
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 20),
                const Text(
                  'LEVEL UP!',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 40,
                    fontFamily: 'Comic Sans MS',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You reached Level ${controller.playerLevel}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    controller.dismissLevelUp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'AWESOME',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerStatsHeader extends StatelessWidget {
  const _PlayerStatsHeader();

  Color _getClassColor(CharacterClass charClass) {
    switch (charClass) {
      case CharacterClass.warrior:
        return Colors.amberAccent;
      case CharacterClass.rogue:
        return Colors.greenAccent;
      case CharacterClass.mage:
        return Colors.purpleAccent;
    }
  }

  String _getClassEmoji(CharacterClass charClass) {
    switch (charClass) {
      case CharacterClass.warrior:
        return '🛡️';
      case CharacterClass.rogue:
        return '🗡️';
      case CharacterClass.mage:
        return '🔮';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PushupCounterController>(
      builder: (context, controller, child) {
        final expPercent = controller.playerExp / controller.expNeededForNextLevel;
        final hpPercent = controller.playerHp / PushupCounterController.maxPlayerHp;
        final classColor = _getClassColor(controller.characterClass);
        final classEmoji = _getClassEmoji(controller.characterClass);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const _ClassSelectionDialog(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: classColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: classColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            classEmoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            controller.characterClass.name.toUpperCase(),
                            style: TextStyle(
                              color: classColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      'LVL ${controller.playerLevel}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'EXP PROGRESS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${controller.playerExp}/${controller.expNeededForNextLevel}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: expPercent.clamp(0.0, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.blueAccent, Colors.cyanAccent],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white12, width: 1),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: hpPercent.clamp(0.0, 1.0),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.redAccent, Colors.red],
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'HP: ${controller.playerHp} / ${PushupCounterController.maxPlayerHp}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.characterClass == CharacterClass.warrior && controller.hasShield) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.shield,
                      color: Colors.lightBlueAccent,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SetsPanel extends StatelessWidget {
  const _SetsPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<PushupCounterController>(
      builder: (context, controller, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ROUTINE SETS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(PushupCounterController.targetReps.length, (index) {
                final target = PushupCounterController.targetReps[index];
                final isCurrent = controller.currentSetIndex == index;
                final isCompleted = controller.currentSetIndex > index;
                
                Color textColor = Colors.white54;
                FontWeight fontWeight = FontWeight.normal;
                IconData icon = Icons.circle_outlined;
                Color iconColor = Colors.white24;

                if (isCurrent) {
                  textColor = Colors.amberAccent;
                  fontWeight = FontWeight.w900;
                  icon = Icons.play_arrow_rounded;
                  iconColor = Colors.amberAccent;
                } else if (isCompleted) {
                  textColor = Colors.greenAccent;
                  icon = Icons.check_circle_rounded;
                  iconColor = Colors.greenAccent;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        'Set ${index + 1}: ',
                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: fontWeight),
                      ),
                      Text(
                        isCurrent
                            ? '${controller.setRepsCount} / $target'
                            : '$target reps',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: fontWeight,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
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
          final hpPercent = controller.enemyCurrentHp / controller.currentBoss.maxHp;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const _PlayerStatsHeader(),
              const SizedBox(height: 10),
              
              // RPG Boss Header Panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.8), width: 2),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 50),
                            transform: controller.shouldShake
                                ? (Matrix4.translationValues(
                                    (math.Random().nextDouble() * 8) - 4,
                                    (math.Random().nextDouble() * 8) - 4,
                                    0,
                                  ))
                                : Matrix4.identity(),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.amberAccent, width: 2),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                controller.currentBoss.imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey,
                                    child: const Icon(Icons.person, color: Colors.white),
                                  );
                                },
                              ),
                            ),
                          ),
                          ...controller.floatingDamages.map((damage) {
                            return Positioned(
                              top: -20,
                              left: damage.offsetLeft,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 600),
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: 1.0 - value,
                                    child: Transform.translate(
                                      offset: Offset(0, -value * 40),
                                      child: Text(
                                        damage.text,
                                        style: TextStyle(
                                          color: damage.color,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 3,
                                              color: Colors.black,
                                              offset: Offset(1.5, 1.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  controller.currentBoss.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.map_outlined,
                                    color: Colors.amberAccent,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => const _StageSelectorDialog(),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black, width: 1),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: hpPercent,
                                    child: Container(
                                      height: 20,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Colors.redAccent, Colors.red],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${controller.enemyCurrentHp} / ${controller.currentBoss.maxHp} HP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
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
                      fontFamily: 'Comic Sans MS',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(
                      width: 150,
                      child: _SetsPanel(),
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          painter: _DoodlyCirclePainter(),
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: Center(
                              child: Text(
                                '${controller.setRepsCount}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 48,
                                  fontFamily: 'Comic Sans MS',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
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

class _DefeatOverlay extends StatelessWidget {
  const _DefeatOverlay();

  @override
  Widget build(BuildContext context) {
    return Consumer<PushupCounterController>(
      builder: (context, controller, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '💀',
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 20),
                const Text(
                  'DEFEATED!',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 40,
                    fontFamily: 'Comic Sans MS',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The ${controller.currentBoss.name} overpowered you!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Your posture collapsed. Maintain a straight back to block incoming attacks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    controller.reviveAndRetry();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'REVIVE & RETRY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClassSelectionDialog extends StatelessWidget {
  const _ClassSelectionDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.amberAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CHOOSE YOUR CLASS',
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 22,
                fontFamily: 'Comic Sans MS',
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildClassCard(
              context,
              CharacterClass.warrior,
              '🛡️ WARRIOR',
              'Tough & Steadfast',
              'Starts each fight with a shield. Blocks the first boss counter-attack.',
              Colors.amberAccent,
            ),
            const SizedBox(height: 10),
            _buildClassCard(
              context,
              CharacterClass.rogue,
              '🗡️ ROGUE',
              'Critical Strike Specialist',
              'Perfect posture deals 3x damage (3 HP) instead of 2.',
              Colors.greenAccent,
            ),
            const SizedBox(height: 10),
            _buildClassCard(
              context,
              CharacterClass.mage,
              '🔮 MAGE',
              'Arcane Spellcaster',
              'Every 3 successful push-ups casts Fireball for +2 bonus damage.',
              Colors.purpleAccent,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CLOSE',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(
    BuildContext context,
    CharacterClass charClass,
    String name,
    String subtitle,
    String perk,
    Color themeColor,
  ) {
    final controller = Provider.of<PushupCounterController>(context, listen: false);
    final isSelected = controller.characterClass == charClass;

    return InkWell(
      onTap: () {
        controller.selectClass(charClass);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withValues(alpha: 0.15) : Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? themeColor : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    perk,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: themeColor, size: 20)
            else
              const Icon(Icons.circle_outlined, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StageSelectorDialog extends StatelessWidget {
  const _StageSelectorDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.amberAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'QUEST MAP',
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 22,
                fontFamily: 'Comic Sans MS',
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: Consumer<PushupCounterController>(
                builder: (context, controller, child) {
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: PushupCounterController.bosses.length,
                    separatorBuilder: (context, index) => const Icon(
                      Icons.arrow_downward,
                      color: Colors.amberAccent,
                      size: 18,
                    ),
                    itemBuilder: (context, index) {
                      final boss = PushupCounterController.bosses[index];
                      final isUnlocked = index <= controller.highestBossUnlocked;
                      final isCurrent = index == controller.currentBossIndex;

                      return InkWell(
                        onTap: isUnlocked
                            ? () {
                                controller.selectBoss(index);
                                Navigator.of(context).pop();
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.amberAccent.withValues(alpha: 0.15)
                                : (isUnlocked ? Colors.black38 : Colors.black87),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? Colors.amberAccent
                                  : (isUnlocked ? Colors.white24 : Colors.transparent),
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isUnlocked ? Colors.amberAccent : Colors.grey,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Opacity(
                                    opacity: isUnlocked ? 1.0 : 0.4,
                                    child: Image.asset(
                                      boss.imagePath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.lock, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'STAGE ${index + 1}: ${boss.name}',
                                      style: TextStyle(
                                        color: isUnlocked ? Colors.white : Colors.white38,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isUnlocked
                                          ? '${boss.maxHp} HP • ${boss.expReward} EXP REWARD'
                                          : 'LOCKED (Defeat previous bosses)',
                                      style: TextStyle(
                                        color: isUnlocked ? Colors.white70 : Colors.white30,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isUnlocked)
                                const Icon(Icons.lock, color: Colors.white30)
                              else if (isCurrent)
                                const Icon(Icons.play_circle_fill, color: Colors.amberAccent)
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CLOSE',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}