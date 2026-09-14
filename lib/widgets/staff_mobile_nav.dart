import 'package:flutter/material.dart';

/// App navigation with secondary destinations in a scrollable menu.
class StaffMobileNav extends StatelessWidget {
  const StaffMobileNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    this.trainer = false,
  });
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool trainer;

  @override
  Widget build(BuildContext context) {
    final items = trainer
        ? const [
            (Icons.home_rounded, 'Home'),
            (Icons.forum_rounded, 'Discussions'),
            (Icons.person_rounded, 'Profile'),
            (Icons.insights_outlined, 'Class Monitoring'),
            (Icons.rate_review_outlined, 'Feedback'),
            (Icons.groups_outlined, 'Students'),
            (Icons.menu_book_outlined, 'Modules'),
          ]
        : const [
            (Icons.home_rounded, 'Home'),
            (Icons.class_rounded, 'Classes'),
            (Icons.forum_rounded, 'Discussions'),
            (Icons.insights_outlined, 'Class Monitoring'),
            (Icons.person_rounded, 'Profile'),
            (Icons.rate_review_outlined, 'Feedback'),
            (Icons.groups_outlined, 'Students'),
            (Icons.menu_book_outlined, 'Modules'),
          ];
    final primary = trainer ? [0, 6, 5] : [0, 1, 7];
    final selected = primary.indexOf(currentIndex);
    return NavigationBar(
      selectedIndex: selected < 0 ? 3 : selected,
      onDestinationSelected: (index) async {
        if (index < 3) {
          onChanged(primary[index]);
          return;
        }
        final destination = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          builder: (context) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  if (!primary.contains(i))
                    ListTile(
                      leading: Icon(items[i].$1),
                      title: Text(items[i].$2),
                      selected: currentIndex == i,
                      trailing: currentIndex == i
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, i),
                    ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
        if (destination != null && context.mounted) onChanged(destination);
      },
      destinations: [
        for (final i in primary)
          NavigationDestination(icon: Icon(items[i].$1), label: items[i].$2),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}
