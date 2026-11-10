enum SetupLabKind { operatingSystem, software, network }

class GuidedSetupData {
  static String sceneAsset(SetupLabKind kind) => switch (kind) {
    SetupLabKind.operatingSystem =>
      'assets/simulations/setup-os-workstation-v1.png',
    SetupLabKind.software =>
      'assets/simulations/setup-software-workstation-v1.png',
    SetupLabKind.network =>
      'assets/simulations/setup-network-workstation-v1.png',
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
      'Rufus: select ISO',
      'Open Rufus, choose SELECT, then select the approved Windows client or server ISO for this assignment.',
    ),
    (
      'Rufus: write boot media',
      'This target uses UEFI. Select GPT and UEFI, confirm the USB can be erased, then START. Wait for READY.',
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
      'Set the UEFI USB as the first boot device, then use F10 to save and restart. A one-time boot override normally does not require saving boot order.',
    ),
    (
      'Boot Windows Setup',
      'Wait for the simulated restart to boot the selected USB installer.',
    ),
    (
      'Choose Custom installation',
      'Choose the language and edition, accept the training license prompt, and select Custom: install Windows only.',
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
      'Set a training username and matching password, then verify the installed desktop. Use a fictional password; this practice does not save credentials.',
    ),
  ];
  static const software = <(String, String)>[
    (
      'Review software requirements',
      'Use the approved training manifest: chipset, LAN and printer drivers, a document editor, and a PDF reader.',
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
      'Check driver status, application launches, protection and printer output. Create a restore point and record the observed results.',
    ),
  ];
  static const network = <(String, String)>[
    (
      'Connect router and server',
      'Choose the assigned station number, then connect both ends of the Ethernet cable to the server NIC and a router LAN port.',
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
      'Use 192.168.N.10 for the router, /24 mask, and DHCP range .1 to .3. Configure a training SSID and Wi-Fi password. N is your station number.',
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
      'Select each computer and ping both peers. The lab pre-allows ICMP echo on its private network. A firewall can otherwise block ping even when addressing is correct.',
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
      'On each simulated device, turn off Private and Public firewall profiles as requested by the worksheet. This isolated exercise does not alter your real computer. Outside the exercise, keep firewall enabled and allow only required traffic.',
    ),
    (
      'Configure allowed features',
      'For each device, check Private and Public for the six worksheet features. These rules do not filter traffic while the firewall is off. Public remote-management exposure is not a recommended deployment configuration.',
    ),
    (
      'Advanced sharing settings',
      'On each device, enable discovery, file/printer sharing and public-folder sharing; turn off password-protected sharing for this isolated worksheet. Then verify the lab and review the protected deployment configuration.',
    ),
  ];
  static List<(String, String)> steps(SetupLabKind kind) => switch (kind) {
    SetupLabKind.operatingSystem => os,
    SetupLabKind.software => software,
    SetupLabKind.network => network,
  };
}
