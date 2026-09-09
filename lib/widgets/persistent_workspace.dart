import 'package:flutter/material.dart';
import '../services/workspace_navigation.dart';

/// Keeps the staff navigation beside the root navigator on detail pages.
class PersistentWorkspace extends StatelessWidget {
  final Widget child;
  const PersistentWorkspace({super.key, required this.child});
  static final revision = ValueNotifier<int>(0);
  static void clear() {
    navigation = null;
    homeRoute = null;
    revision.value++;
  }

  static Widget? navigation;
  static Route<dynamic>? homeRoute;
  static void register(BuildContext context, Widget sidebar) {
    navigation = sidebar;
    homeRoute = ModalRoute.of(context);
  }

  static void returnHome(BuildContext context, VoidCallback select) {
    Navigator.of(
      context,
    ).popUntil((route) => route == homeRoute || route.isFirst);
    select();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: revision,
    builder: (context, _, _) => ValueListenableBuilder<Route<dynamic>?>(
      valueListenable: WorkspaceNavigation.instance.topPage,
      builder: (context, topPage, _) {
        if (topPage == null ||
            topPage == homeRoute ||
            homeRoute?.isActive != true ||
            navigation == null ||
            MediaQuery.sizeOf(context).width < 1000) {
          return child;
        }
        return Row(
          children: [
            navigation!,
            Expanded(child: child),
          ],
        );
      },
    ),
  );
}
