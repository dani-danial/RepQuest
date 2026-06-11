import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'camera_view_screen.dart';
import 'pushup_counter_controller.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Failed to list cameras at startup: $e');
    cameras = [];
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PushupCounterController()),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Push-Up Tracker',
        home: AppEntry(),
      ),
    ),
  );
}

class AppEntry extends StatelessWidget {
  const AppEntry({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CameraViewScreen(cameras: cameras);
  }
}
