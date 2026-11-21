import 'package:flutter/material.dart';

enum LearningFlowStage { module, quiz, simulation }

class LearningFlowIndicator extends StatelessWidget {
  const LearningFlowIndicator({
    super.key,
    required this.current,
    this.compact = false,
  });

  final LearningFlowStage current;
  final bool compact;

  static const _labels = ['Module', 'Quiz', 'Simulation'];
  static const _icons = [
    Icons.menu_book_rounded,
    Icons.quiz_rounded,
    Icons.build_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = current.index;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Learning flow: Module, Quiz, Simulation. Current step: ${_labels[activeIndex]}',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            for (var index = 0; index < _labels.length; index++) ...[
              Expanded(
                child: _Step(
                  label: _labels[index],
                  icon: _icons[index],
                  completed: index < activeIndex,
                  active: index == activeIndex,
                  compact: compact,
                ),
              ),
              if (index < _labels.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index < activeIndex
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.icon,
    required this.completed,
    required this.active,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final bool completed;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = completed || active;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: compact ? 30 : 36,
          height: compact ? 30 : 36,
          decoration: BoxDecoration(
            color: highlighted ? scheme.primary : scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: highlighted ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Icon(
            completed ? Icons.check_rounded : icon,
            size: compact ? 17 : 20,
            color: highlighted ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 10 : 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
