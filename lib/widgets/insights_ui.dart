import 'package:flutter/material.dart';

const insightsNavy = Color(0xFF102E4A);
const insightsTeal = Color(0xFF087F8C);
const insightsMuted = Color(0xFF526579);
const insightsBorder = Color(0xFFE0E8EF);

class InsightsFieldPair extends StatelessWidget {
  const InsightsFieldPair({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 360 &&
          MediaQuery.textScalerOf(context).scale(14) > 18;
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: stack
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2,
              child: child,
            ),
        ],
      );
    },
  );
}

/// Shared spacing for the teacher's insights and grading workspace.
class InsightsList extends StatelessWidget {
  const InsightsList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > 1160
        ? (width - 1120) / 2
        : width < 600
        ? 16.0
        : 24.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(inset, 24, inset, 40),
      children: children,
    );
  }
}

class InsightsHeader extends StatelessWidget {
  const InsightsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.eyebrow,
  });
  final String title, subtitle;
  final String? eyebrow;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F1F2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: insightsTeal, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!,
                  style: const TextStyle(
                    color: insightsTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: insightsNavy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: insightsMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class InsightsPanel extends StatelessWidget {
  const InsightsPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: insightsBorder),
    ),
    child: child,
  );
}

class InsightsPill extends StatelessWidget {
  const InsightsPill(this.text, {super.key, this.color = insightsTeal});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class InsightsStats extends StatelessWidget {
  const InsightsStats({super.key, required this.items});
  final List<({String label, String value, IconData icon})> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final columns = constraints.maxWidth < 280 || largeText
          ? 1
          : constraints.maxWidth < 850
          ? 2
          : items.length;
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: insightsBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, color: insightsTeal, size: 22),
                      const SizedBox(height: 14),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: insightsNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: insightsMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class InsightsEmpty extends StatelessWidget {
  const InsightsEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => InsightsPanel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFEAF2F7),
            child: Icon(icon, color: insightsMuted, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: insightsNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: insightsMuted, height: 1.5),
          ),
        ],
      ),
    ),
  );
}
