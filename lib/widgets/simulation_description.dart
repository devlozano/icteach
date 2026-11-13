import 'package:flutter/material.dart';
import '../models/simulation_model.dart';

/// Readable on both dark workbenches and light screens; never clips instructions.
class SimulationDescriptionSection extends StatelessWidget {
  final String title, text;
  const SimulationDescriptionSection({
    super.key,
    required this.title,
    required this.text,
  });
  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final (icon, accent) = switch (title.toLowerCase()) {
      final value when value.contains('description') => (
        Icons.info_outline_rounded,
        const Color(0xFF2563EB),
      ),
      final value when value.contains('specification') => (
        Icons.tune_rounded,
        const Color(0xFF7C3AED),
      ),
      final value
          when value.contains('handling') || value.contains('what to do') =>
        (Icons.pan_tool_alt_outlined, const Color(0xFFB45309)),
      final value
          when value.contains('verify') || value.contains('verification') =>
        (Icons.fact_check_outlined, const Color(0xFF0F766E)),
      final value when value.contains('resource') => (
        Icons.handyman_outlined,
        const Color(0xFF0369A1),
      ),
      _ => (Icons.school_outlined, const Color(0xFF334155)),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: .08), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: accent, size: 18),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text.trim(),
                softWrap: true,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SimulationItemDescriptionDialog extends StatelessWidget {
  final DraggableItem item;
  final String resource, control;
  const SimulationItemDescriptionDialog({
    super.key,
    required this.item,
    required this.resource,
    required this.control,
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.precision_manufacturing_outlined,
            color: Color(0xFF0369A1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.name,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
    scrollable: true,
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SimulationDescriptionSection(
            title: 'Description',
            text: item.description,
          ),
          SimulationDescriptionSection(
            title: 'Specifications',
            text: item.specification,
          ),
          if (item.tooltip.trim() != item.description.trim())
            SimulationDescriptionSection(
              title: 'Handling guidance',
              text: item.tooltip,
            ),
          SimulationDescriptionSection(
            title: 'Required resource',
            text: resource,
          ),
          SimulationDescriptionSection(title: 'How to use', text: control),
        ],
      ),
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF1D4ED8)),
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
