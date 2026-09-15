import 'package:flutter/material.dart';
import 'manage_lrn_page.dart';
import 'manage_teachers_page.dart';
import 'manage_trainers_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _DashboardOverview(),
    const ManageTeachersPage(),
    const ManageTrainersPage(),
    const ManageLRNPage(),
    const _SystemSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Side Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Teachers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_user),
                label: Text('Trainers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.numbers),
                label: Text('LRN Registration'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Page Content
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard Overview'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Welcome to Admin Dashboard')),
    );
  }
}

class _SystemSettingsPage extends StatelessWidget {
  const _SystemSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('System Settings')),
    );
  }
}
