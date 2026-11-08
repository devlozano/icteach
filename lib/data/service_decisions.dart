/// Decisions made inside a virtual service operation, before credit is awarded.
/// Labels describe simulated actions; no commands run on the learner's device.
class ServiceDecision {
  const ServiceDecision(
    this.evidence,
    this.options,
    this.correctIndex,
    this.explanation,
  );
  final String evidence;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  static const bySlot = <String, ServiceDecision>{
    'storage_setup': ServiceDecision(
      'Work order: clean-install on the 256 GB system SSD. A separate 1 TB drive contains client files. Backup has been verified.',
      [
        'Erase both drives',
        'Select the verified 256 GB SSD only',
        'Install on the 1 TB data drive',
      ],
      1,
      'Match the authorized target by model and capacity. Changing the data drive risks losing client files; a backup does not authorize erasing it.',
    ),
    'driver_install': ServiceDecision(
      'After installation, the network adapter appears as an unknown device. The work order identifies the PC model and installed OS.',
      [
        'Install the matching OEM network driver',
        'Install a driver from an advertisement',
        'Disable the network adapter permanently',
      ],
      0,
      'Use the manufacturer driver for the device and OS, then check Device Manager and connectivity. Disabling the device hides the symptom without restoring service.',
    ),
    'account_config': ServiceDecision(
      'The client needs an account for everyday schoolwork. Only authorized technicians should change system settings.',
      [
        'Give every learner administrator access',
        'Share the technician account',
        'Create a named standard user',
      ],
      2,
      'A named standard account supports everyday work without unnecessary administrative privileges. Keep technician credentials separate.',
    ),
    'security_config': ServiceDecision(
      'A required application cannot receive traffic. Its approved documentation specifies a single inbound port.',
      [
        'Turn off the firewall completely',
        'Add only the approved application/port rule',
        'Disable antivirus and all updates',
      ],
      1,
      'Keep protection enabled and permit only the documented traffic. Test the application after the narrow rule is applied.',
    ),
    'address_layer': ServiceDecision(
      'Link is up. The network plan is 192.168.1.0/24, gateway 192.168.1.254. This client is incorrectly set to 192.168.2.10/24; 192.168.1.10 is reserved for it.',
      [
        'Set the client to the gateway address',
        'Keep the address and replace the cable',
        'Apply 192.168.1.10/24 and gateway 192.168.1.254',
      ],
      2,
      'The client is on the wrong subnet. Use its reserved unique address and the planned gateway; do not duplicate the router address.',
    ),
    'dns_test': ServiceDecision(
      'The gateway responds and the approved service works by IP. Name lookup times out. The network plan specifies a working DNS server.',
      [
        'Crimp a new cable immediately',
        'Apply the approved DNS server and repeat name lookup',
        'Erase the system drive',
      ],
      1,
      'Working IP connectivity with failed name resolution points to DNS configuration or service. Correct DNS and retest the named service before closing the incident.',
    ),
  };
}
