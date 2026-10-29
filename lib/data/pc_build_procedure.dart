import 'package:flutter/material.dart';

/// Procedures for the pictured DDR4 desktop kit, not a universal board manual.
class PcBuildOperation {
  const PcBuildOperation(
    this.label,
    this.tool,
    this.point, {
    this.place = false,
    this.result = '',
  });
  final String label, tool, result;
  final Offset point;
  final bool place;
}

class PcBuildProcedure {
  static const hand = 'ESD-safe hands';
  static const driver = 'Phillips #2';
  static const paste = 'Thermal compound';
  static const inspect = 'Inspection light';
  static const tools = [hand, driver, paste, inspect];
  static const frontPanelDropTokens = <int, String>{
    2: 'front_power_sw',
    3: 'front_reset_sw',
    4: 'front_hdd_led',
    5: 'front_power_led',
  };
  static const frontPanelLeadNames = <String, String>{
    'front_power_sw': 'POWER SW â€¢ blue/white â€¢ pins 6/8',
    'front_reset_sw': 'RESET SW â€¢ orange/white â€¢ pins 5/7',
    'front_hdd_led': 'HDD LED â€¢ red + / white âˆ’ â€¢ pins 1/3',
    'front_power_led': 'POWER LED â€¢ green + / white âˆ’ â€¢ pins 2/4',
  };
  static const rects = <String, Rect>{
    // These rectangles are calibrated against the photographed chassis. Their
    // screen-space aspect ratios match the transparent source sprites.
    'motherboard': Rect.fromLTWH(.255, .16, .262, .55),
    'cpu': Rect.fromLTWH(.366, .29, .056, .105),
    'cpu_fan': Rect.fromLTWH(.334, .227, .12, .23),
    // RAM and SSD source images are photographed horizontally. Their chassis
    // layers rotate 90 degrees into the vertical DIMM and drive mounts.
    // A seated DIMM is seen edge-on from this chassis view. The full-height
    // side-profile sprite is used only while the learner is positioning it.
    'ram': Rect.fromLTWH(.451, .211, .010, .263),
    // From the open side panel the installed card is seen edge-on.
    'gpu': Rect.fromLTWH(.245, .535, .22, .13),
    'ssd': Rect.fromLTWH(.608, .31, .09, .202),
    'psu': Rect.fromLTWH(.225, .735, .12, .213),
  };
  static const assets = <String, String>{
    'motherboard': 'assembly-motherboard-nine-hole-v2.png',
    'cpu': 'assembly-cpu-matched.png',
    'cpu_fan': 'assembly-cooler-matched.png',
    'ram': 'assembly-ram-ddr4-matched.png',
    'gpu': 'assembly-gpu-matched.png',
    'ssd': 'assembly-ssd-matched.png',
    'psu': 'assembly-psu-matched.png',
  };
  static const installedAssets = <String, String>{
    'ram': 'assembly-ram-installed-edge-v2.png',
    'gpu': 'assembly-gpu-installed-edge-v2.png',
  };
  static int quarterTurns(String id) => id == 'ram' || id == 'ssd' ? 1 : 0;
  static Rect targetRect(String id) => switch (id) {
    'ram' => const Rect.fromLTWH(.446, .206, .020, .273),
    'gpu' => const Rect.fromLTWH(.24, .51, .235, .17),
    _ => rects[id]!,
  };
  static const fasteners = <String, List<Offset>>{
    'motherboard': [
      Offset(.309, .191),
      Offset(.509, .676),
      Offset(.509, .191),
      Offset(.281, .676),
      Offset(.394, .489),
      Offset(.438, .191),
      Offset(.394, .688),
      Offset(.281, .483),
      Offset(.509, .483),
    ],
    'cpu_fan': [
      Offset(.34, .25),
      Offset(.45, .44),
      Offset(.45, .25),
      Offset(.34, .44),
    ],
    'gpu': [Offset(.25, .55), Offset(.25, .61)],
    'ssd': [
      Offset(.622, .325),
      Offset(.684, .495),
      Offset(.684, .325),
      Offset(.622, .495),
    ],
    'psu': [
      Offset(.235, .755),
      Offset(.335, .925),
      Offset(.335, .755),
      Offset(.235, .925),
    ],
  };
  static Offset installStartOffset(String id) => switch (id) {
    'motherboard' => const Offset(.07, -.10),
    'cpu' => const Offset(0, -.13),
    'cpu_fan' => const Offset(0, -.16),
    'ram' => const Offset(0, -.18),
    'gpu' => const Offset(-.15, -.04),
    'ssd' => const Offset(.14, 0),
    'psu' => const Offset(-.18, 0),
    _ => Offset.zero,
  };
  static double installStartAngle(String id) => switch (id) {
    'motherboard' => -.08,
    'cpu' => .04,
    'cpu_fan' => -.06,
    'ram' => .06,
    'gpu' => -.10,
    'ssd' => .04,
    _ => 0,
  };
  static double installStartScale(String id) => switch (id) {
    'cpu' || 'ram' => 1.18,
    'motherboard' || 'cpu_fan' => 1.08,
    _ => 1.04,
  };
  static Duration installDuration(String id) =>
      Duration(milliseconds: id == 'motherboard' || id == 'psu' ? 950 : 720);
  static const placementOperation = <String, int>{
    'motherboard': 10,
    'cpu': 2,
    'cpu_fan': 2,
    'ram': 2,
    'gpu': 2,
    'ssd': 0,
    'psu': 1,
  };
  static const fitChecks = <String, List<String>>{
    'motherboard': [
      'Rear I/O edge is flush with the chassis opening',
      'Every board hole is centered over a standoff',
      'No unused standoff touches the underside of the board',
    ],
    'cpu': [
      'Marked CPU corner matches the socket corner',
      'CPU rests flat without pressure or side-to-side movement',
      'Socket contacts remain untouched and undamaged',
    ],
    'cpu_fan': [
      'Cooler base is centered over the CPU lid',
      'All four fasteners line up before any is tightened',
      'Fan lead can reach CPU_FAN without crossing the blades',
    ],
    'ram': [
      'DDR4 notch matches the raised key in the DIMM slot',
      'Both ends enter the same slot at the same depth',
      'Both retaining clips close and the module remains level',
    ],
    'gpu': [
      'Rear bracket enters the open expansion-slot space',
      'Gold edge connector is directly over PCIe x16',
      'PCIe latch closes and the card remains level',
    ],
    'ssd': [
      'SATA connectors face the cable-routing side',
      'Drive holes align with the 2.5-inch tray holes',
      'Drive lies flat without covering another mount',
    ],
    'psu': [
      'Fan faces the filtered bottom ventilation opening',
      'Rear switch and mains socket remain accessible',
      'Four rear screw holes align before tightening',
    ],
  };
  static const operations = <String, List<PcBuildOperation>>{
    'motherboard': [
      PcBuildOperation(
        'Inspect the tray: remove any standoff without a matching board hole',
        inspect,
        Offset(.42, .45),
      ),
      PcBuildOperation(
        'Fit the upper-left standoff',
        driver,
        Offset(.309, .191),
      ),
      PcBuildOperation(
        'Fit the lower-right standoff',
        driver,
        Offset(.509, .676),
      ),
      PcBuildOperation(
        'Fit the upper-right standoff',
        driver,
        Offset(.509, .191),
      ),
      PcBuildOperation(
        'Fit the lower-left standoff',
        driver,
        Offset(.281, .676),
      ),
      PcBuildOperation('Fit the center standoff', driver, Offset(.394, .489)),
      PcBuildOperation(
        'Fit the top-center standoff',
        driver,
        Offset(.438, .191),
      ),
      PcBuildOperation(
        'Fit the bottom-center standoff',
        driver,
        Offset(.394, .688),
      ),
      PcBuildOperation(
        'Fit the center-left standoff',
        driver,
        Offset(.281, .483),
      ),
      PcBuildOperation(
        'Fit the center-right standoff',
        driver,
        Offset(.509, .483),
      ),
      PcBuildOperation(
        'Lower the board onto all nine standoffs; align rear I/O',
        hand,
        Offset(.41, .43),
        place: true,
      ),
      PcBuildOperation(
        'Snug the upper-left board screw',
        driver,
        Offset(.309, .191),
      ),
      PcBuildOperation(
        'Snug the lower-right board screw',
        driver,
        Offset(.509, .676),
      ),
      PcBuildOperation(
        'Snug the upper-right board screw',
        driver,
        Offset(.509, .191),
      ),
      PcBuildOperation(
        'Snug the lower-left board screw; do not overtighten',
        driver,
        Offset(.281, .676),
      ),
      PcBuildOperation(
        'Snug the center board screw',
        driver,
        Offset(.394, .489),
      ),
      PcBuildOperation(
        'Snug the top-center board screw',
        driver,
        Offset(.438, .191),
      ),
      PcBuildOperation(
        'Snug the bottom-center board screw',
        driver,
        Offset(.394, .688),
      ),
      PcBuildOperation(
        'Snug the center-left board screw',
        driver,
        Offset(.281, .483),
      ),
      PcBuildOperation(
        'Snug the center-right board screw',
        driver,
        Offset(.509, .483),
      ),
    ],
    'cpu': [
      PcBuildOperation('Release the socket lever', hand, Offset(.43, .35)),
      PcBuildOperation(
        'Raise the retention plate; inspect socket contacts',
        hand,
        Offset(.39, .29),
      ),
      PcBuildOperation(
        'Align the marked corner and lower the CPU straight into the socket',
        hand,
        Offset(.39, .34),
        place: true,
      ),
      PcBuildOperation('Close the retention plate', hand, Offset(.39, .29)),
      PcBuildOperation(
        'Latch the socket lever without forcing the CPU',
        hand,
        Offset(.43, .35),
      ),
    ],
    'cpu_fan': [
      PcBuildOperation(
        'Inspect the clean CPU lid and cooler base; this kit has no pre-applied paste',
        inspect,
        Offset(.39, .34),
      ),
      PcBuildOperation(
        'Apply the kit-specified small central amount of thermal compound',
        paste,
        Offset(.39, .34),
      ),
      PcBuildOperation(
        'Lower the cooler squarely onto the CPU',
        hand,
        Offset(.39, .34),
        place: true,
      ),
      PcBuildOperation(
        'Engage upper-left cooler fastener',
        driver,
        Offset(.34, .25),
      ),
      PcBuildOperation(
        'Engage lower-right fastener diagonally',
        driver,
        Offset(.45, .44),
      ),
      PcBuildOperation(
        'Engage upper-right cooler fastener',
        driver,
        Offset(.45, .25),
      ),
      PcBuildOperation(
        'Engage lower-left fastener evenly',
        driver,
        Offset(.34, .44),
      ),
      PcBuildOperation(
        'Plug the fan lead into CPU_FAN',
        hand,
        Offset(.455, .23),
      ),
    ],
    'ram': [
      PcBuildOperation(
        'Open the upper DIMM retaining clip',
        hand,
        Offset(.456, .211),
      ),
      PcBuildOperation(
        'Open the lower DIMM retaining clip',
        hand,
        Offset(.456, .474),
      ),
      PcBuildOperation(
        'Match the DDR4 notch and seat the DIMM evenly',
        hand,
        Offset(.456, .3425),
        place: true,
      ),
      PcBuildOperation(
        'Check both clips have locked and the module is level',
        inspect,
        Offset(.456, .3425),
      ),
    ],
    'gpu': [
      PcBuildOperation(
        'Remove the rear expansion-slot screws and covers',
        driver,
        Offset(.25, .58),
      ),
      PcBuildOperation(
        'Open the PCIe x16 retention latch',
        hand,
        Offset(.455, .51),
      ),
      PcBuildOperation(
        'Align the bracket and seat the card in PCIe x16',
        hand,
        Offset(.355, .585),
        place: true,
      ),
      PcBuildOperation(
        'Secure the card bracket to the chassis',
        driver,
        Offset(.25, .55),
      ),
      PcBuildOperation(
        'Secure the second expansion-slot bracket screw',
        driver,
        Offset(.25, .61),
      ),
      PcBuildOperation(
        'Inspect the locked PCIe latch and level card',
        inspect,
        Offset(.455, .51),
      ),
    ],
    'ssd': [
      PcBuildOperation(
        'Position the 2.5-inch SATA SSD in its tray, connectors accessible',
        hand,
        Offset(.653, .41),
        place: true,
      ),
      PcBuildOperation(
        'Secure the first SSD mounting screw',
        driver,
        Offset(.622, .325),
      ),
      PcBuildOperation(
        'Secure the diagonal SSD mounting screw',
        driver,
        Offset(.684, .495),
      ),
      PcBuildOperation(
        'Secure the upper-right SSD mounting screw',
        driver,
        Offset(.684, .325),
      ),
      PcBuildOperation(
        'Secure the lower-left SSD mounting screw',
        driver,
        Offset(.622, .495),
      ),
      PcBuildOperation(
        'Check the drive cannot shift in the carrier',
        inspect,
        Offset(.653, .41),
      ),
    ],
    'psu': [
      PcBuildOperation(
        'Check PSU switch is OFF and mains lead is disconnected',
        inspect,
        Offset(.285, .84),
      ),
      PcBuildOperation(
        'Face the PSU fan toward the filtered bottom intake and slide into the bay',
        hand,
        Offset(.285, .84),
        place: true,
      ),
      PcBuildOperation(
        'Secure upper-left PSU screw while supporting the unit',
        driver,
        Offset(.235, .755),
      ),
      PcBuildOperation(
        'Secure lower-right PSU screw',
        driver,
        Offset(.335, .925),
      ),
      PcBuildOperation(
        'Secure upper-right PSU screw',
        driver,
        Offset(.335, .755),
      ),
      PcBuildOperation(
        'Secure lower-left PSU screw',
        driver,
        Offset(.235, .925),
      ),
    ],
    'assembly_test': [
      PcBuildOperation(
        'Seat the keyed 24-pin ATX motherboard lead',
        hand,
        Offset(.501, .338),
      ),
      PcBuildOperation(
        'Seat the EPS 4+4 CPU lead; never substitute PCIe 6+2',
        hand,
        Offset(.326, .187),
      ),
      PcBuildOperation(
        'Seat the PCIe 6+2 lead on the graphics card',
        hand,
        Offset(.455, .58),
      ),
      PcBuildOperation(
        'Connect the SSD SATA data lead to the motherboard',
        hand,
        Offset(.635, .315),
      ),
      PcBuildOperation(
        'Connect the separate 15-pin SATA power lead to the SSD',
        hand,
        Offset(.675, .315),
      ),
      PcBuildOperation(
        'Connect PWR_SW to the kit header pins 6 and 8',
        hand,
        Offset(.49, .68),
      ),
      PcBuildOperation(
        'Inspect for loose screws, open latches and cables touching fans',
        inspect,
        Offset(.42, .45),
      ),
      PcBuildOperation(
        'Connect the monitor to the GPU and attach the keyboard',
        hand,
        Offset(.24, .62),
      ),
      PcBuildOperation(
        'Connect mains, switch PSU ON, then press the case power button',
        hand,
        Offset(.77, .14),
        result:
            'POST: CPU detected • DDR4 memory detected • SATA SSD detected • CPU fan running',
      ),
      PcBuildOperation(
        'Read firmware hardware detection and record the test result',
        inspect,
        Offset(.42, .45),
      ),
    ],
    'power_cable': [
      PcBuildOperation(
        'Verify mains is disconnected and PSU is OFF',
        inspect,
        Offset(.28, .84),
      ),
      PcBuildOperation(
        'Route the ATX lead through the nearest chassis grommet',
        hand,
        Offset(.565, .39),
      ),
      PcBuildOperation(
        'Drag the 24-pin connector to the motherboard socket, latch facing the hook',
        hand,
        Offset(.501, .338),
        place: true,
      ),
      PcBuildOperation(
        'Inspect the closed latch and flush connector housing',
        inspect,
        Offset(.501, .338),
      ),
    ],
    'cpu_power': [
      PcBuildOperation(
        'Check the EPS 4+4 label and square/rounded key pattern',
        inspect,
        Offset(.326, .187),
      ),
      PcBuildOperation(
        'Route behind the motherboard tray, clear of CPU_FAN',
        hand,
        Offset(.59, .19),
      ),
      PcBuildOperation(
        'Seat the joined EPS 4+4 connector at CPU power',
        hand,
        Offset(.326, .187),
        place: true,
      ),
      PcBuildOperation(
        'Inspect the engaged CPU power latch',
        inspect,
        Offset(.326, .187),
      ),
    ],
    'gpu_power': [
      PcBuildOperation(
        'Check PCIe 6+2 label; EPS is electrically incompatible',
        inspect,
        Offset(.455, .58),
      ),
      PcBuildOperation(
        'Route below the card, leaving slack clear of its fans',
        hand,
        Offset(.60, .70),
      ),
      PcBuildOperation(
        'Seat the joined PCIe 6+2 plug on the GPU',
        hand,
        Offset(.455, .58),
        place: true,
      ),
      PcBuildOperation(
        'Inspect the latched plug without pulling its wires',
        inspect,
        Offset(.455, .58),
      ),
    ],
    'sata_cable': [
      PcBuildOperation(
        'Inspect the narrow 7-pin L-shaped data plug',
        inspect,
        Offset(.635, .315),
      ),
      PcBuildOperation(
        'Seat the data cable at the SSD',
        hand,
        Offset(.635, .315),
        place: true,
      ),
      PcBuildOperation(
        'Connect the other end to motherboard SATA0',
        hand,
        Offset(.501, .585),
      ),
      PcBuildOperation(
        'Route the data cable without sharp bends',
        hand,
        Offset(.56, .64),
      ),
    ],
    'sata_power': [
      PcBuildOperation(
        'Inspect the wider 15-pin L-shaped SATA power housing',
        inspect,
        Offset(.675, .315),
      ),
      PcBuildOperation(
        'Route the SATA power branch from the PSU behind the drive tray',
        hand,
        Offset(.64, .56),
      ),
      PcBuildOperation(
        'Seat the SATA power connector on the SSD without twisting it',
        hand,
        Offset(.675, .315),
        place: true,
      ),
      PcBuildOperation(
        'Inspect both SSD connectors and keep their cables free of strain',
        inspect,
        Offset(.655, .315),
      ),
    ],
    'front_panel': [
      PcBuildOperation(
        'Read the training board header: HDD_LED 1+/3−, PWR_LED 2+/4−, RESET 5/7, PWR_SW 6/8',
        inspect,
        Offset(.49, .68),
      ),
      PcBuildOperation(
        'Connect the front-panel harness at F_PANEL',
        hand,
        Offset(.49, .68),
        place: true,
      ),
      PcBuildOperation(
        'Seat PWR_SW on pins 6/8; switch polarity does not matter',
        hand,
        Offset(.505, .69),
        place: true,
      ),
      PcBuildOperation(
        'Seat RESET on pins 5/7; switch polarity does not matter',
        hand,
        Offset(.495, .685),
        place: true,
      ),
      PcBuildOperation(
        'Seat HDD_LED positive on 1 and negative on 3',
        hand,
        Offset(.475, .675),
        place: true,
      ),
      PcBuildOperation(
        'Seat PWR_LED positive on 2 and negative on 4',
        hand,
        Offset(.485, .68),
        place: true,
      ),
    ],
    'cable_inspection': [
      PcBuildOperation(
        'Check CPU_FAN is plugged into the fan header',
        inspect,
        Offset(.455, .23),
      ),
      PcBuildOperation(
        'Secure the cable bundle behind the tray without crushing wires',
        hand,
        Offset(.60, .73),
      ),
      PcBuildOperation(
        'Check all fan sweep areas and connector latches',
        inspect,
        Offset(.40, .34),
      ),
      PcBuildOperation(
        'Connect display and keyboard, then mains; switch on and test',
        hand,
        Offset(.77, .14),
        result:
            'CHECK: power and reset switches respond • fans unobstructed • SSD detected',
      ),
      PcBuildOperation(
        'Record the inspection and functional-test result',
        inspect,
        Offset(.42, .45),
      ),
    ],
  };
}
