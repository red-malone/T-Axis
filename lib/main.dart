import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:t_axis/firebase_options.dart';
import 'package:t_axis/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //Add firebase initialization before runApp to ensure it's ready when the app starts.
  // This is required for any Firebase services to work properly.
  //to get firebase options, run `flutterfire configure` in the terminal and follow the prompts.
  // The `firebase_options.dart` file will be generated in the `lib` directory, and it contains the necessary configuration for Firebase initialization.
  //Just follow the instruction in the firbase console to set up the project. Choose flutter and it will guide you through the process.
  // Make sure to select the correct platforms (iOS, Android, Web) that you intend to support. After running the command, the `firebase_options.dart` file will be created with the appropriate configuration for your Firebase project.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Lock orientation to portraitUp for consistent sensor readings
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'T-Axis Telemetry',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(),
    );
  }
}
