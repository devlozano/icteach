import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Official ICTeach Platform Screen Imports
import 'splash.dart';
import 'home_router.dart';
import 'admin_login.dart';
import 'login.dart';
import 'widgets/offline_indicator.dart';
import 'services/navigation_service.dart';
import 'utils/app_theme.dart';
import 'services/session_service.dart';
import 'services/workspace_preferences.dart';
import 'services/workspace_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WorkspacePreferences.initialize();

  try {
    await _initializeFirebase();
    await SessionService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDCnNrIz2g2Ovq5XnocJVBVl5S065vOB2g",
        authDomain: "icteach-free.firebaseapp.com",
        projectId: "icteach-free",
        storageBucket: "icteach-free.firebasestorage.app",
        messagingSenderId: "4824580226",
        appId: "1:4824580226:web:e28624a19f13361241f49b",
        measurementId: "G-S77WYVMF0N",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICTeach Learning Portal',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      navigatorObservers: [WorkspaceNavigation.instance],
      builder: (context, child) => OfflineIndicator(child: child!),
      theme: AppTheme.light,
      home: const _AppEntry(),
      routes: {
        '/home': (context) => const HomeRouter(),
        '/login': (context) => const LoginPage(),
        '/web-login': (context) => const AdminLoginPage(),
        '/admin-login': (context) => const AdminLoginPage(),
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _finished = false;
  @override
  Widget build(BuildContext context) {
    if (!_finished)
      return SplashPage(
        onFinished: () {
          if (mounted) setState(() => _finished = true);
        },
      );
    return const HomeRouter();
  }
}
