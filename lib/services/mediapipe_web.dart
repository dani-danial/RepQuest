import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('repquestPoseBridge')
extension type RepquestPoseBridge._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external JSPromise<JSAny?> attachVideoElement(web.HTMLVideoElement video);
  external JSAny? detectVideoFrame();
  external void stopVideo();
}

@JS('repquestPoseBridge')
external RepquestPoseBridge get repquestPoseBridge;

Future<void> ensureMediaPipeInitialized() async {
  await repquestPoseBridge.init().toDart;
}

Future<void> attachCameraVideo(web.HTMLVideoElement video) async {
  await repquestPoseBridge.attachVideoElement(video).toDart;
}

Future<List<Map<String, double>>?> detectVideoFrame() async {
  final result = repquestPoseBridge.detectVideoFrame();
  return _parseLandmarks(result);
}

void stopCameraVideo() {
  repquestPoseBridge.stopVideo();
}

List<Map<String, double>>? _parseLandmarks(JSAny? result) {
  final dartResult = result?.dartify();
  if (dartResult == null) {
    return null;
  }
  if (dartResult is! List) {
    return null;
  }

  final landmarks = <Map<String, double>>[];
  for (final item in dartResult) {
    if (item is! Map) continue;
    landmarks.add({
      'x': (item['x'] as num).toDouble(),
      'y': (item['y'] as num).toDouble(),
      'visibility': (item['visibility'] as num?)?.toDouble() ?? 1.0,
    });
  }

  return landmarks;
}
