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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 6),
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
    title: Text(
      item.name,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
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
