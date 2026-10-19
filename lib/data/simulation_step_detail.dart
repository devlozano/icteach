import '../models/simulation_model.dart';

/// Local training operations. These never execute commands on a real device.
class SimulationStepDetail {
  final List<String> actions;
  final String expected;
  final String fault;
  const SimulationStepDetail(this.actions, this.expected, this.fault);

  static SimulationStepDetail forItem(
    Simulation simulation,
    DraggableItem item,
  ) {
    final specific = _steps[item.correctSlot];
    if (specific != null) return specific;
    if (simulation.id == 'sim_coc2_ipconfig') {
      final address = item.name.split(': ').last;
      return SimulationStepDetail(
        [
          'Open the IPv4 properties for ${item.name.split(':').first}. Select the adapter connected to the training LAN.',
          'Select manual addressing and enter $address. Compare it with the device allocation table to avoid duplicates.',
          'Enter subnet mask 255.255.255.0. ${item.id == 'ip_router' ? 'This is the router LAN interface; its upstream route is configured separately.' : 'Set default gateway 192.168.1.254.'}',
          'Apply the approved DNS address from the network plan. Save the adapter settings and reopen the status view.',
          'Inspect the saved address, then test the gateway and an approved service separately. Record the result.',
        ],
        'Saved IPv4 address is $address with a /24 mask.',
        'The saved address differs from $address or another device already uses it.',
      );
    }
    if (simulation.id == 'sim_coc2_crimping') {
      return SimulationStepDetail(
        [
          'Hold the plug with gold contacts facing you, latch away, and cable entering from below. Locate pin ${item.step}.',
          'Separate ${item.name.split(' (').first} without stripping its individual insulation. Keep pair untwist to the minimum required by the plug.',
          'Place this conductor in channel ${item.step}. Check adjacent conductors against the complete T568B order.',
          'Check that its tip reaches the end of the plug before crimping. Repeat the inspection at the other end and run the wire-map tester.',
        ],
        'Conductor matches pin ${item.step} and reaches the plug nose.',
        'Conductor is in an adjacent channel or stops short of the contact.',
      );
    }
    // Legacy/custom activities retain their own instructions, never an empty lab.
    return SimulationStepDetail(
      [
        'Inspect ${item.name}: ${item.description}',
        if (item.specification.isNotEmpty)
          'Compare the specification: ${item.specification}',
        'Prepare the target ${item.correctSlot.replaceAll('_', ' ')}. ${item.tooltip}',
        'Perform the indicated operation, then inspect the result before continuing.',
      ],
      'The requested operation is complete and the target matches the instructions.',
      'The requested operation is incomplete or the target does not match.',
    );
  }

  static SimulationStepDetail? forSlot(String slot) => _steps[slot];

  static const _steps = <String, SimulationStepDetail>{
    'safety_station': SimulationStepDetail(
      [
        'Save work and shut down normally. Identify mains and any other power sources before opening the case.',
        'Disconnect mains and peripherals and follow the manufacturer residual-power procedure.',
        'Connect ESD protection to the approved ground point and clear an antistatic work area.',
        'Undo the side-panel fasteners, collect them in a labelled tray, and slide the panel free.',
      ],
      'All power sources are isolated and the panel is removed safely.',
      'A power lead remains connected or the panel catches on a fastener.',
    ),
    'gpu_parts_tray': SimulationStepDetail(
      [
        'Identify the GPU power plugs, bracket fasteners, and PCIe retention latch.',
        'Release each power-plug catch and pull the housing, never the cable wires.',
        'Support the card while removing its bracket screws, then release the PCIe latch.',
        'Lift the card straight without twisting the slot and place it on the antistatic parts tray.',
      ],
      'GPU is free of cables and retainers and rests on the protected tray.',
      'The card is being pulled against its locked PCIe latch.',
    ),
    'storage_parts_tray': SimulationStepDetail(
      [
        'Label the SATA data and power leads before disconnecting them.',
        'Release any locking clip and pull each connector by its housing.',
        'Support the SSD while removing the mounting screws or tray retention.',
        'Remove the drive, protect its connectors, and record its label in the inventory.',
      ],
      'Drive and connectors are intact and its labelled fasteners are collected.',
      'A connector is still attached while the drive is lifted.',
    ),
    'psu_parts_tray': SimulationStepDetail(
      [
        'Confirm mains isolation and trace every internal power lead to its destination.',
        'Release the ATX, EPS, GPU, and drive power connections by their catches and housings.',
        'Support the PSU weight while removing its chassis screws.',
        'Lift the enclosed PSU clear and store its approved modular leads with it. Never open its enclosure.',
      ],
      'Enclosed PSU is removed with all leads released and retained together.',
      'A power lead is still attached or the PSU is unsupported.',
    ),
    'cooler_parts_tray': SimulationStepDetail(
      [
        'Identify and unplug the CPU fan lead without pulling its wires.',
        'Release mounting fasteners gradually in the manufacturer sequence.',
        'Use the approved release method for the thermal compound seal; do not pull a stuck cooler forcefully.',
        'Lift clear, protect the CPU and cooler contact surfaces, and prepare for correct cleaning before reinstallation.',
      ],
      'Cooler is free without damage to the processor or socket.',
      'Cooler remains bonded or a fastener is still engaged.',
    ),
    'ram_parts_tray': SimulationStepDetail(
      [
        'Identify the DIMM and the movable clips on this slot.',
        'Release both movable retaining clips in the training board.',
        'Hold the module by its edges and lift it evenly without touching contacts.',
        'Inspect the notch and contacts and store the module in antistatic packaging.',
      ],
      'Module is removed evenly with contacts protected.',
      'One retaining clip is still engaged or contacts are being touched.',
    ),
    'cpu_parts_tray': SimulationStepDetail(
      [
        'Inspect the exposed processor and identify the socket retention lever.',
        'Release the lever and open the load plate according to the socket design.',
        'Lift the processor vertically by its edges without contacting pins or pads.',
        'Place it in a protective holder and fit the socket protection according to the service instructions.',
      ],
      'Processor and socket contacts are undamaged and protected.',
      'Processor is dragged across contacts or stored without protection.',
    ),
    'motherboard_parts_tray': SimulationStepDetail(
      [
        'Identify and label front-panel, USB, audio, fan, and remaining board connections.',
        'Release every connection by its housing or retaining catch.',
        'Remove and count the mounting screws, then inspect the board edges for attached leads.',
        'Lift by the edges, clear the rear ports, and place the board on the antistatic work surface.',
      ],
      'Board is free with no attached leads and all mounting screws accounted for.',
      'A hidden screw or cable still holds the board.',
    ),
    'inventory_station': SimulationStepDetail(
      [
        'Inspect each removed component and connector for physical damage.',
        'Group and label fasteners by component and reconcile their counts.',
        'Package sensitive parts with ESD and contact protection.',
        'Record identifiers, condition, missing items, and the next authorized service action.',
      ],
      'All parts and fasteners are accounted for and safely stored.',
      'A component or fastener is missing or unprotected.',
    ),

    'motherboard_tray': SimulationStepDetail(
      [
        'Identify the motherboard by its CPU socket, DIMM slots, PCIe slots, and rear I/O. Compare its form factor with the case.',
        'With power isolated and ESD protection in place, match standoffs to mounting holes. Remove any standoff beneath an unmarked area.',
        'Fit the separate I/O shield if required. Lower the board without scraping its underside and align the rear ports.',
        'Start each mounting screw by hand, then tighten evenly until snug. Inspect for trapped cables and loose screws.',
      ],
      'Every installed standoff aligns with a mounting hole; the board is secure.',
      'An extra standoff touches the underside of the board.',
    ),
    'cpu_socket': SimulationStepDetail(
      [
        'Identify the processor by its heat spreader and alignment mark. Check socket compatibility before opening the retention mechanism.',
        'Hold the CPU by its edges. Align its triangle and notches with the socket markings.',
        'Lower the CPU vertically without pressure or sliding. Inspect that it rests flat.',
        'Close the retention plate and secure the lever according to the socket instructions. Keep the protective cover for later service.',
      ],
      'The compatible CPU sits flat with its alignment marks matched.',
      'The CPU is tilted or needs force to enter the socket.',
    ),
    'cpu_fan_mount': SimulationStepDetail(
      [
        'Identify the heatsink, fan lead, and mounting hardware. Check cooler and socket compatibility.',
        'Inspect the contact surface. Remove protective film; use the supplied thermal compound or the manufacturer amount if none is pre-applied.',
        'Lower the cooler squarely and engage the mounting points. Tighten gradually in the recommended pattern.',
        'Connect the fan to CPU_FAN and route its lead clear of the blades. Check that the cooler cannot rock.',
      ],
      'Cooler is secured evenly and its fan lead is on CPU_FAN.',
      'Protective film remains on the cooler or the fan lead is disconnected.',
    ),
    'ram_slot': SimulationStepDetail(
      [
        'Identify the memory generation from its label and keyed notch. Select the DDR4 module for this DDR4 training board.',
        'Use the board manual to choose the recommended DIMM slot. Open its movable retention clips.',
        'Align the notch with the slot key. Press evenly at both ends without bending the module.',
        'Inspect both ends at the same height and confirm the retention clips engage. Verify memory capacity at the final POST check.',
      ],
      'DDR4 module is level and its retention clips are engaged.',
      'One end is raised or the DDR5 notch does not match.',
    ),
    'pcie_slot': SimulationStepDetail(
      [
        'Identify the graphics card by its PCIe edge connector and display ports. Check slot and case clearance.',
        'Remove the matching expansion covers and open the PCIe x16 retention latch.',
        'Align the bracket and connector, then lower the card evenly until seated.',
        'Secure the bracket and required support. Identify its auxiliary power sockets for the cabling stage.',
      ],
      'Card is seated, retained, and supported at its bracket.',
      'Bracket is secured but the PCIe connector is only partly inserted.',
    ),
    'storage_bay': SimulationStepDetail(
      [
        'Identify this SATA SSD by its separate 7-pin data and 15-pin power connectors. Check the drive label and mounting size.',
        'Align the drive in the 2.5-inch tray with connectors accessible for cabling.',
        'Fit the correct screws without overtightening and secure the tray in the case.',
        'Check that the drive is held firmly and that data and power leads can reach without strain.',
      ],
      'SATA drive is secure with both connectors accessible.',
      'Drive is loose or a cable must be stretched to reach it.',
    ),
    'psu_mount': SimulationStepDetail(
      [
        'Identify the enclosed PSU, its rating, and the approved cables supplied for this exact PSU model.',
        'Keep mains disconnected. Orient the fan toward the intended filtered ventilation opening.',
        'Support the unit while securing its rear mounting screws. Do not open the PSU enclosure.',
        'Route the correct motherboard, CPU, GPU, and drive leads for the cabling stage. Never interchange modular leads from another PSU.',
      ],
      'PSU is secured, ventilation is clear, and its own approved cables are selected.',
      'A modular cable from a different PSU has been selected.',
    ),
    'assembly_test_station': SimulationStepDetail(
      [
        'Inspect all fasteners, power connections, fan clearance, and loose objects before closing the case.',
        'Connect the display to the intended graphics output and attach keyboard and mains power.',
        'Start the training system and observe fan operation, diagnostic LEDs, and POST messages.',
        'Enter firmware setup and compare CPU, memory capacity, and drive detection with the installed parts. Record any fault before shutdown.',
      ],
      'POST completes and firmware detects the intended CPU, RAM, and drive.',
      'Fans spin but POST fails or an installed component is missing.',
    ),
    'power_slot': SimulationStepDetail(
      [
        'Isolate mains power. Identify the ATX 24-pin lead by its connector size and latch.',
        'Route it through the nearest cable opening without blocking case fans.',
        'Align keyed cavities and latch with the motherboard socket; support the board while seating it.',
        'Inspect the full connector length for gaps and confirm the latch is engaged.',
      ],
      '24-pin connector is fully seated with the latch engaged.',
      'One side remains raised or the latch is outside its catch.',
    ),
    'cpu_power_slot': SimulationStepDetail(
      [
        'Read the EPS/CPU marking on the 4+4 lead. Compare it with the PCIe 6+2 lead before selecting.',
        'Route the lead to the CPU power header with mains disconnected.',
        'Join the required halves, align the keys, and press the connector straight into the header.',
        'Check its latch and make sure the cable cannot contact the CPU fan.',
      ],
      'EPS/CPU lead is latched in the CPU power header.',
      'PCIe power lead has been selected for the CPU header.',
    ),
    'gpu_power_slot': SimulationStepDetail(
      [
        'Inspect the graphics card power requirements and select the approved PCIe lead.',
        'Arrange the 6+2 sections for the card socket. Do not substitute the EPS/CPU lead.',
        'Seat the plug straight until the retention latch engages. Connect every required power socket.',
        'Check connector seating and leave sufficient bend clearance beside the card.',
      ],
      'Required GPU sockets are connected with approved PCIe leads.',
      'One required GPU power socket remains empty.',
    ),
    'sata_slot': SimulationStepDetail(
      [
        'Distinguish the narrow 7-pin SATA data connector from the wider 15-pin power connector.',
        'With power isolated, align the L-shaped key at the motherboard SATA port.',
        'Connect the other end to the SATA drive data port; supply drive power separately with its approved PSU lead.',
        'Route without sharp bends and inspect both data connections and any locking clips.',
      ],
      '7-pin data cable joins motherboard and drive; drive power is separate.',
      '15-pin power connector is being used as a data connector.',
    ),
    'front_panel_slot': SimulationStepDetail(
      [
        'Open the board header diagram and locate power switch, reset switch, power LED, and drive LED pins.',
        'Read each case lead label and match it to the documented pin pair.',
        'Connect switches to the correct pairs and LEDs with the indicated polarity.',
        'Inspect for a one-pin offset. During the final test, check each button and indicator separately.',
      ],
      'Each lead matches its documented pair and LEDs have correct polarity.',
      'A lead is offset by one pin or an LED is reversed.',
    ),
    'cable_test_station': SimulationStepDetail(
      [
        'Trace each lead from source to destination against the connection plan.',
        'Inspect latches, keyed plugs, LED polarity, strain, and clearance around every fan.',
        'Secure loose runs with reusable ties without crushing insulation. Fit the case panel without pinching cables.',
        'Perform a controlled startup and verify buttons, indicators, fans, storage detection, and display output.',
      ],
      'Cable routes are clear and all requested functions pass.',
      'A cable touches a fan or a front-panel control fails.',
    ),
    'modem_position': SimulationStepDetail(
      [
        'Identify the service handoff and the modem WAN and Ethernet connections.',
        'Connect the approved service lead to the modem input and its Ethernet output to the router WAN port.',
        'Apply power and observe the simulated service synchronization sequence.',
        'Check service and Ethernet indicators before moving to the router.',
      ],
      'Service is synchronized and Ethernet leads to router WAN.',
      'Ethernet is connected to the wrong interface or service is not synchronized.',
    ),
    'router_position': SimulationStepDetail(
      [
        'Identify WAN and LAN interfaces on the router. Label the upstream and downstream leads.',
        'Connect modem Ethernet to WAN and router LAN to the switch uplink.',
        'Apply the approved WAN configuration and LAN plan without creating a second unintended DHCP service.',
        'Inspect link indicators on both sides and trace the path from LAN toward the modem.',
      ],
      'WAN reaches the modem and LAN reaches the switch.',
      'WAN and LAN leads are reversed.',
    ),
    'switch_position': SimulationStepDetail(
      [
        'Identify the access switch and its documented uplink port.',
        'Connect the router LAN to the uplink and assign each endpoint its documented access port.',
        'Apply the intended VLAN settings when required. Avoid connecting a second unmanaged loop.',
        'Inspect link indicators and trace one endpoint through the switch to the router.',
      ],
      'Endpoints and uplink use the intended ports without an unintended loop.',
      'An endpoint is on the wrong VLAN or an unintended loop exists.',
    ),
    'pc_position': SimulationStepDetail(
      [
        'Identify the workstation network adapter and its assigned switch port.',
        'Connect a tested patch cable from the workstation to that access port.',
        'Enable the adapter and apply the addressing plan in the IP Configuration activity.',
        'Inspect link status and test the approved local service once addressing is ready.',
      ],
      'Workstation link is active on its assigned access port.',
      'Workstation link is down or connected to an incorrect port.',
    ),
    'server_position': SimulationStepDetail(
      [
        'Identify the server role and reserved network connection in the plan.',
        'Connect its network adapter to the designated switch port.',
        'Apply the reserved address and enable only the approved service.',
        'Test that service from an authorized workstation and record the result.',
      ],
      'Authorized workstation can reach the intended server service.',
      'Link is active but the required service cannot be reached.',
    ),
    'printer_position': SimulationStepDetail(
      [
        'Identify the printer Ethernet port and its address reservation in the plan.',
        'Connect it to the assigned switch port and wait for link status.',
        'Apply its reserved address and add the correct queue on the workstation.',
        'Send a test page and inspect both the queue status and printed result.',
      ],
      'The test page prints from the intended workstation queue.',
      'The queue remains stalled or sends to another printer.',
    ),
    'readiness_check': SimulationStepDetail(
      [
        'Compare the target device inventory against the approved operating system requirements.',
        'Select an authorized backup destination and copy the required user files.',
        'Open sample files from the backup and record the license and recovery information.',
        'Confirm stable power and identify disks that must remain untouched.',
      ],
      'Backup opens successfully and the intended device meets the requirements.',
      'Backup cannot be opened or a required capability is missing.',
    ),
    'boot_media': SimulationStepDetail(
      [
        'Select the approved operating system image and its trusted checksum reference.',
        'Compare the image checksum with the reference before writing the media.',
        'Identify the USB device by capacity and label; confirm it may be overwritten.',
        'Create compatible boot media and verify the target can read it in the boot menu.',
      ],
      'Image checksum matches and the USB appears as a bootable device.',
      'Checksum differs or the wrong USB device is selected.',
    ),
    'firmware_setup': SimulationStepDetail(
      [
        'Open firmware setup and record existing storage and boot settings.',
        'Select the firmware mode required by the deployment plan and verify required security capabilities.',
        'Avoid changing the storage controller mode on an existing installation without a migration plan.',
        'Save the approved settings and select the installation USB from the one-time boot menu.',
      ],
      'Approved USB boots in the intended firmware mode.',
      'The installer boots in a mode incompatible with the deployment plan.',
    ),
    'installer_setup': SimulationStepDetail(
      [
        'Choose the deployment language, region, and keyboard layout.',
        'Review the license and select the edition covered by the authorized entitlement.',
        'Enter the approved product key or use the authorized deferred activation path.',
        'Select the planned installation type and pause at disk selection to verify the target.',
      ],
      'Selected edition and installation type match the deployment plan.',
      'An edition without the required license is selected.',
    ),
    'storage_setup': SimulationStepDetail(
      [
        'Compare the disk model, capacity, and existing partitions with the deployment record.',
        'Confirm backup verification and explicit authorization before deleting any target partition.',
        'Preserve every non-target data disk. Select unallocated space on the authorized destination.',
        'Allow the installer to create its required system partitions and review the resulting layout.',
      ],
      'Only the authorized target disk is selected; protected data disks are intact.',
      'A protected data disk or unverified destination is selected.',
    ),
    'system_install': SimulationStepDetail(
      [
        'Start installation on the verified destination and observe file copy progress.',
        'Wait through expansion and component setup while maintaining stable power.',
        'Allow required restarts; avoid restarting from the USB when the internal installation should continue.',
        'Confirm that first-run configuration appears without returning to the initial installer.',
      ],
      'System reaches first-run configuration from the internal drive.',
      'The machine repeatedly returns to the USB installer.',
    ),
    'oobe_setup': SimulationStepDetail(
      [
        'Select the planned region, keyboard, and time zone.',
        'Connect to the approved network and enter the required device name.',
        'Create or enroll the authorized account using the organization policy.',
        'Review privacy and security settings, then verify sign-in and the desktop.',
      ],
      'Authorized account signs in with the intended device and regional settings.',
      'The account, device name, or regional settings do not match the plan.',
    ),
    'driver_install': SimulationStepDetail(
      [
        'Open the hardware inventory and identify unknown devices or warning indicators.',
        'Select drivers for the exact device model and operating system from the approved source.',
        'Install required chipset, storage, network, display, audio, and peripheral drivers; restart when requested.',
        'Reopen the device list and function-test the affected hardware.',
      ],
      'Required devices are recognized and pass functional checks.',
      'An unknown device or warning remains after installation.',
    ),
    'update_system': SimulationStepDetail(
      [
        'Verify the authorized activation status and resolve any entitlement mismatch.',
        'Check for approved system and security updates and begin installation.',
        'Restart when required and resume the update check.',
        'Inspect update history and protection definitions; record any unresolved failure.',
      ],
      'Required updates complete successfully and activation is valid.',
      'A required update failed or activation is unresolved.',
    ),
    'validation_stage': SimulationStepDetail(
      [
        'Restart from the internal drive and verify normal sign-in.',
        'Test storage, network, display, audio, ports, and installed devices.',
        'Inspect activation, security, and update status against the deployment checklist.',
        'Create the approved recovery baseline and document test results and remaining issues.',
      ],
      'All deployment checks pass and recovery information is recorded.',
      'An unresolved device, security, or boot failure remains.',
    ),
    'software_requirements': SimulationStepDetail(
      [
        'Open the client requirements and compare the requested applications and versions.',
        'Check device capacity, compatibility, licensing, and installation permissions.',
        'Select approved installation packages and verify their source and integrity.',
        'Record the required configuration and acceptance test for each application.',
      ],
      'Every selected package matches an authorized requirement and license.',
      'A package is unapproved, incompatible, or unlicensed.',
    ),
    'account_config': SimulationStepDetail(
      [
        'Open account management using authorized maintenance credentials.',
        'Create the named everyday account with standard-user privileges.',
        'Configure authentication and recovery according to the account policy.',
        'Sign in as that user and verify ordinary work succeeds while privileged changes require authorization.',
      ],
      'Everyday account is standard and privileged changes require authorization.',
      'The everyday account has unnecessary administrator privileges.',
    ),
    'security_config': SimulationStepDetail(
      [
        'Open security status and inspect firewall and malware protection.',
        'Enable the approved firewall profile and real-time protection.',
        'Update protection definitions and run the required scan.',
        'Inspect results and resolve alerts without disabling protection to hide them.',
      ],
      'Firewall and real-time protection are active with current definitions.',
      'Protection is disabled or an unresolved alert remains.',
    ),
    'application_install': SimulationStepDetail(
      [
        'Select a verified licensed application package from the approved list.',
        'Run its installer with authorized privileges and choose required components only.',
        'Apply the client configuration and update the application.',
        'Launch as the standard user, create a test document, save it, and reopen it.',
      ],
      'Application opens, saves, and reopens a test file as the standard user.',
      'Installation reports success but the application cannot perform its required task.',
    ),
    'peripheral_config': SimulationStepDetail(
      [
        'Join the approved network and verify the assigned network profile.',
        'Locate the assigned printer and install the matching approved driver.',
        'Add the intended queue and choose its required defaults.',
        'Print a test page and inspect the queue and physical output.',
      ],
      'Correct queue produces the requested test page.',
      'Job is stalled or is sent to an unintended printer.',
    ),
    'recovery_config': SimulationStepDetail(
      [
        'Run the client acceptance task in each installed application.',
        'Verify licenses, updates, network access, and peripheral operation.',
        'Create the approved restore or recovery baseline and verify it is listed.',
        'Document versions, settings, recovery location, and any approved deviations.',
      ],
      'Acceptance tasks pass and the recovery baseline is available.',
      'A required task fails or no usable recovery baseline is recorded.',
    ),
    'backup_stage': SimulationStepDetail(
      [
        'Identify the approved files and authorized backup destination.',
        'Check available capacity and access permissions before copying.',
        'Copy the required data and inspect the backup completion log.',
        'Open sample files from the backup destination and record verification.',
      ],
      'Backup is complete and sampled files open from the destination.',
      'Copy completed but the destination files cannot be opened.',
    ),
    'power_isolation': SimulationStepDetail(
      [
        'Close applications and shut down the operating system normally.',
        'Disconnect mains and external peripherals; isolate other power sources per the service manual.',
        'Follow the manufacturer residual-power procedure and connect approved ESD protection.',
        'Inspect the workspace and verify isolation before opening the case.',
      ],
      'Power sources are isolated and ESD precautions are in place.',
      'A power source remains connected.',
    ),
    'cleaning_stage': SimulationStepDetail(
      [
        'Inspect dust buildup with the equipment isolated and open according to its service instructions.',
        'Hold each fan stationary before using controlled air bursts.',
        'Clear vents and heatsink fins without spraying liquid or spinning fans with compressed air.',
        'Inspect for remaining debris, moisture, or displaced connectors before reassembly.',
      ],
      'Vents are clear, surfaces dry, and fans and connectors remain intact.',
      'Debris remains in a vent or a connector was displaced.',
    ),
    'inspection_stage': SimulationStepDetail(
      [
        'Trace power and data leads and inspect their insulation and connectors.',
        'Inspect fans, ports, mounting hardware, and visible board components.',
        'Record looseness, heat discoloration, swelling, or mechanical damage.',
        'Escalate unsafe damage and replace only authorized parts before functional testing.',
      ],
      'No unresolved physical damage or loose connection remains.',
      'Heat damage or a loose connection remains unaddressed.',
    ),
    'software_service': SimulationStepDetail(
      [
        'Reassemble and reconnect safely before starting software maintenance.',
        'Install approved updates and perform the required malware scan.',
        'Inspect storage health reports and startup entries against the approved baseline.',
        'Record warnings and confirm normal startup without removing required services.',
      ],
      'Service checks finish with no unresolved health or protection warning.',
      'A storage warning or unresolved malware alert remains.',
    ),
    'verification_stage': SimulationStepDetail(
      [
        'Check reassembly, cable routing, and enclosure closure before applying power.',
        'Test startup, cooling, storage, network, and required peripherals.',
        'Compare observed behavior with the pre-service symptom and baseline.',
        'Record work, test evidence, and client confirmation or follow-up needs.',
      ],
      'Functional checks pass and service evidence is documented.',
      'The original problem remains or a new fault appears.',
    ),
    'check_psu': SimulationStepDetail(
      [
        'Ask the user when the fault occurs and what changed before it began.',
        'Record the exact message, indicator, sound, or failure behavior.',
        'Reproduce the symptom safely without risking unsaved data.',
        'State the observed symptom separately from any suspected cause.',
      ],
      'Symptom and reproduction conditions are documented.',
      'A component is blamed before the symptom is reproduced or recorded.',
    ),
    'check_display': SimulationStepDetail(
      [
        'Review the symptom and recent hardware or software changes.',
        'Inspect simple external causes such as power, display input, and loose leads.',
        'Rank plausible causes by evidence and choose one testable theory.',
        'Define the observation that would support or reject that theory.',
      ],
      'A specific theory has a test with a measurable expected result.',
      'Several parts are replaced without testing a specific theory.',
    ),
    'check_cooling': SimulationStepDetail(
      [
        'Choose an approved diagnostic tool suitable for the suspected fault.',
        'Record the baseline before changing one controlled variable.',
        'Run the test and compare its output with the expected result.',
        'Accept or reject the theory; if rejected, restore the baseline and test the next supported cause.',
      ],
      'One controlled test provides evidence for or against the theory.',
      'Multiple variables changed, so the result cannot isolate the cause.',
    ),
    'check_resources': SimulationStepDetail(
      [
        'Confirm the cause from diagnostic evidence and obtain required repair authorization.',
        'Protect client data and isolate power before hardware service.',
        'Apply the targeted repair using compatible parts or the approved configuration.',
        'Reassemble safely and record exactly what changed.',
      ],
      'Repair addresses the confirmed cause and the change is recorded.',
      'Unrelated parts or settings changed without evidence.',
    ),
    'check_boot': SimulationStepDetail(
      [
        'Repeat the exact action that originally caused the fault.',
        'Run full functional checks to detect side effects of the repair.',
        'Compare before-and-after results and confirm with the user.',
        'Document symptom, cause, repair, test evidence, and prevention advice.',
      ],
      'Original symptom is resolved and full functional checks pass.',
      'The original fault persists despite a successful power-on.',
    ),
    'physical_layer': SimulationStepDetail(
      [
        'Inspect both cable ends, plug retention, and the assigned switch port.',
        'Observe link indicators and adapter enabled status.',
        'Test with an approved known-good cable or port, changing one variable at a time.',
        'Record whether link state changed before moving to addressing checks.',
      ],
      'Physical link is active at the intended adapter and switch port.',
      'Link remains down or is on the wrong switch port.',
    ),
    'address_layer': SimulationStepDetail(
      [
        'Open the adapter configuration report and identify the active interface.',
        'Compare IPv4 address, mask, gateway, and DNS with the approved network plan.',
        'Inspect DHCP state and duplicate-address warnings.',
        'Correct the confirmed mismatch and read back the applied configuration.',
      ],
      'Active adapter configuration matches the plan with no duplicate address.',
      'Mask, gateway, or address differs from the plan.',
    ),
    'local_stack': SimulationStepDetail(
      [
        'Open the training command console and select the local TCP/IP test.',
        'Run ping 127.0.0.1 and observe the simulated replies.',
        'Record whether the local stack responds; this test does not prove cable or gateway connectivity.',
        'Continue to external reachability only after interpreting this local result.',
      ],
      'Loopback replies confirm local stack response only.',
      'Loopback success is treated as proof that the Internet works.',
    ),
    'gateway_test': SimulationStepDetail(
      [
        'Read the configured gateway from the active adapter report.',
        'Send a simulated ping to that gateway and observe replies or timeouts.',
        'Compare the result with link, VLAN, subnet, and firewall evidence; a timeout alone does not prove the router is faulty.',
        'Record evidence and test the intended service using the approved method.',
      ],
      'Gateway result is interpreted together with configuration and filtering evidence.',
      'A timeout alone is used to declare the router broken.',
    ),
    'dns_test': SimulationStepDetail(
      [
        'Test an approved service by its known IP address.',
        'Query that service name using the configured DNS server.',
        'Compare the returned address with the expected record.',
        'If IP access works but lookup fails, investigate DNS settings and service separately from the physical link.',
      ],
      'Name resolves to the expected address and the intended service responds.',
      'IP access works but name resolution fails or returns the wrong address.',
    ),
    'service_test': SimulationStepDetail(
      [
        'Open the required application and connect to the intended service.',
        'Perform the actual user task rather than relying only on ping.',
        'Retest the original failure and confirm the approved fix.',
        'Document the fault, evidence, configuration change, and end-to-end result.',
      ],
      'The original application task succeeds after the documented fix.',
      'Ping responds but the required application task still fails.',
    ),
  };
}
