import 'package:flutter/material.dart';

/// A short placement response; it never changes the activity's scoring state.
class SimulationPlacementMotion extends StatelessWidget {
  const SimulationPlacementMotion({
    super.key,
    required this.identity,
    required this.child,
  });
  final Object identity;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(identity),
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (_, value, child) => Opacity(
      opacity: .65 + .35 * value,
      child: Transform.scale(scale: .94 + .06 * value, child: child),
    ),
  );
}
