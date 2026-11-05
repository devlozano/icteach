import 'package:flutter/material.dart';

/// Regions calibrated to assembly-motherboard-nine-hole-v2.png.
class MotherboardParts {
  static const asset =
      'assets/simulations/assembly-motherboard-nine-hole-v2.png';
  static const entries = <(String, String, Rect, String)>[
    (
      'cpu_socket',
      'CPU socket',
      Rect.fromLTWH(.41, .18, .23, .28),
      'Holds the processor. Match the CPU orientation before closing the retention mechanism.',
    ),
    (
      'dimm',
      'DIMM memory slots',
      Rect.fromLTWH(.71, .09, .16, .50),
      'Accept compatible RAM modules. Align the module notch with the slot key.',
    ),
    (
      'atx',
      '24-pin ATX power socket',
      Rect.fromLTWH(.92, .22, .06, .20),
      'Supplies the motherboard with its main power connection.',
    ),
    (
      'eps',
      'CPU power socket',
      Rect.fromLTWH(.23, .025, .09, .05),
      'Accepts CPU EPS power from the PSU. Do not substitute a PCIe GPU lead.',
    ),
    (
      'pcie',
      'Primary PCIe x16 slot',
      Rect.fromLTWH(.21, .60, .41, .055),
      'Accepts a graphics card. Release its retention latch before removing the card.',
    ),
    (
      'sata',
      'SATA drive ports',
      Rect.fromLTWH(.92, .66, .065, .23),
      'Connect SATA data cables to storage drives. Drives also need separate power.',
    ),
    (
      'io',
      'Rear I/O ports',
      Rect.fromLTWH(.02, .02, .11, .53),
      'Provide external connections such as USB, network, and audio.',
    ),
    (
      'chipset',
      'Chipset heatsink',
      Rect.fromLTWH(.69, .62, .20, .26),
      'Dissipates heat from the chipset that supports peripheral communication.',
    ),
  ];
}
