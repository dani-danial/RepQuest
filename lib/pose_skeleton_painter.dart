import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Representation of a single normalized landmark from MediaPipe.
/// Coordinates (x, y) are typically between 0.0 and 1.0.
class PoseLandmark {
  final double x;
  final double y;

  const PoseLandmark({required this.x, required this.y});
}

class PoseSkeletonPainter extends CustomPainter {
  final Map<int, PoseLandmark> landmarks;
  final bool isFrontCamera;
  final math.Random _random = math.Random(42); // Fixed seed to prevent wild flickering

  PoseSkeletonPainter({
    required this.landmarks,
    this.isFrontCamera = false,
  });

  // Helper to draw a "sketchy" line
  void _drawDoodlyLine(Canvas canvas, Offset start, Offset end, Paint basePaint) {
    // Draw main thick line
    canvas.drawLine(start, end, basePaint);

    // Draw a thinner, slightly messy overlay line
    final sketchPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    
    // Add a slight bowing/curve effect using a quadratic bezier
    final midPoint = Offset(
      start.dx + dx / 2 + (_random.nextDouble() * 10 - 5),
      start.dy + dy / 2 + (_random.nextDouble() * 10 - 5),
    );

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(midPoint.dx, midPoint.dy, end.dx, end.dy);
      
    canvas.drawPath(path, sketchPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFFFA500) // Comic orange
      ..style = PaintingStyle.fill;
    final dotOutlinePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Offset? getScaledOffset(int index) {
      final landmark = landmarks[index];
      if (landmark == null) return null;
      double x = isFrontCamera ? (1.0 - landmark.x) : landmark.x;
      return Offset(x * size.width, landmark.y * size.height);
    }

    final connections = [
      _Connection(11, 13), _Connection(13, 15), // Left Arm
      _Connection(12, 14), _Connection(14, 16), // Right Arm
      _Connection(11, 12), // Shoulders
      _Connection(11, 23), _Connection(12, 24), _Connection(23, 24), // Torso
      _Connection(23, 25), _Connection(24, 26), // Legs
    ];

    for (final connection in connections) {
      final start = getScaledOffset(connection.from);
      final end = getScaledOffset(connection.to);
      if (start != null && end != null) {
        _drawDoodlyLine(canvas, start, end, linePaint);
      }
    }

    final jointsToDraw = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26];
    for (final index in jointsToDraw) {
      final point = getScaledOffset(index);
      if (point != null) {
        // Draw sketchy joint circles
        canvas.drawCircle(point, 8.0, dotPaint);
        canvas.drawCircle(
            point + Offset(_random.nextDouble() * 2 - 1, _random.nextDouble() * 2 - 1), 
            8.0, 
            dotOutlinePaint
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PoseSkeletonPainter oldDelegate) {
    if (oldDelegate.isFrontCamera != isFrontCamera) return true;
    if (oldDelegate.landmarks.length != landmarks.length) return true;

    for (final entry in landmarks.entries) {
      final previous = oldDelegate.landmarks[entry.key];
      if (previous == null) return true;
      if ((previous.x - entry.value.x).abs() > 0.001 ||
          (previous.y - entry.value.y).abs() > 0.001) {
        return true;
      }
    }
    return false;
  }
}

/// Helper structure to represent a connection between two joint indices.
class _Connection {
  final int from;
  final int to;

  const _Connection(this.from, this.to);
}