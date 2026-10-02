import 'package:flutter/material.dart';

/// Five thumb-friendly staff destinations, with the task-specific tools grouped
/// in More instead of competing with the daily workflow in the bottom bar.
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
            (Icons.home_outlined, Icons.home_rounded, 'Home'),
            (Icons.forum_outlined, Icons.forum_rounded, 'Discussions'),
            (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
            (
              Icons.insights_outlined,
              Icons.insights_rounded,
              'Class Monitoring',
            ),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, 'Feedback'),
            (Icons.groups_outlined, Icons.groups_rounded, 'Students'),
            (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Modules'),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, 'Home'),
            (Icons.school_outlined, Icons.school_rounded, 'Classes'),
            (Icons.forum_outlined, Icons.forum_rounded, 'Discussions'),
            (
              Icons.insights_outlined,
              Icons.insights_rounded,
              'Class Monitoring',
            ),
            (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, 'Feedback'),
            (Icons.groups_outlined, Icons.groups_rounded, 'Students'),
            (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Modules'),
            (
              Icons.fact_check_outlined,
              Icons.fact_check_rounded,
              'Quiz & Assessment',
            ),
          ];
    // Keep discussion in the centre: it is a shared, high-frequency workspace
    // for both roles. Profile remains one tap away; management tools are in
    // More, where they can be labelled clearly without a cramped tab bar.
    final primary = trainer ? [0, 6, 1, 2] : [0, 1, 2, 4];
    final moreOrder = trainer ? [3, 5, 4] : [7, 8, 3, 6, 5];
    final selected = primary.indexOf(currentIndex);
    return NavigationBar(
      selectedIndex: selected < 0 ? 4 : selected,
      onDestinationSelected: (index) async {
        if (index < primary.length) {
          onChanged(primary[index]);
          return;
        }
        final destination = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SingleChildScrollView(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0B2B4A), Color(0xFF2563A9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .18),
                            ),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'More tools',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                trainer
                                    ? 'Monitoring and learner management'
                                    : 'Teaching, assessment, and class tools',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Text(
                      'WORKSPACE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      childAspectRatio: 1.55,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (
                          var position = 0;
                          position < moreOrder.length;
                          position++
                        )
                          _MoreToolTile(
                            icon: items[moreOrder[position]].$2,
                            label: items[moreOrder[position]].$3,
                            selected: currentIndex == moreOrder[position],
                            accent: _toolColors[position % _toolColors.length],
                            onTap: () =>
                                Navigator.pop(context, moreOrder[position]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (destination != null && context.mounted) onChanged(destination);
      },
      destinations: [
        for (final i in primary)
          NavigationDestination(
            icon: _StaffNavIcon(icon: items[i].$1),
            selectedIcon: _StaffNavIcon(icon: items[i].$2, selected: true),
            label: items[i].$3,
          ),
        const NavigationDestination(
          icon: _StaffNavIcon(icon: Icons.grid_view_outlined),
          selectedIcon: _StaffNavIcon(
            icon: Icons.grid_view_rounded,
            selected: true,
          ),
          label: 'More',
        ),
      ],
    );
  }
}

const _toolColors = [
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFF059669),
  Color(0xFFEA580C),
  Color(0xFFDB2777),
];

class _StaffNavIcon extends StatelessWidget {
  const _StaffNavIcon({required this.icon, this.selected = false});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: EdgeInsets.all(selected ? 7 : 4),
    decoration: BoxDecoration(
      gradient: selected
          ? const LinearGradient(colors: [Color(0xFF2F80ED), Color(0xFF1A5FA8)])
          : null,
      borderRadius: BorderRadius.circular(12),
      boxShadow: selected
          ? [
              BoxShadow(
                color: const Color(0xFF2F80ED).withValues(alpha: .24),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    ),
    child: Icon(
      icon,
      color: selected ? Colors.white : null,
      size: selected ? 22 : 24,
    ),
  );
}

class _MoreToolTile extends StatelessWidget {
  const _MoreToolTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: .14) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? accent : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
      ),
      elevation: selected ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? accent : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
