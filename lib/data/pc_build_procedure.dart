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
  static const rects = <String, Rect>{
    'motherboard': Rect.fromLTWH(.255, .16, .31, .55),
    'cpu': Rect.fromLTWH(.361, .29, .064, .10),
    'cpu_fan': Rect.fromLTWH(.326, .23, .14, .23),
    'ram': Rect.fromLTWH(.512, .22, .043, .29),
    'gpu': Rect.fromLTWH(.253, .56, .33, .12),
    'ssd': Rect.fromLTWH(.65, .49, .10, .16),
    'psu': Rect.fromLTWH(.227, .765, .23, .16),
  };
  static const assets = <String, String>{
    'motherboard': 'assembly-motherboard-matched.png',
    'cpu': 'assembly-cpu-matched.png',
    'cpu_fan': 'assembly-cooler-matched.png',
    'ram': 'assembly-ram-ddr4-matched.png',
    'gpu': 'assembly-gpu-matched.png',
    'ssd': 'assembly-ssd-matched.png',
    'psu': 'assembly-psu-matched.png',
  };
  static const operations = <String, List<PcBuildOperation>>{
    'motherboard': [
      PcBuildOperation(
        'Inspect the tray: remove any standoff without a matching board hole',
        inspect,
        Offset(.42, .45),
      ),
      PcBuildOperation('Fit the upper-left standoff', driver, Offset(.28, .20)),
      PcBuildOperation(
        'Fit the lower-right standoff',
        driver,
        Offset(.54, .68),
      ),
      PcBuildOperation(
        'Fit the upper-right standoff',
        driver,
        Offset(.54, .20),
      ),
      PcBuildOperation('Fit the lower-left standoff', driver, Offset(.28, .68)),
      PcBuildOperation(
        'Lower the board onto the four training-kit standoffs; align rear I/O',
        hand,
        Offset(.41, .43),
        place: true,
      ),
      PcBuildOperation(
        'Snug the upper-left board screw',
        driver,
        Offset(.28, .20),
      ),
      PcBuildOperation(
        'Snug the lower-right board screw',
        driver,
        Offset(.54, .68),
      ),
      PcBuildOperation(
        'Snug the upper-right board screw',
        driver,
        Offset(.54, .20),
      ),
      PcBuildOperation(
        'Snug the lower-left board screw; do not overtighten',
        driver,
        Offset(.28, .68),
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
        Offset(.48, .23),
      ),
    ],
    'ram': [
      PcBuildOperation(
        'Open the upper DIMM retaining clip',
        hand,
        Offset(.53, .22),
      ),
      PcBuildOperation(
        'Open the lower DIMM retaining clip',
        hand,
        Offset(.53, .51),
      ),
      PcBuildOperation(
        'Match the DDR4 notch and seat the DIMM evenly',
        hand,
        Offset(.53, .36),
        place: true,
      ),
      PcBuildOperation(
        'Check both clips have locked and the module is level',
        inspect,
        Offset(.53, .36),
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
        Offset(.56, .60),
      ),
      PcBuildOperation(
        'Align the bracket and seat the card in PCIe x16',
        hand,
        Offset(.42, .60),
        place: true,
      ),
      PcBuildOperation(
        'Secure the card bracket to the chassis',
        driver,
        Offset(.25, .58),
      ),
      PcBuildOperation(
        'Inspect the locked PCIe latch and level card',
        inspect,
        Offset(.56, .60),
      ),
    ],
    'ssd': [
      PcBuildOperation(
        'Position the 2.5-inch SATA SSD in its tray, connectors accessible',
        hand,
        Offset(.70, .56),
        place: true,
      ),
      PcBuildOperation(
        'Secure the first SSD mounting screw',
        driver,
        Offset(.66, .50),
      ),
      PcBuildOperation(
        'Secure the diagonal SSD mounting screw',
        driver,
        Offset(.74, .64),
      ),
      PcBuildOperation(
        'Check the drive cannot shift in the carrier',
        inspect,
        Offset(.70, .56),
      ),
    ],
    'psu': [
      PcBuildOperation(
        'Check PSU switch is OFF and mains lead is disconnected',
        inspect,
        Offset(.27, .83),
      ),
      PcBuildOperation(
        'Face the PSU fan toward the filtered bottom intake and slide into the bay',
        hand,
        Offset(.34, .84),
        place: true,
      ),
      PcBuildOperation(
        'Secure upper-left PSU screw while supporting the unit',
        driver,
        Offset(.24, .79),
      ),
      PcBuildOperation(
        'Secure lower-right PSU screw',
        driver,
        Offset(.44, .90),
      ),
      PcBuildOperation(
        'Secure upper-right PSU screw',
        driver,
        Offset(.44, .79),
      ),
      PcBuildOperation('Secure lower-left PSU screw', driver, Offset(.24, .90)),
    ],
    'assembly_test': [
      PcBuildOperation(
        'Seat the keyed 24-pin ATX motherboard lead',
        hand,
        Offset(.56, .40),
      ),
      PcBuildOperation(
        'Seat the EPS 4+4 CPU lead; never substitute PCIe 6+2',
        hand,
        Offset(.29, .18),
      ),
      PcBuildOperation(
        'Seat the PCIe 6+2 lead on the graphics card',
        hand,
        Offset(.56, .60),
      ),
      PcBuildOperation(
        'Connect the SSD SATA data lead to the motherboard',
        hand,
        Offset(.69, .58),
      ),
      PcBuildOperation(
        'Connect the separate 15-pin SATA power lead to the SSD',
        hand,
        Offset(.73, .58),
      ),
      PcBuildOperation(
        'Connect PWR_SW to the kit header pins 6 and 8',
        hand,
        Offset(.51, .68),
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
        'Read firmware hardware detection and record the commissioning result',
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
        Offset(.59, .41),
      ),
      PcBuildOperation(
        'Drag the 24-pin connector to the motherboard socket, latch facing the hook',
        hand,
        Offset(.56, .40),
        place: true,
      ),
      PcBuildOperation(
        'Inspect the closed latch and flush connector housing',
        inspect,
        Offset(.56, .40),
      ),
    ],
    'cpu_power': [
      PcBuildOperation(
        'Check the EPS 4+4 label and square/rounded key pattern',
        inspect,
        Offset(.29, .18),
      ),
      PcBuildOperation(
        'Route behind the motherboard tray, clear of CPU_FAN',
        hand,
        Offset(.59, .19),
      ),
      PcBuildOperation(
        'Seat the joined EPS 4+4 connector at CPU power',
        hand,
        Offset(.29, .18),
        place: true,
      ),
      PcBuildOperation(
        'Inspect the engaged CPU power latch',
        inspect,
        Offset(.29, .18),
      ),
    ],
    'gpu_power': [
      PcBuildOperation(
        'Check PCIe 6+2 label; EPS is electrically incompatible',
        inspect,
        Offset(.56, .60),
      ),
      PcBuildOperation(
        'Route below the card, leaving slack clear of its fans',
        hand,
        Offset(.60, .70),
      ),
      PcBuildOperation(
        'Seat the joined PCIe 6+2 plug on the GPU',
        hand,
        Offset(.56, .60),
        place: true,
      ),
      PcBuildOperation(
        'Inspect the latched plug without pulling its wires',
        inspect,
        Offset(.56, .60),
      ),
    ],
    'sata_cable': [
      PcBuildOperation(
        'Inspect the narrow 7-pin L-shaped data plug',
        inspect,
        Offset(.69, .58),
      ),
      PcBuildOperation(
        'Seat the data cable at the SSD',
        hand,
        Offset(.69, .58),
        place: true,
      ),
      PcBuildOperation(
        'Connect the other end to motherboard SATA0',
        hand,
        Offset(.54, .65),
      ),
      PcBuildOperation(
        'Route the data cable without sharp bends',
        hand,
        Offset(.60, .67),
      ),
    ],
    'front_panel': [
      PcBuildOperation(
        'Read the training board header: HDD_LED 1+/3−, PWR_LED 2+/4−, RESET 5/7, PWR_SW 6/8',
        inspect,
        Offset(.51, .68),
      ),
      PcBuildOperation(
        'Connect the front-panel harness at F_PANEL',
        hand,
        Offset(.51, .68),
        place: true,
      ),
      PcBuildOperation(
        'Seat PWR_SW on pins 6/8; switch polarity does not matter',
        hand,
        Offset(.52, .68),
      ),
      PcBuildOperation('Seat RESET on pins 5/7', hand, Offset(.50, .68)),
      PcBuildOperation(
        'Seat HDD_LED positive on 1 and negative on 3',
        hand,
        Offset(.49, .68),
      ),
      PcBuildOperation(
        'Seat PWR_LED positive on 2 and negative on 4',
        hand,
        Offset(.48, .68),
      ),
    ],
    'cable_inspection': [
      PcBuildOperation(
        'Connect the separate SATA power lead from PSU to SSD',
        hand,
        Offset(.73, .58),
      ),
      PcBuildOperation(
        'Check CPU_FAN is plugged into the fan header',
        inspect,
        Offset(.48, .23),
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
            'POST: power and reset switches respond • fans unobstructed • SSD detected',
      ),
      PcBuildOperation(
        'Record the inspection and functional-test result',
        inspect,
        Offset(.42, .45),
      ),
    ],
  };
}
