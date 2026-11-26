enum SetupLabKind { operatingSystem, software, network }

class GuidedSetupData {
  static String sceneAsset(SetupLabKind kind) => switch (kind) {
    SetupLabKind.operatingSystem =>
      'assets/simulations/coc1-boot-media-profiles-v1.png',
    SetupLabKind.software =>
      'assets/simulations/setup-software-workstation-v1.png',
    SetupLabKind.network =>
      'assets/simulations/coc2-three-device-network-v1.png',
  };
  static SetupLabKind? kindForId(String id) => switch (id) {
    'sim_coc1_os_install' => SetupLabKind.operatingSystem,
    'sim_coc1_software_config' => SetupLabKind.software,
    'sim_coc2_network_setup' => SetupLabKind.network,
    _ => null,
  };
  static const os = <(String, String)>[
    (
      'Connect preparation USB',
      'Drag the training USB into the preparation PC. The approved ISO is stored on this PC; writing the USB will erase its old contents.',
    ),
    (
      'Choose deployment profile and ISO',
      'Select the assigned deployment profile first. Use PowerISO with the legacy BIOS Windows 7/Server 2008 R2 worksheet, or Rufus with the modern UEFI practice profile. Do not mix settings between profiles.',
    ),
    (
      'Create and verify bootable USB',
      'Match the media settings to the selected target: MBR/legacy BIOS for the worksheet profile or GPT/UEFI for modern practice. Confirm the correct USB, start writing, and wait for completion.',
    ),
    (
      'Safely remove USB',
      'Eject the completed USB before unplugging it from the preparation PC.',
    ),
    (
      'Connect target USB',
      'Check that the destination system unit is powered off, then insert the prepared USB.',
    ),
    (
      'Enter firmware setup',
      'Power on the target and press its setup key. This training board uses Delete. Other boards may use F2 or F10; F12 commonly opens a one-time boot menu.',
    ),
    (
      'Choose USB boot',
      'Choose the USB boot entry that matches the selected profile. For the worksheet profile, inspect Boot Option #1 and Hard Drive BBS priority; for modern practice, choose the UEFI USB entry. Save with F10 and restart.',
    ),
    (
      'Boot Windows Setup',
      'Wait for the simulated restart to boot the selected USB installer.',
    ),
    (
      'Choose Custom installation',
      'Choose English and the assigned edition: Windows Server 2008 R2 Full Installation, Windows 7 Ultimate x64, or the approved modern practice image. Accept the training license prompt and choose Custom installation.',
    ),
    (
      'Create disk partitions',
      'Use only the authorized blank training disk. After system-reserved space, 102400 MiB remains: allocate 40% (40960 MiB) to Windows and 60% (61440 MiB) to Data.',
    ),
    (
      'Choose destination partition',
      'Select the Windows partition, not Data or the EFI system partition. The installer creates required system partitions separately.',
    ),
    (
      'Install Windows',
      'Start copying system files and keep power connected. Installation will restart automatically when the progress reaches 100%.',
    ),
    (
      'Prevent installer restart',
      'At the restart boundary, remove the USB or select Windows Boot Manager so the system does not start the installer again.',
    ),
    (
      'Create the local account',
      'Complete the required user setup with fictional training credentials. Install the approved device drivers and manufacturer updates, check Device Manager, then test and document the completed installation.',
    ),
  ];
  static const software = <(String, String)>[
    (
      'Review software requirements',
      'Read the end-user work order and approved manifest. Confirm versions, system requirements, licenses and trusted installation sources before changing the computer.',
    ),
    (
      'Install device drivers',
      'Install the chipset driver first, then the LAN and printer drivers. Inspect Device Manager after installation.',
    ),
    (
      'Install approved applications',
      'Select the approved packages, install each, then launch each application to verify that it opens.',
    ),
    (
      'Configure protection and remote access',
      'Enable firewall and antivirus protection. Configure Remote Desktop only for the authorized training account and keep network-level authentication enabled.',
    ),
    (
      'Configure and test the printer',
      'Select the installed printer driver, configure the lab printer at 192.168.9.20, and print a test page.',
    ),
    (
      'Verify and document',
      'Check driver status, application launches, protection, network access and printer output. Apply approved updates, create a restore point and record the observed results and variations.',
    ),
  ];
  static const network = <(String, String)>[
    (
      'Connect router and server',
      'Read the network plan, choose the assigned station, inspect the tested patch cable, then connect the server NIC to the specified router LAN port.',
    ),
    (
      'Reset the training router',
      'Reset only this isolated training router. Its factory address is 192.168.0.1; real devices may use another address. A reset erases existing configuration.',
    ),
    (
      'Open Command Prompt',
      'Open Run (Windows + R), enter cmd, and select OK.',
    ),
    (
      'Inspect the current lease',
      'Run ipconfig and read the IPv4 address, subnet mask and default gateway.',
    ),
    (
      'Open the router GUI',
      'Enter the gateway observed in ipconfig in the browser address bar and sign in using the training router label.',
    ),
    (
      'Configure LAN, DHCP and Wi-Fi',
      'Use the work-order address plan: 192.168.N.10/24 for the router and the assigned DHCP range. Configure the training SSID, approved security mode and Wi-Fi password. N is the station number.',
    ),
    (
      'Refresh the Ethernet adapter',
      'Disable and then enable the server Ethernet adapter to acquire a lease in the new subnet.',
    ),
    (
      'Verify the renewed lease',
      'Run ipconfig again. Confirm server .1, mask 255.255.255.0 and gateway .10. This lab reserves .1/.2/.3 for its three devices; lease order alone cannot guarantee addresses.',
    ),
    (
      'Connect clients and workgroup',
      'Connect the desktop Ethernet cable and laptop Wi-Fi. Assign unique .1/.2/.3 addresses and the same workgroup on all devices. Matching workgroups help organization; they are not required for IP ping.',
    ),
    (
      'Open the test terminal',
      'Open Run and start cmd on the connected computers.',
    ),
    (
      'Test both directions',
      'Select each computer and test the loopback address, its own address, the default gateway and both peers. Record packet loss and isolate any failure before continuing.',
    ),
    (
      'Prepare discovery settings',
      'Review the private lab network, then open Run to configure discovery services on each device.',
    ),
    (
      'Open Services',
      'Enter services.msc in Run to open the simulated Services console.',
    ),
    (
      'Configure discovery services',
      'On each device, set Function Discovery Resource Publication, SSDP Discovery and UPnP Device Host to Automatic, then start them. DNS Client is already running in this lab.',
    ),
    (
      'Open firewall settings',
      'Open Network properties, then Windows Defender Firewall.',
    ),
    (
      'Worksheet firewall exercise',
      'Review the firewall profiles in this isolated simulator. Keep protection enabled and use the approved rules for the services required by the work order.',
    ),
    (
      'Configure allowed features',
      'Allow only the required private-network discovery, file and printer sharing, and authorized management features. Do not expose remote-management services on a public profile.',
    ),
    (
      'Advanced sharing settings',
      'Enable the work-order discovery and sharing options on the private training network. Keep password-protected sharing unless the work order explicitly requires an isolated exception. Retest, inspect and document the final network.',
    ),
  ];
  static List<(String, String)> steps(SetupLabKind kind) => switch (kind) {
    SetupLabKind.operatingSystem => os,
    SetupLabKind.software => software,
    SetupLabKind.network => network,
  };
}
