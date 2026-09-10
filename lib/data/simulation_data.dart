import '../models/simulation_model.dart';

class SimulationData {
  static DraggableItem _item({
    required String id,
    required String name,
    required String description,
    required String imageUrl,
    required String correctSlot,
    required String category,
    required int step,
    required String tooltip,
    String specification = '',
    bool isRequired = true,
  }) => DraggableItem(
    id: id,
    name: name,
    description: description,
    imageUrl: imageUrl,
    correctSlot: correctSlot,
    category: category,
    step: step,
    tooltip: tooltip,
    specification: specification,
    isRequired: isRequired,
  );

  static Simulation _simulation({
    required String id,
    required String title,
    required String description,
    required String type,
    required String competency,
    required String learningOutcome,
    required List<DraggableItem> items,
    required int timeLimit,
    required String? requiredSimulationId,
  }) {
    final now = DateTime.now();
    return Simulation(
      id: id,
      title: title,
      description: description,
      type: type,
      competency: competency,
      learningOutcome: learningOutcome,
      items: items,
      slots: items.map((item) => item.correctSlot).toSet().toList(),
      timeLimit: timeLimit,
      passingScore: 80,
      isPublished: true,
      isLocked: false,
      requiredSimulationId: requiredSimulationId,
      createdAt: now,
      updatedAt: now,
    );
  }

  static Simulation getPcAssembly() => _simulation(
    id: 'sim_coc1_assembly',
    title: 'PC Assembly - COC1',
    description:
        'Assemble a computer system by placing components in the correct installation order.',
    type: 'assembly',
    competency: 'COC1',
    learningOutcome: 'LO1 - Assemble computer hardware',
    timeLimit: 15,
    requiredSimulationId: null,
    items: [
      _item(
        id: 'motherboard',
        name: 'Motherboard',
        description: 'Main circuit board - install first in the case',
        imageUrl: 'assets/simulations/assembly-motherboard-matched.png',
        correctSlot: 'motherboard_tray',
        category: 'motherboard',
        step: 1,
        tooltip: 'Install standoffs before mounting the motherboard.',
      ),
      _item(
        id: 'cpu',
        name: 'CPU',
        description: 'Central Processing Unit - align the gold triangle',
        imageUrl: 'assets/simulations/assembly-cpu-matched.png',
        correctSlot: 'cpu_socket',
        category: 'processor',
        step: 2,
        tooltip: 'Match the CPU triangle with the socket indicator.',
      ),
      _item(
        id: 'cpu_fan',
        name: 'CPU Cooler',
        description: 'Attach after CPU installation',
        imageUrl: 'assets/simulations/assembly-cooler-matched.png',
        correctSlot: 'cpu_fan_mount',
        category: 'cooling',
        step: 3,
        tooltip: 'Apply thermal paste before attaching the cooler.',
      ),
      _item(
        id: 'ram',
        name: 'RAM',
        description: 'Random Access Memory - align the notch',
        imageUrl: 'assets/simulations/assembly-ram-ddr4-matched.png',
        correctSlot: 'ram_slot',
        category: 'memory',
        step: 4,
        tooltip: 'Press firmly until the clips click.',
        specification: 'DDR4-3200 UDIMM • 288-pin • 1.2 V',
      ),
      _item(
        id: 'ram_ddr5_distractor',
        name: 'DDR5 Memory',
        description: 'Newer-generation DIMM with a different notch and voltage',
        imageUrl: 'assets/simulations/ddr5-memory-incompatible-matched.png',
        correctSlot: 'ddr5_memory_slot',
        category: 'memory',
        step: 0,
        tooltip:
            'DDR5 cannot fit a DDR4 socket. The key notch and electrical design are different.',
        specification:
            'DDR5-5600 UDIMM • 288-pin • 1.1 V • incompatible with DDR4',
        isRequired: false,
      ),
      _item(
        id: 'gpu',
        name: 'GPU',
        description: 'Graphics card - install in the PCIe x16 slot',
        imageUrl: 'assets/simulations/assembly-gpu-matched.png',
        correctSlot: 'pcie_slot',
        category: 'graphics',
        step: 5,
        tooltip: 'Secure the bracket with screws.',
      ),
      _item(
        id: 'ssd',
        name: 'SSD Storage',
        description: 'Fast storage for the operating system and apps',
        imageUrl: 'assets/simulations/assembly-ssd-matched.png',
        correctSlot: 'storage_bay',
        category: 'storage',
        step: 6,
        tooltip: 'Mount in the drive bay or M.2 slot.',
      ),
      _item(
        id: 'psu',
        name: 'Power Supply',
        description: 'Install last and connect all cables',
        imageUrl: 'assets/simulations/assembly-psu-matched.png',
        correctSlot: 'psu_mount',
        category: 'power',
        step: 7,
        tooltip: 'Face the fan toward the case ventilation.',
      ),
      _item(
        id: 'assembly_test',
        name: 'POST and Inspection',
        description: 'Inspect the assembly and verify safe initial operation',
        imageUrl: 'assets/simulations/check.svg',
        correctSlot: 'assembly_test_station',
        category: 'diagnostic',
        step: 8,
        tooltip:
            'Check clearances, fasteners, and connections before power-on. Confirm POST, fan operation, hardware detection, and document the result.',
        specification:
            'TESDA evidence: assembled hardware • safe operation • testing and documentation',
      ),
    ],
  );

  static Simulation getCableManagement() => _simulation(
    id: 'sim_coc1_cabling',
    title: 'Cable Management - COC1',
    description:
        'Connect each cable to its correct location for reliable power and airflow.',
    type: 'cabling',
    competency: 'COC1',
    learningOutcome: 'LO1 - Assemble computer hardware',
    timeLimit: 10,
    requiredSimulationId: 'sim_coc1_assembly',
    items: [
      _item(
        id: 'power_cable',
        name: '24-pin Motherboard Cable',
        description: 'Main motherboard power connector',
        imageUrl: 'assets/simulations/cable-atx-24pin.png',
        correctSlot: 'power_slot',
        category: 'cable',
        step: 1,
        tooltip: 'The largest connector from the PSU.',
        specification: 'ATX 24-pin • motherboard main power • keyed latch',
      ),
      _item(
        id: 'cpu_power',
        name: '4+4 pin CPU Cable',
        description: 'Provides power to the CPU',
        imageUrl: 'assets/simulations/cable-cpu-4plus4.png',
        correctSlot: 'cpu_power_slot',
        category: 'cable',
        step: 2,
        tooltip: 'Connect near the CPU socket.',
        specification: 'EPS12V 4+4 pin • CPU power • rounded/square keying',
      ),
      _item(
        id: 'gpu_power',
        name: '6+2 pin PCIe Cable',
        description: 'Provides power to the graphics card',
        imageUrl: 'assets/simulations/cable-gpu-6plus2.png',
        correctSlot: 'gpu_power_slot',
        category: 'cable',
        step: 3,
        tooltip: 'High-end GPUs may require multiple cables.',
        specification: 'PCIe 6+2 pin • GPU auxiliary power • not EPS12V',
      ),
      _item(
        id: 'sata_cable',
        name: 'SATA Data Cable',
        description: 'Connects storage drives to the motherboard',
        imageUrl: 'assets/simulations/cable-sata-power-15pin-matched.png',
        correctSlot: 'sata_slot',
        category: 'cable',
        step: 4,
        tooltip: 'The L-shaped connector fits one way.',
        specification: 'SATA 7-pin data • L-shaped key • not SATA power',
      ),
      _item(
        id: 'front_panel',
        name: 'Front Panel Connectors',
        description: 'Connects power, reset, and LED controls',
        imageUrl: 'assets/simulations/cable-front-panel.png',
        correctSlot: 'front_panel_slot',
        category: 'cable',
        step: 5,
        tooltip: 'Use the motherboard manual for the pin layout.',
        specification: 'F_PANEL header • polarity matters for LEDs',
      ),
      _item(
        id: 'cable_inspection',
        name: 'Cable Inspection and Test',
        description: 'Verify routing, locking tabs, polarity, and operation',
        imageUrl: 'assets/simulations/check.svg',
        correctSlot: 'cable_test_station',
        category: 'diagnostic',
        step: 6,
        tooltip:
            'Inspect every keyed connector and latch, keep cables clear of fans, then perform a controlled power-on test and record the result.',
        specification:
            'TESDA evidence: manufacturer requirements • OHS • inspection and testing',
      ),
      _item(
        id: 'sata_power_distractor',
        name: 'SATA Power Cable',
        description: '15-pin PSU power connector for SATA drives',
        imageUrl: 'assets/simulations/cable-sata-data.png',
        correctSlot: 'sata_power_device',
        category: 'cable',
        step: 0,
        tooltip:
            'This is a 15-pin power lead, not the 7-pin motherboard data cable.',
        specification:
            'SATA 15-pin power • PSU to drive • incompatible with SATA data port',
        isRequired: false,
      ),
    ],
  );

  static Simulation getHardwareIdentification() => _simulation(
    id: 'sim_coc1_identification',
    title: 'Hardware Identification - COC1',
    description:
        'Identify each computer component by placing its label on the correct target.',
    type: 'identification',
    competency: 'COC1',
    learningOutcome: 'LO1 - Identify computer parts',
    timeLimit: 8,
    requiredSimulationId: 'sim_coc1_assembly',
    items: [
      _item(
        id: 'cpu_label',
        name: 'CPU',
        description: 'The brain of the computer',
        imageUrl: 'assets/simulations/cpu.jpg',
        correctSlot: 'cpu_target',
        category: 'identification',
        step: 1,
        tooltip:
            'Look for a compact square package, metal heat spreader, corner alignment triangle, and underside contact pads.',
        specification:
            'Recognition markers: socket-keyed package • no edge connector • requires heatsink',
      ),
      _item(
        id: 'ram_label',
        name: 'RAM',
        description: 'Temporary memory for running programs',
        imageUrl: 'assets/simulations/ram.jpg',
        correctSlot: 'ram_target',
        category: 'identification',
        step: 2,
        tooltip:
            'Look for a long narrow PCB, multiple memory ICs, one keyed notch, and gold edge contacts.',
        specification:
            'Recognition markers: DIMM form factor • edge connector • retaining-clip notches',
      ),
      _item(
        id: 'gpu_label',
        name: 'GPU',
        description: 'Processes graphics and video output',
        imageUrl: 'assets/simulations/gpu.jpg',
        correctSlot: 'gpu_target',
        category: 'identification',
        step: 3,
        tooltip:
            'Inspect the cooling fans, PCIe edge connector, rear display outputs, and auxiliary power socket.',
        specification:
            'Recognition markers: PCIe expansion card • video outputs • large cooler',
      ),
      _item(
        id: 'motherboard_label',
        name: 'Motherboard',
        description: 'Main circuit board connecting components',
        imageUrl: 'assets/simulations/motherboard.jpg',
        correctSlot: 'motherboard_target',
        category: 'identification',
        step: 4,
        tooltip:
            'Identify the CPU socket, DIMM banks, PCIe slots, chipset heatsink, and rear I/O cluster on one board.',
        specification:
            'Recognition markers: main system PCB • multiple buses • power and I/O headers',
      ),
      _item(
        id: 'ssd_label',
        name: 'SSD',
        description: 'Fast storage for files and the operating system',
        imageUrl: 'assets/simulations/ssd.jpg',
        correctSlot: 'storage_target',
        category: 'identification',
        step: 5,
        tooltip:
            'Look for a compact drive enclosure with no cooling fan and SATA data/power connectors along one edge.',
        specification:
            'Recognition markers: non-volatile storage • 2.5-inch form factor • SATA interface',
      ),
      _item(
        id: 'psu_label',
        name: 'PSU',
        description: 'Converts AC power to DC power',
        imageUrl: 'assets/simulations/psu.jpg',
        correctSlot: 'psu_target',
        category: 'identification',
        step: 6,
        tooltip:
            'Inspect the metal enclosure, AC input, cooling fan, wattage label, and bundled DC power leads.',
        specification:
            'Recognition markers: AC-to-DC converter • ATX enclosure • multiple voltage rails',
      ),
    ],
  );

  static Simulation getNetworkTopology() => _simulation(
    id: 'sim_coc2_topology',
    title: 'Network Topology - COC2',
    description:
        'Build a functional network by placing devices in their correct positions.',
    type: 'networking',
    competency: 'COC2',
    learningOutcome: 'LO1 - Install network cables',
    timeLimit: 12,
    requiredSimulationId: 'sim_coc1_identification',
    items: [
      _item(
        id: 'router',
        name: 'Router',
        description: 'Routes data between networks',
        imageUrl: 'assets/simulations/coc2-router-matched.png',
        correctSlot: 'router_position',
        category: 'network',
        step: 2,
        tooltip: 'Connects the local network to the ISP.',
      ),
      _item(
        id: 'switch',
        name: 'Network Switch',
        description: 'Connects devices in one network',
        imageUrl: 'assets/simulations/coc2-switch-matched.png',
        correctSlot: 'switch_position',
        category: 'network',
        step: 3,
        tooltip: 'Distributes connections to local devices.',
      ),
      _item(
        id: 'pc',
        name: 'Computer',
        description: 'End-user device on the network',
        imageUrl: 'assets/simulations/coc2-workstation-matched.png',
        correctSlot: 'pc_position',
        category: 'network',
        step: 4,
        tooltip: 'A workstation or client device.',
      ),
      _item(
        id: 'server',
        name: 'Server',
        description: 'Provides services to network devices',
        imageUrl: 'assets/simulations/coc2-server-matched.png',
        correctSlot: 'server_position',
        category: 'network',
        step: 5,
        tooltip: 'Provides centralized resources.',
      ),
      _item(
        id: 'printer',
        name: 'Network Printer',
        description: 'Shared printing device',
        imageUrl: 'assets/simulations/coc2-printer-matched.png',
        correctSlot: 'printer_position',
        category: 'network',
        step: 6,
        tooltip: 'Available to authorized network users.',
      ),
      _item(
        id: 'modem',
        name: 'Modem',
        description: 'Connects the network to the ISP',
        imageUrl: 'assets/simulations/coc2-modem-matched.png',
        correctSlot: 'modem_position',
        category: 'network',
        step: 1,
        tooltip: 'The first device in the Internet connection chain.',
      ),
    ],
  );

  static Simulation getRj45Crimping() => _simulation(
    id: 'sim_coc2_crimping',
    title: 'RJ45 Cable Crimping - COC2',
    description:
        'Prepare both cable ends: strip the jacket, remove the spline, untwist, arrange, trim, insert and crimp. Manually connect the LAN tester to check straight-through or 10/100 crossover wiring.',
    type: 'cabling',
    competency: 'COC2',
    learningOutcome: 'LO1 - Install network cables',
    timeLimit: 10,
    requiredSimulationId: 'sim_coc2_topology',
    items: List.generate(8, (index) {
      final pin = index + 1;
      const colors = [
        'White/Orange',
        'Orange',
        'White/Green',
        'Blue',
        'White/Blue',
        'Green',
        'White/Brown',
        'Brown',
      ];
      return _item(
        id: 'wire$pin',
        name: '${colors[index]} (Pin $pin)',
        description: 'T568B wire for pin $pin',
        imageUrl: 'assets/simulations/coc2-t568b-pin$pin-matched.png',
        correctSlot: 'pin$pin',
        category: 'cable',
        step: pin,
        tooltip: 'T568B standard: ${colors[index]}.',
      );
    }),
  );

  static Simulation getIpConfiguration() => _simulation(
    id: 'sim_coc2_ipconfig',
    title: 'IP Configuration - COC2',
    description:
        'Assign the correct IP addresses to each device in the network.',
    type: 'networking',
    competency: 'COC2',
    learningOutcome: 'LO3 - Set-up network protocols',
    timeLimit: 10,
    requiredSimulationId: 'sim_coc2_topology',
    items: [
      _ip('ip_pc1', 'PC 1: 192.168.1.10', 'pc1_ip', 1),
      _ip('ip_pc2', 'PC 2: 192.168.1.11', 'pc2_ip', 2),
      _ip('ip_pc3', 'PC 3: 192.168.1.12', 'pc3_ip', 3),
      _ip('ip_server', 'Server: 192.168.1.1', 'server_ip', 4),
      _ip('ip_router', 'Router: 192.168.1.254', 'router_ip', 5),
    ],
  );

  static Simulation getOperatingSystemInstallation() => _procedureSimulation(
    id: 'sim_coc1_os_install',
    title: 'Operating System Installation - COC1',
    description:
        'Complete a professional clean installation from readiness checks and UEFI setup through drivers, updates, activation, and final validation.',
    competency: 'COC1',
    outcome: 'LO2 - Install operating system and device drivers',
    prerequisite: 'sim_coc1_cabling',
    visual: 'assets/simulations/laptop.svg',
    steps: const [
      (
        'Readiness and Backup',
        'readiness_check',
        'Confirm CPU, RAM, storage, TPM, and firmware requirements. Back up approved user data, record the license, and verify stable AC power before changing the disk.',
      ),
      (
        'Verified Installation Media',
        'boot_media',
        'Download the approved ISO from a trusted source, verify its checksum, create a UEFI-compatible bootable USB, and test that the media is readable.',
      ),
      (
        'UEFI Firmware Setup',
        'firmware_setup',
        'Use UEFI mode with GPT support, confirm AHCI where required, enable TPM and Secure Boot when supported, then choose the USB from the one-time boot menu.',
      ),
      (
        'Installer and Edition',
        'installer_setup',
        'Choose the correct language and keyboard, start the clean installation, enter or defer the product key correctly, and select the licensed OS edition.',
      ),
      (
        'GPT Disk Partitioning',
        'storage_setup',
        'Identify the destination drive by model and capacity. Delete only authorized partitions, preserve required data drives, and create the EFI, MSR, recovery, and primary layout.',
      ),
      (
        'Install System Files',
        'system_install',
        'Allow copying, expansion, feature installation, and automatic restarts to finish. Do not remove power; remove the USB or restore boot priority before the installer loops.',
      ),
      (
        'Out-of-Box Configuration',
        'oobe_setup',
        'Set the correct region, keyboard, network policy, device name, authorized account, password, privacy options, and time zone according to the deployment plan.',
      ),
      (
        'Drivers and Device Check',
        'driver_install',
        'Install OEM chipset and storage drivers first, then network, graphics, audio, and peripherals. Check Device Manager for unknown devices or warning symbols.',
      ),
      (
        'Updates and Activation',
        'update_system',
        'Activate using the authorized license, install all cumulative and security updates, restart as requested, update protection definitions, and scan again for updates.',
      ),
      (
        'Final Validation',
        'validation_stage',
        'Verify activation, boot behavior, storage, network, audio, display, ports, security status, and updates. Create a restore point and document the completed installation.',
      ),
    ],
  );

  static Simulation getSoftwareConfiguration() => _procedureSimulation(
    id: 'sim_coc1_software_config',
    title: 'Software Configuration - COC1',
    description:
        'Configure accounts, protection, approved applications, peripherals, and recovery controls.',
    competency: 'COC1',
    outcome: 'LO3 - Install and configure application software',
    prerequisite: 'sim_coc1_os_install',
    visual: 'assets/simulations/software-config-requirements-matched.png',
    stepVisuals: const [
      'assets/simulations/software-config-requirements-matched.png',
      'assets/simulations/software-config-accounts-matched.png',
      'assets/simulations/software-config-security-matched.png',
      'assets/simulations/software-config-applications-matched.png',
      'assets/simulations/software-config-network-printer-matched.png',
      'assets/simulations/software-config-recovery-matched.png',
    ],
    steps: const [
      (
        'Review Client Requirements',
        'software_requirements',
        'Confirm the authorized software list, versions, licenses, system requirements, installation source, and required configuration before making changes.',
      ),
      (
        'Standard User Account',
        'account_config',
        'Create a named standard account and reserve administrator rights for authorized maintenance.',
      ),
      (
        'Firewall and Antivirus',
        'security_config',
        'Enable the firewall, update malware definitions, and verify real-time protection.',
      ),
      (
        'Required Applications',
        'application_install',
        'Install only licensed client-required software from trusted sources and verify each launch.',
      ),
      (
        'Network and Printer',
        'peripheral_config',
        'Join the approved network, test connectivity, then add and print-test the assigned printer.',
      ),
      (
        'Test, Restore, and Document',
        'recovery_config',
        'Launch and function-test each application and peripheral, confirm updates and licenses, create a restore point, and document the final configuration and variations.',
      ),
    ],
  );

  static Simulation getPreventiveMaintenance() => _procedureSimulation(
    id: 'sim_coc1_maintenance',
    title: 'Preventive Maintenance - COC1',
    description:
        'Protect client data, service hardware and software safely, and verify normal operation.',
    competency: 'COC1',
    outcome: 'LO4 - Maintain computer hardware and software',
    prerequisite: 'sim_coc1_software_config',
    visual: 'assets/simulations/steps.svg',
    steps: const [
      (
        'Back Up Client Data',
        'backup_stage',
        'Confirm the backup destination, copy critical client files, and verify that the backup opens.',
      ),
      (
        'Shut Down and Unplug',
        'power_isolation',
        'Shut down correctly, disconnect power and peripherals, discharge residual power, and use ESD protection.',
      ),
      (
        'Clean Components',
        'cleaning_stage',
        'Hold fan blades stationary and remove dust using controlled compressed air; never use a household vacuum.',
      ),
      (
        'Inspect Cables and Parts',
        'inspection_stage',
        'Check connectors, capacitors, fans, ports, and cable insulation for looseness, heat damage, or wear.',
      ),
      (
        'Update and Scan',
        'software_service',
        'Apply approved updates, scan for malware, inspect storage health, and remove unnecessary startup items.',
      ),
      (
        'Document and Test',
        'verification_stage',
        'Reconnect equipment, run functional tests, record observations, and obtain client confirmation.',
      ),
    ],
  );

  static Simulation getComputerTroubleshooting() => _procedureSimulation(
    id: 'sim_coc1_repair',
    title: 'Computer Troubleshooting and Repair - COC1',
    description:
        'Follow a safe evidence-based diagnostic sequence before replacing components.',
    competency: 'COC1',
    outcome: 'LO5 - Diagnose and repair computer systems',
    prerequisite: 'sim_coc1_maintenance',
    visual: 'assets/simulations/support.svg',
    steps: const [
      (
        'Identify the Symptom',
        'check_psu',
        'Interview the user, reproduce the fault safely, and record exact symptoms and error messages.',
      ),
      (
        'Establish a Theory',
        'check_display',
        'Start with simple likely causes such as power, cables, seating, settings, or recent changes.',
      ),
      (
        'Test the Theory',
        'check_cooling',
        'Use observation and approved diagnostic tools; change only one variable at a time.',
      ),
      (
        'Apply the Repair',
        'check_resources',
        'Repair or replace only the confirmed cause while protecting client data and observing ESD safety.',
      ),
      (
        'Verify and Document',
        'check_boot',
        'Test full system operation, confirm the original symptom is gone, and document the resolution.',
      ),
    ],
  );

  static Simulation getConnectivityDiagnostics() => _procedureSimulation(
    id: 'sim_coc2_diagnostics',
    title: 'Network Connectivity Diagnostics - COC2',
    description:
        'Diagnose physical, addressing, gateway, DNS, and service faults from the lowest layer upward.',
    competency: 'COC2',
    outcome: 'LO4 - Test and troubleshoot network connectivity',
    prerequisite: 'sim_coc2_ipconfig',
    visual: 'assets/simulations/coc2-diagnostic-laptop-matched.png',
    steps: const [
      (
        'Check Link and Cable',
        'physical_layer',
        'Inspect RJ45 termination, cable condition, link lights, adapter status, and the assigned switch port.',
      ),
      (
        'Check IP Configuration',
        'address_layer',
        'Verify IP address, prefix or subnet mask, default gateway, DHCP status, and duplicate addresses.',
      ),
      (
        'Ping Loopback',
        'local_stack',
        'Ping 127.0.0.1 to confirm the local TCP/IP stack before testing the network adapter.',
      ),
      (
        'Ping Default Gateway',
        'gateway_test',
        'Test the local gateway; failure indicates a local configuration, cable, VLAN, or switch issue.',
      ),
      (
        'Test DNS Resolution',
        'dns_test',
        'Compare access by IP address with name lookup to isolate a DNS configuration or service fault.',
      ),
      (
        'Verify Service and Document',
        'service_test',
        'Confirm the required application service, retest end-to-end connectivity, and record the cause and fix.',
      ),
    ],
  );

  static Simulation _procedureSimulation({
    required String id,
    required String title,
    required String description,
    required String competency,
    required String outcome,
    required String prerequisite,
    required String visual,
    List<String>? stepVisuals,
    required List<(String, String, String)> steps,
  }) => _simulation(
    id: id,
    title: title,
    description: description,
    type: 'procedure',
    competency: competency,
    learningOutcome: outcome,
    timeLimit: 12,
    requiredSimulationId: prerequisite,
    items: [
      for (var index = 0; index < steps.length; index++)
        _item(
          id: '${id}_$index',
          name: steps[index].$1,
          description: steps[index].$3,
          imageUrl: stepVisuals?[index] ?? visual,
          correctSlot: steps[index].$2,
          category: id.contains('repair') || id.contains('diagnostics')
              ? 'diagnostic'
              : 'procedure',
          step: index + 1,
          tooltip: steps[index].$3,
        ),
    ],
  );
  static DraggableItem _ip(String id, String name, String slot, int step) =>
      _item(
        id: id,
        name: name,
        description: 'Assign this address to the correct network device',
        imageUrl: switch (id) {
          'ip_server' => 'assets/simulations/coc2-server-matched.png',
          'ip_router' => 'assets/simulations/coc2-router-matched.png',
          _ => 'assets/simulations/coc2-workstation-matched.png',
        },
        correctSlot: slot,
        category: 'network',
        step: step,
        tooltip: 'Keep all devices on the same private subnet.',
      );

  static Simulation getComputerAssembly() => getPcAssembly();
  static Simulation getNetworkSetup() => getNetworkTopology();

  static List<Simulation> getAllSimulations() => [
    getPcAssembly(),
    getCableManagement(),
    getHardwareIdentification(),
    getOperatingSystemInstallation(),
    getSoftwareConfiguration(),
    getPreventiveMaintenance(),
    getComputerTroubleshooting(),
    getNetworkTopology(),
    getRj45Crimping(),
    getIpConfiguration(),
    getConnectivityDiagnostics(),
  ];

  static List<Simulation> getSimulationsByCompetency(String competency) =>
      getAllSimulations().where((sim) => sim.competency == competency).toList();

  static Simulation? getSimulationById(String id) {
    for (final simulation in getAllSimulations()) {
      if (simulation.id == id) return simulation;
    }
    return null;
  }

  static List<Simulation> getSimulationsByLearningOutcome(
    String learningOutcome,
  ) => getAllSimulations()
      .where((sim) => sim.learningOutcome.contains(learningOutcome))
      .toList();

  static List<Simulation> getPrerequisiteChain(String simulationId) {
    final chain = <Simulation>[];
    var current = getSimulationById(simulationId);
    final visited = <String>{};
    while (current?.requiredSimulationId != null && visited.add(current!.id)) {
      final prerequisite = getSimulationById(current.requiredSimulationId!);
      if (prerequisite == null) break;
      chain.insert(0, prerequisite);
      current = prerequisite;
    }
    return chain;
  }
}
