import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'services/sync_service.dart';
void main() async{
  // 1. Ensure Flutter is ready to talk to native code (Android/iOS)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase using the settings for the current platform
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    'sync-task',
    'syncUnsyncedRecords',
    frequency: Duration(minutes: 15), // at least 15 mins
  );
  runApp(const MainApp());
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'syncUnsyncedRecords':
        await SyncService().syncUnsyncedRecords();
        break;
    }
    return Future.value(true);
  });
}
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafariPass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1A237E),
        scaffoldBackgroundColor: Colors.grey[50],
    ),
      home: const SplashScreen(),
    );
  }
}
