import 'package:flutter/material.dart';

/// AI-generated object art; wire order, connections and test LEDs remain live.
class Rj45Art {
  static const root = 'assets/simulations/rj45/';
  static const objects = [
    'stripper',
    'cutters',
    'crimper_open',
    'crimper_closed',
    'cable_intact',
    'cable_spline',
    'cable_pairs',
    'plug_empty',
    'plug_side',
    'cable_plug',
    'tester_main',
    'tester_remote',
    'tester_main_connected',
    'tester_remote_connected',
  ];
  static const wires = [
    'white-orange',
    'orange',
    'white-green',
    'green',
    'white-blue',
    'blue',
    'white-brown',
    'brown',
  ];
  static List<String> get paths => [
    for (final id in objects) '$root$id.png',
    for (final id in wires) '${root}wire_$id.png',
  ];
  static String wire(int index) => 'wire_${wires[index]}';
  static Widget image(
    String id, {
    Key? key,
    double? width,
    double? height,
    String? label,
  }) => Image.asset(
    '$root$id.png',
    key: key,
    width: width,
    height: height,
    fit: BoxFit.contain,
    cacheWidth: width == null ? 768 : (width * 2).ceil(),
    semanticLabel: label ?? id.replaceAll('_', ' '),
    gaplessPlayback: true,
  );
}
