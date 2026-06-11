import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/detected_pose.dart';

class PoseDetectorService {
  late final PoseDetector _poseDetector;

  PoseDetectorService() {
    final options = PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<DetectedPose?> processCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return null;

    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isEmpty) return null;

    final pose = poses.first;
    final isPortrait =
        camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
    final imageSize = Size(
      isPortrait ? image.height.toDouble() : image.width.toDouble(),
      isPortrait ? image.width.toDouble() : image.height.toDouble(),
    );

    return _toDetectedPose(pose, imageSize);
  }

  DetectedPose _toDetectedPose(Pose pose, Size imageSize) {
    final landmarks = <int, DetectedLandmark>{};
    pose.landmarks.forEach((type, landmark) {
      landmarks[type.index] = DetectedLandmark(
        x: landmark.x / imageSize.width,
        y: landmark.y / imageSize.height,
        visibility: landmark.likelihood,
      );
    });
    return DetectedPose(landmarks: landmarks);
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final sensorOrientation = camera.sensorOrientation;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid &&
            format != InputImageFormat.nv21 &&
            format != InputImageFormat.yuv_420_888 &&
            format != InputImageFormat.yuv420) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void dispose() {
    _poseDetector.close();
  }
}
