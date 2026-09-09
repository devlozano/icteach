import 'widgets/persistent_workspace.dart';
// home_router.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import 'teacher_home.dart';
import 'trainer_home.dart';
import 'admin_home.dart';
import 'login.dart';
import 'admin_login.dart';
import 'register.dart';
import 'services/navigation_service.dart';
import 'services/workspace_navigation.dart';
import 'services/workspace_preferences.dart';

class HomeRouter extends StatefulWidget {
  const HomeRouter({super.key});

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  bool _restoreQueued = false;
  late final _profile = FirebaseAuth.instance.currentUser == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return kIsWeb ? const AdminLoginPage() : const LoginPage();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Complete registration')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your sign-in exists, but student registration is incomplete. '
                      'Use the same email and password, your LRN and a valid school code to finish.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child: const Text('Complete LRN registration'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        PersistentWorkspace.clear();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final role = data['role']?.toString().toLowerCase() ?? 'student';
        if (kIsWeb && !const {'admin', 'teacher', 'trainer'}.contains(role)) {
          return const _WebAccessBlocked();
        }

        WorkspacePreferences.owner = user.uid;
        if (!_restoreQueued) {
          _restoreQueued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              WorkspaceNavigation.instance.restore(context, user.uid, role);
          });
        }
        // One root navigator; child pages pop before dashboard back handling.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await NavigationService.onWillPop(context);
          },
          child: _buildHomePage(role),
        );
      },
    );
  }

  Widget _buildHomePage(String role) {
    switch (role) {
      case 'admin':
        return const AdminHomePage();
      case 'teacher':
        return const TeacherHomePage();
      case 'trainer':
        return const TrainerHomePage();
      default:
        return const HomePage();
    }
  }
}

class _WebAccessBlocked extends StatefulWidget {
  const _WebAccessBlocked();

  @override
  State<_WebAccessBlocked> createState() => _WebAccessBlockedState();
}

class _WebAccessBlockedState extends State<_WebAccessBlocked> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _returnToWebLogin());
  }

  Future<void> _returnToWebLogin() async {
    await FirebaseAuth.instance.signOut();
    PersistentWorkspace.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Returning to ICTeach sign-in...'),
          ],
        ),
      ),
    );
  }
}
