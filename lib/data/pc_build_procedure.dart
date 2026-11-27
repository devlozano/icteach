import 'package:flutter/material.dart';

/// Procedures for the pictured DDR4 desktop kit, not a universal board manual.
class PcBuildOperation {
  const PcBuildOperation(
    this.label,
    this.tool,
    this.point, {
    this.place = false,
    this.result = '',
    this.dropToken,
    this.requiredQuarterTurns,
  });
  final String label, tool, result;
  final Offset point;
  final bool place;
  final String? dropToken;
  final int? requiredQuarterTurns;
}

class PcBuildProcedure {
  static const hand = 'ESD-safe hands';
  static const driver = 'Phillips #2';
  static const paste = 'Thermal compound';
  static const inspect = 'Inspection light';
  static const tools = [hand, driver, paste, inspect];
  // The cooler lead exits on the upper-right side of the fan and plugs into
  // the CPU_FAN header above the DIMM bank. Keeping both anchors above the RAM
  // rectangle prevents the rendered lead from crossing either memory slot.
  static const cpuFanCableExit = Offset(.405, .285);
  static const cpuFanHeader = Offset(.443, .195);
  static const coolerPushPins = <Offset>[
    Offset(.349, .271),
    Offset(.425, .410),
    Offset(.425, .271),
    Offset(.349, .410),
  ];
  static const cableRouteX = <String, double>{
    'power_cable': .575,
    'gpu_power': .515,
    'sata_cable': .555,
    'sata_power': .665,
  };
  // Physical connector faces on the installed component artwork.
  static const gpuPowerPort = Offset(.435, .532);
  // Center the full 7-pin housing over the SSD data socket. The earlier
  // anchor used its left edge and left the plug visibly offset.
  static const sataDataDrivePort = Offset(.612, .542);
  static const sataDataBoardPort = Offset(.501, .585);
  static const sataPowerDrivePort = Offset(.642, .542);
  // F_PANEL is a 2x5 pin header. Each two-pin housing must remain on one
  // horizontal row instead of forming a diagonal line across the board.
  static const frontHddLedPins = Offset(.481, .681);
  static const frontPowerLedPins = Offset(.481, .690);
  static const frontResetSwPins = Offset(.500, .681);
  static const frontPowerSwPins = Offset(.500, .690);
  static const frontPanelDropTokens = <int, String>{
    2: 'front_power_sw',
    3: 'front_reset_sw',
    4: 'front_hdd_led',
    5: 'front_power_led',
  };
  static const frontPanelLeadNames = <String, String>{
    'front_power_sw': 'POWER SW • blue/white • pins 6/8',
    'front_reset_sw': 'RESET SW • orange/white • pins 5/7',
    'front_hdd_led': 'HDD LED • red + / white − • pins 1/3',
    'front_power_led': 'POWER LED • green + / white − • pins 2/4',
  };
  static const connectorNames = <String, String>{
    'atx_24pin_plug': '24-pin ATX plug • motherboard main power',
    'eps_8pin_plug': '4+4 EPS plug • CPU power socket',
    'pcie_8pin_plug': '6+2 PCIe plug • GPU auxiliary power',
    'sata_data_drive': 'SATA data end • SSD data port',
    'sata_data_board': 'SATA data end • motherboard SATA0 port',
    'sata_power_drive': '15-pin SATA power • SSD power port',
    'test_display': 'Display cable • graphics output',
    'test_keyboard': 'USB keyboard • rear USB port',
    'test_mains': 'IEC mains lead • PSU inlet',
  };
  static const rects = <String, Rect>{
    // These rectangles are calibrated against the photographed chassis. Their
    // screen-space aspect ratios match the transparent source sprites.
    'motherboard': Rect.fromLTWH(.255, .16, .262, .55),
    'cpu': Rect.fromLTWH(.366, .29, .056, .105),
    // Physical screen dimensions are square on the 1672:941 chassis canvas.
    // The smaller footprint clears the adjacent CMOS holder.
    'cpu_fan': Rect.fromLTWH(.345, .265, .084, .1493),
    // RAM and SSD source images are photographed horizontally. Their chassis
    // layers rotate 90 degrees into the vertical DIMM and drive mounts.
    // A seated DIMM is seen edge-on from this chassis view. The full-height
    // side-profile sprite is used only while the learner is positioning it.
    // Center the DIMM over the pictured slot while leaving clear space beside
    // the CMOS holder. The latch painter uses this same .463 center.
    'ram': Rect.fromLTWH(.458, .211, .010, .263),
    // From the open side panel the installed card is seen edge-on.
    // The rear bracket sits against the expansion-slot rail while the gold
    // edge is centered over PCIe x16. This also puts both bracket tabs under
    // their case screw anchors instead of leaving the screws beside the card.
    'gpu': Rect.fromLTWH(.228, .510, .22, .13),
    // Raised 2.5-inch carrier beside the motherboard tray. The connector edge
    // faces down toward the cable grommet and remains visible after seating.
    'ssd': Rect.fromLTWH(.574, .292, .104, .258),
    // Calibrated to the round CR2032 holder visible on the motherboard layer.
    // Seat the CR2032 inside the holder without touching the DIMM bank.
    'cmos': Rect.fromLTWH(.423, .422, .018, .032),
    'psu': Rect.fromLTWH(.225, .735, .12, .213),
  };
  static const assets = <String, String>{
    'motherboard': 'assembly-motherboard-cmos-holder-v3.png',
    'cpu': 'assembly-cpu-matched.png',
    'cpu_fan': 'assembly-cooler-pushpin-v2.png',
    'ram': 'assembly-ram-ddr4-matched.png',
    'gpu': 'assembly-gpu-matched.png',
    'ssd': 'assembly-ssd-matched.png',
    'cmos': 'cmos-cr2032-v1.png',
    'psu': 'assembly-psu-matched.png',
  };
  static const installedAssets = <String, String>{
    'ram': 'assembly-ram-installed-edge-v2.png',
    'gpu': 'assembly-gpu-installed-edge-v2.png',
  };
  static int quarterTurns(String id) => switch (id) {
    'ram' => 1,
    // Turn counter-clockwise so the SSD's SATA edge faces the lower cable
    // opening rather than being trapped against the top of the carrier.
    'ssd' => 3,
    _ => 0,
  };
  static Rect targetRect(String id) => switch (id) {
    'ram' => const Rect.fromLTWH(.453, .206, .020, .273),
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
    // The GPU bracket screws pass through the rear I/O bracket tabs into the
    // top two case expansion-slot screw holes.
    'gpu': [Offset(.230, .523), Offset(.230, .558)],
    'ssd': [
      Offset(.594, .335),
      Offset(.662, .505),
      Offset(.662, .335),
      Offset(.594, .505),
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
    'cmos' => const Offset(0, -.12),
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
    'cmos' => .02,
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
    'motherboard': 1,
    'cpu': 2,
    'cpu_fan': 2,
    'ram': 2,
    'gpu': 2,
    'ssd': 0,
    'cmos': 2,
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
    'cmos': [
      'Battery holder latch is released before insertion',
      'CR2032 positive (+) face remains visible',
      'Battery sits flat beneath the retaining tab',
    ],
    'psu': [
      'Fan faces the filtered bottom ventilation opening',
      'Rear switch and mains socket remain accessible',
      'Four rear screw holes align before tightening',
    ],
  };
  static const wiringSequence = [
    'power_cable',
    'cpu_power',
    'gpu_power',
    'sata_cable',
    'sata_power',
    'front_panel',
    'cable_inspection',
  ];
  static const connectionSequence = [...wiringSequence, 'assembly_test'];
  static List<PcBuildOperation> stepsFor(String? id) =>
      operations[id] ?? const [];
  static Set<String> get requiredConnections => {
    for (final key in connectionSequence)
      for (final step in operations[key]!)
        if (step.dropToken != null) step.dropToken!,
  };
  static const operations = <String, List<PcBuildOperation>>{
    'motherboard': [
      PcBuildOperation(
        'Inspect the pre-fitted standoffs: each must match a motherboard hole',
        inspect,
        Offset(.42, .45),
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
        'Rotate the upper-left push pin to its install position, then press until it clicks',
        hand,
        Offset(.349, .271),
      ),
      PcBuildOperation(
        'Rotate and press the lower-right push pin diagonally opposite',
        hand,
        Offset(.425, .410),
      ),
      PcBuildOperation(
        'Rotate and press the upper-right push pin until its center locks',
        hand,
        Offset(.425, .271),
      ),
      PcBuildOperation(
        'Rotate and press the lower-left push pin; verify all four sit level',
        hand,
        Offset(.349, .410),
      ),
      PcBuildOperation('Plug the fan lead into CPU_FAN', hand, cpuFanHeader),
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
        Offset(.226, .54),
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
        Offset(.230, .523),
      ),
      PcBuildOperation(
        'Secure the second expansion-slot bracket screw',
        driver,
        Offset(.230, .558),
      ),
      PcBuildOperation(
        'Inspect the locked PCIe latch and level card',
        inspect,
        Offset(.455, .51),
      ),
    ],
    'cmos': [
      PcBuildOperation(
        'Locate the CR2032 holder and inspect its retaining latch',
        inspect,
        Offset(.438, .438),
      ),
      PcBuildOperation(
        'Release the CMOS battery-holder latch',
        hand,
        Offset(.447, .438),
      ),
      PcBuildOperation(
        'Insert the CR2032 with the positive (+) face visible',
        hand,
        Offset(.438, .438),
        place: true,
      ),
      PcBuildOperation(
        'Press the edge beneath the latch and confirm the battery is flat',
        inspect,
        Offset(.438, .438),
      ),
    ],
    'ssd': [
      PcBuildOperation(
        'Position the 2.5-inch SATA SSD in its tray, connectors accessible',
        hand,
        Offset(.626, .421),
        place: true,
      ),
      PcBuildOperation(
        'Secure the first SSD mounting screw',
        driver,
        Offset(.594, .335),
      ),
      PcBuildOperation(
        'Secure the diagonal SSD mounting screw',
        driver,
        Offset(.662, .505),
      ),
      PcBuildOperation(
        'Secure the upper-right SSD mounting screw',
        driver,
        Offset(.662, .335),
      ),
      PcBuildOperation(
        'Secure the lower-left SSD mounting screw',
        driver,
        Offset(.594, .505),
      ),
      PcBuildOperation(
        'Check the drive cannot shift in the carrier',
        inspect,
        Offset(.626, .421),
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
        'Drag the display cable into the graphics output',
        hand,
        Offset(.785, .26),
        place: true,
        dropToken: 'test_display',
        requiredQuarterTurns: 0,
      ),
      PcBuildOperation(
        'Drag the keyboard USB plug into a rear USB port',
        hand,
        Offset(.785, .32),
        place: true,
        dropToken: 'test_keyboard',
        requiredQuarterTurns: 0,
      ),
      PcBuildOperation(
        'Connect the IEC mains lead to the PSU inlet',
        hand,
        Offset(.785, .82),
        place: true,
        dropToken: 'test_mains',
        requiredQuarterTurns: 0,
      ),
      PcBuildOperation(
        'Switch the PSU ON and press the case power button',
        hand,
        Offset(.77, .14),
        result:
            'CHECK: power and reset switches respond • fans unobstructed • SSD detected',
      ),
      PcBuildOperation(
        'Open firmware hardware information and verify CPU, DDR4 memory, and SATA SSD detection',
        hand,
        Offset(.74, .29),
      ),
      PcBuildOperation(
        'Record the final POST and hardware-detection result',
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
        dropToken: 'atx_24pin_plug',
        requiredQuarterTurns: 0,
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
        dropToken: 'eps_8pin_plug',
        requiredQuarterTurns: 0,
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
        gpuPowerPort,
      ),
      PcBuildOperation(
        'Route below the card, leaving slack clear of its fans',
        hand,
        Offset(.60, .70),
      ),
      PcBuildOperation(
        'Seat the joined PCIe 6+2 plug on the GPU',
        hand,
        gpuPowerPort,
        place: true,
        dropToken: 'pcie_8pin_plug',
        requiredQuarterTurns: 0,
      ),
      PcBuildOperation(
        'Inspect the latched plug without pulling its wires',
        inspect,
        gpuPowerPort,
      ),
    ],
    'sata_cable': [
      PcBuildOperation(
        'Inspect the narrow 7-pin L-shaped data plug',
        inspect,
        sataDataDrivePort,
      ),
      PcBuildOperation(
        'Seat the data cable at the SSD',
        hand,
        sataDataDrivePort,
        place: true,
        dropToken: 'sata_data_drive',
        requiredQuarterTurns: 0,
      ),
      PcBuildOperation(
        'Rotate and drag the other end into motherboard SATA0',
        hand,
        sataDataBoardPort,
        place: true,
        dropToken: 'sata_data_board',
        requiredQuarterTurns: 2,
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
        sataPowerDrivePort,
      ),
      PcBuildOperation(
        'Route the SATA power branch from the PSU behind the drive tray',
        hand,
        Offset(.64, .56),
      ),
      PcBuildOperation(
        'Seat the SATA power connector on the SSD without twisting it',
        hand,
        sataPowerDrivePort,
        place: true,
        dropToken: 'sata_power_drive',
        requiredQuarterTurns: 0,
      ),
      PcBuildOperation(
        'Inspect both SSD connectors and keep their cables free of strain',
        inspect,
        Offset(.624, .542),
      ),
    ],
    'front_panel': [
      PcBuildOperation(
        'Read the training board header: HDD LED 1+/3−, POWER LED 2+/4−, RESET SW 5/7, POWER SW 6/8',
        inspect,
        Offset(.49, .68),
      ),
      PcBuildOperation(
        'Separate the four front-panel leads and verify every printed label',
        inspect,
        Offset(.49, .68),
      ),
      PcBuildOperation(
        'Seat PWR_SW on pins 6/8; switch polarity does not matter',
        hand,
        frontPowerSwPins,
        place: true,
        dropToken: 'front_power_sw',
      ),
      PcBuildOperation(
        'Seat RESET on pins 5/7; switch polarity does not matter',
        hand,
        frontResetSwPins,
        place: true,
        dropToken: 'front_reset_sw',
      ),
      PcBuildOperation(
        'Seat HDD_LED positive on 1 and negative on 3',
        hand,
        frontHddLedPins,
        place: true,
        dropToken: 'front_hdd_led',
        requiredQuarterTurns: 0,
      ),
      PcBuildOperation(
        'Seat PWR_LED positive on 2 and negative on 4',
        hand,
        frontPowerLedPins,
        place: true,
        dropToken: 'front_power_led',
        requiredQuarterTurns: 0,
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
        'Confirm front-panel polarity and close the side panel without pinching a cable',
        inspect,
        Offset(.42, .45),
      ),
    ],
  };
}
