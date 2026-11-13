import 'simulation_description.dart';
import 'package:flutter/material.dart';
import '../data/guided_setup_data.dart';

/// An isolated desktop/firmware/router practice. Never executes host commands.
class GuidedSetupWorkbench extends StatefulWidget {
  const GuidedSetupWorkbench({
    super.key,
    required this.kind,
    required this.onComplete,
    this.onFeedback,
  });
  final SetupLabKind kind;
  final void Function(int score, int total, bool passed) onComplete;
  final ValueChanged<List<String>>? onFeedback;
  @override
  State<GuidedSetupWorkbench> createState() => _GuidedSetupWorkbenchState();
}

class _GuidedSetupWorkbenchState extends State<GuidedSetupWorkbench>
    with SingleTickerProviderStateMixin {
  final _fields = <String, TextEditingController>{};
  final _choices = <String, String>{};
  final _flags = <String>{};
  final _errors = <String>[];
  final _log = <String>[];
  final _scroll = ScrollController();
  late final AnimationController _animation;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  int _step = 0;
  bool _busy = false, _done = false;
  String? _error;
  String _terminal = '';
  String _device = 'Server';
  static const _devices = ['Server', 'Desktop', 'Laptop'];
  static const _services = [
    'Function Discovery Resource Publication',
    'SSDP Discovery',
    'UPnP Device Host',
  ];
  static const _features = [
    'File and Printer Sharing',
    'Netlogon Services',
    'Network Discovery',
    'Remote Desktop',
    'Windows Firewall Remote Management',
    'Windows Remote Management',
  ];
  List<(String, String)> get _steps => GuidedSetupData.steps(widget.kind);
  String get _station => _text('station').isEmpty ? '9' : _text('station');
  String get _subnet => '192.168.$_station';
  String _ip(String device) => '$_subnet.${_devices.indexOf(device) + 1}';
  TextEditingController _controller(String key) =>
      _fields.putIfAbsent(key, () => TextEditingController());
  String _text(String key) => _controller(key).text.trim();
  String _choice(String key) => _choices[key] ?? '';
  bool _has(String key) => _flags.contains(key);
  void _flag(String key) => setState(() => _flags.add(key));

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _animation.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _check(bool condition, String reason) {
    if (_busy || _done) return false;
    if (!condition) {
      setState(() {
        _error = reason;
        _errors.add('${_steps[_step].$1}: $reason');
      });
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _advance() {
    if (_busy || _done) return;
    _log.add(_steps[_step].$1);
    if (_step == _steps.length - 1) {
      setState(() => _done = true);
      final total = _steps.length;
      final score = (total - _errors.length).clamp(0, total);
      widget.onFeedback?.call(List.unmodifiable(_errors));
      widget.onComplete(score, total, score / total >= .8);
    } else {
      setState(() {
        _step++;
        _error = null;
        _terminal = '';
      });
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _wait(String event, {bool advance = true}) async {
    if (_busy || _done) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _animation.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _flags.add(event);
    });
    if (advance) _advance();
  }

  Widget _button(String label, VoidCallback action, {String? key}) => Padding(
    padding: const EdgeInsets.only(top: 10, right: 8),
    child: FilledButton(
      onPressed: _busy || _done ? null : action,
      key: ValueKey(key ?? label),
      child: Text(label),
    ),
  );
  Widget _field(
    String key,
    String label, {
    String? hint,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: TextField(
      key: ValueKey(key),
      controller: _controller(key),
      enabled: !_busy,
      obscureText: secret,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget _select(String key, String label, List<String> values) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$key-${_choice(key)}'),
      initialValue: values.contains(_choice(key)) ? _choice(key) : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        for (final value in values)
          DropdownMenuItem(
            value: value,
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() => _choices[key] = value!),
    ),
  );
  Widget _toggle(String key, String label) => CheckboxListTile(
    key: ValueKey(key),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(label),
    value: _has(key),
    onChanged: _busy
        ? null
        : (value) => setState(() {
            value! ? _flags.add(key) : _flags.remove(key);
          }),
  );
  Widget _note(String text) =>
      SimulationDescriptionSection(title: 'Guidance', text: text);
  Widget _console() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(top: 12),
    color: const Color(0xFF111B27),
    child: SelectableText(
      _terminal.isEmpty
          ? 'Microsoft Windows [Training terminal]\nC:\\>'
          : _terminal,
      style: const TextStyle(
        color: Color(0xFFBEEBD3),
        fontFamily: 'monospace',
        height: 1.5,
      ),
    ),
  );
  Widget _deviceSelector() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final device in _devices)
        ChoiceChip(
          label: Text(device),
          selected: _device == device,
          onSelected: _busy ? null : (_) => setState(() => _device = device),
        ),
    ],
  );
  Widget _connection(
    String token,
    String label,
    List<String> ports,
    String flag,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Draggable<String>(
        data: token,
        maxSimultaneousDrags: _busy || _has(flag) ? 0 : 1,
        feedback: Material(
          color: Colors.transparent,
          child: Icon(
            token.contains('usb') ? Icons.usb : Icons.cable,
            size: 68,
            color: Colors.blue,
          ),
        ),
        childWhenDragging: Opacity(opacity: .3, child: _note(label)),
        child: _note('${_has(flag) ? 'Connected' : 'Drag connector'}: $label'),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final port in ports)
            DragTarget<String>(
              onAcceptWithDetails: (details) {
                if (_check(
                  details.data == token && port == ports.first,
                  'Use the matching ${ports.first} connector, not $port.',
                )) {
                  _flag(flag);
                }
              },
              builder: (context, candidates, rejected) => Container(
                key: ValueKey('port-$flag-$port'),
                width: 145,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _has(flag) && port == ports.first
                      ? const Color(0xFFD6F2DF)
                      : candidates.isNotEmpty
                      ? Colors.blue.shade100
                      : Colors.white,
                  border: Border.all(color: Colors.blueGrey, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(port, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    ],
  );

  List<Widget> _os() {
    switch (_step) {
      case 0:
        return [
          _connection('usb', 'Training USB • 16 GB', [
            'Preparation PC USB',
            'Ethernet',
          ], 'prep_usb'),
          _button('Open preparation desktop', () {
            if (_check(
              _has('prep_usb'),
              'Connect the USB to the preparation PC first.',
            )) {
              _advance();
            }
          }),
        ];
      case 1:
        return [
          _button('Open Rufus', () => _flag('rufus')),
          if (_has('rufus')) ...[
            _note(
              'Rufus • Device: Training USB (16 GB)\nBoot selection: Disk or ISO image',
            ),
            _button('SELECT', () => _flag('iso_picker')),
            if (_has('iso_picker')) ...[
              _select('iso', 'Approved ISO library', [
                'Windows 10 x64.iso',
                'Windows Server 2022 x64.iso',
              ]),
              _button('Open ISO', () {
                if (_check(
                  _choice('iso').isNotEmpty,
                  'Select an ISO file from the library.',
                )) {
                  _advance();
                }
              }),
            ],
          ],
        ];
      case 2:
        return [
          _note(
            'Device: Training USB • ${_choice('iso')}\nTarget specification: UEFI x64 • blank GPT disk. Windows 10 is included for worksheet practice, not as a current deployment recommendation.',
          ),
          _select('partition_scheme', 'Partition scheme', ['GPT', 'MBR']),
          _select('firmware', 'Target system', [
            'UEFI (non CSM)',
            'BIOS (or UEFI-CSM)',
          ]),
          _note(
            'File system: Rufus-selected default for this ISO. Rufus can use its UEFI:NTFS loader when needed; FAT32 is not universally required.',
          ),
          _toggle(
            'erase_usb',
            'I have checked the USB device and authorized erasing its contents',
          ),
          _button('START', () {
            if (_check(
              _choice('partition_scheme') == 'GPT' &&
                  _choice('firmware') == 'UEFI (non CSM)' &&
                  _has('erase_usb'),
              'This UEFI target needs GPT/UEFI and confirmation of the USB erase.',
            )) {
              _wait('usb_ready');
            }
          }),
        ];
      case 3:
        return [
          _note('Rufus status: READY • writing finished'),
          _button('Eject Training USB', () => _flag('ejected')),
          _button('Unplug USB', () {
            if (_check(
              _has('ejected'),
              'Eject the USB and wait for safe-removal confirmation before unplugging.',
            )) {
              _flags.remove('prep_usb');
              _advance();
            }
          }),
          if (_has('ejected')) _note('Safe to remove hardware'),
        ];
      case 4:
        return [
          _toggle('target_off', 'Target system unit is powered OFF'),
          if (_has('target_off'))
            _connection('usb', 'Prepared installation USB', [
              'Target PC USB',
              'Ethernet',
            ], 'target_usb'),
          _button('Check connection', () {
            if (_check(
              _has('target_off') && _has('target_usb'),
              'Power off the target and connect the prepared USB.',
            )) {
              _advance();
            }
          }),
        ];
      case 5:
        return [
          _button('Power on target', () => _flag('target_on')),
          if (_has('target_on')) ...[
            _note('POST • Press Delete for Setup • F12 for Boot Menu'),
            _select('setup_key', 'Firmware key', [
              'Delete',
              'F2',
              'F10',
              'F12',
            ]),
            _button('Press selected key', () {
              if (_check(
                _choice('setup_key') == 'Delete',
                'Read this board’s POST prompt: Delete opens Setup. Keys vary by model.',
              )) {
                _advance();
              }
            }),
          ],
        ];
      case 6:
        return [
          _note('UEFI Setup Utility • Boot priority'),
          _select('boot', 'Boot option #1', [
            'UEFI: Training USB',
            'Windows Boot Manager',
            'Network PXE',
          ]),
          _button('F10 • Save and restart', () {
            if (_check(
              _choice('boot') == 'UEFI: Training USB',
              'Choose the UEFI USB entry to start the installer.',
            )) {
              _advance();
            }
          }),
        ];
      case 7:
        return [
          _note('Target restarting • boot source: UEFI USB'),
          _button('Boot installer', () => _wait('installer_loaded')),
        ];
      case 8:
        return [
          _note('Windows Setup • ${_choice('iso')}'),
          _select('language', 'Language and keyboard', [
            'English • US',
            'English • UK',
          ]),
          _toggle(
            'license',
            'Accept the simulated license prompt for this approved training image',
          ),
          _select('install_type', 'Installation type', [
            'Upgrade',
            'Custom: install Windows only',
          ]),
          _button('Next', () {
            if (_check(
              _choice('language').isNotEmpty &&
                  _has('license') &&
                  _choice('install_type') == 'Custom: install Windows only',
              'Choose language, accept the license prompt and select Custom installation.',
            )) {
              _advance();
            }
          }),
        ];
      case 9:
        return [
          _note(
            'Disk 0 • authorized training disk • GPT\nEFI/MSR/recovery space is reserved separately. Usable exercise space: 102400 MiB.',
          ),
          _toggle(
            'disk_authorized',
            'Backup checked; Disk 0 is authorized for replacement',
          ),
          _field(
            'windows_size',
            'Windows partition size (MiB)',
            hint: 'Enter the primary partition size in MB',
          ),
          _field(
            'data_size',
            'Data partition size (MiB)',
            hint: 'Enter the remaining partition size in MB',
          ),
          _button('Apply partition layout', () {
            if (_check(
              _has('disk_authorized') &&
                  int.tryParse(_text('windows_size')) == 40960 &&
                  int.tryParse(_text('data_size')) == 61440,
              'Use 40960 MiB for Windows and 61440 MiB for Data; verify authorization before changing the disk.',
            )) {
              _advance();
            }
          }),
        ];
      case 10:
        return [
          _select('destination', 'Where do you want to install Windows?', [
            'EFI System • reserved',
            'Windows • 40960 MiB',
            'Data • 61440 MiB',
          ]),
          _button('Next', () {
            if (_check(
              _choice('destination') == 'Windows • 40960 MiB',
              'Select the Windows partition. Preserve Data and system-reserved partitions.',
            )) {
              _advance();
            }
          }),
        ];
      case 11:
        return [
          _note('Copying files → installing features → preparing restart'),
          _button('Install Windows', () => _wait('windows_installed')),
        ];
      case 12:
        return [
          _note(
            'Automatic restart boundary reached. The USB is still connected.',
          ),
          _button('Remove installer USB', () {
            _flags.remove('target_usb');
            _flag('installer_removed');
          }),
          _select('restart_boot', 'Restart boot source', [
            'UEFI: Training USB',
            'Windows Boot Manager',
          ]),
          _button('Continue restart', () {
            if (_check(
              !_has('target_usb') ||
                  _choice('restart_boot') == 'Windows Boot Manager',
              'The USB installer would load again. Remove it at restart or choose Windows Boot Manager.',
            )) {
              _wait('desktop_boot');
            }
          }),
        ];
      default:
        return [
          _field(
            'username',
            _choice('iso').contains('Server')
                ? 'Administrator display name (training)'
                : 'Local username',
          ),
          _field('password', 'Training password (8+ characters)', secret: true),
          _field('confirm_password', 'Confirm password', secret: true),
          _button('Create account and verify desktop', () {
            if (_check(
              _text('username').isNotEmpty &&
                  _text('password').length >= 8 &&
                  _text('password') == _text('confirm_password'),
              'Enter a username and matching training passwords of at least 8 characters.',
            )) {
              _controller('password').clear();
              _controller('confirm_password').clear();
              _advance();
            }
          }),
        ];
    }
  }

  void _command(String expected, {required String output}) {
    if (_check(
      _text('command').toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
          expected,
      'Enter $expected in this simulated terminal.',
    )) {
      setState(() => _terminal = 'C:\\> $expected\n$output');
      _flag('command_$_step');
    }
  }

  List<Widget> _runWindow(String expected) => [
    _button('Windows + R', () => _flag('run_$_step')),
    if (_has('run_$_step')) ...[
      _field('run_$_step', 'Run • Open'),
      _button('OK', () {
        if (_check(
          _text('run_$_step').toLowerCase() == expected,
          'Type $expected in Run.',
        )) {
          _advance();
        }
      }),
    ],
  ];

  List<Widget> _network() {
    switch (_step) {
      case 0:
        return [
          _field(
            'station',
            'Assigned station number (1–254)',
            hint: 'Enter the assigned station number',
          ),
          _connection('ethernet_server', 'Ethernet end • server', [
            'Server NIC',
            'USB',
          ], 'server_nic'),
          _connection('ethernet_router', 'Ethernet end • router', [
            'Router LAN 1',
            'Router WAN',
          ], 'router_lan'),
          _button('Check link', () {
            final n = int.tryParse(_text('station'));
            if (_check(
              n != null &&
                  n >= 1 &&
                  n <= 254 &&
                  _has('server_nic') &&
                  _has('router_lan'),
              'Enter station 1–254 and attach both Ethernet ends to NIC and LAN.',
            )) {
              _advance();
            }
          }),
        ];
      case 1:
        return [
          _toggle(
            'reset_authorized',
            'This is the isolated training router; reset is authorized',
          ),
          _button('Hold Reset • simulated 15 seconds', () {
            if (_check(
              _has('reset_authorized'),
              'Confirm the reset is authorized for the training router.',
            )) {
              _wait('router_reset');
            }
          }),
        ];
      case 2:
        return _runWindow('cmd');
      case 3:
      case 7:
        return [
          _field('command', 'Command Prompt'),
          _button(
            'Run command',
            () => _command(
              'ipconfig',
              output: _step == 3
                  ? 'IPv4 Address . . . : 192.168.0.100\nSubnet Mask . . . : 255.255.255.0\nDefault Gateway . : 192.168.0.1'
                  : 'IPv4 Address . . . : ${_ip('Server')}\nSubnet Mask . . . : 255.255.255.0\nDefault Gateway . : $_subnet.10',
            ),
          ),
          _console(),
          _button('Record network details', () {
            if (_check(
              _has('command_$_step'),
              'Run ipconfig and inspect the output first.',
            )) {
              _advance();
            }
          }),
        ];
      case 4:
        return [
          _field(
            'browser',
            'Browser address',
            hint: 'Enter the gateway reported by ipconfig',
          ),
          _note(
            'Training router label: username admin • password admin. These are fixture credentials, not universal router defaults.',
          ),
          _field('router_user', 'Router username'),
          _field('router_password', 'Router password', secret: true),
          _button('Sign in', () {
            if (_check(
              _text('browser')
                          .replaceFirst(RegExp(r'^https?://'), '')
                          .replaceAll(RegExp(r'/$'), '') ==
                      '192.168.0.1' &&
                  _text('router_user') == 'admin' &&
                  _text('router_password') == 'admin',
              'Use the observed gateway and the credentials printed on this training router.',
            )) {
              _advance();
            }
          }),
        ];
      case 5:
        return [
          _note(
            'Router administration • station $_station\nReserve Server .1, Desktop .2 and Laptop .3. Router address .10 is outside the DHCP pool.',
          ),
          _field('lan', 'LAN address', hint: 'Enter the planned LAN address'),
          _field('mask', 'Subnet mask', hint: 'Enter the required subnet mask'),
          _field(
            'dhcp_start',
            'DHCP start address',
            hint: 'Enter the planned starting address',
          ),
          _field(
            'dhcp_end',
            'DHCP end address',
            hint: 'Enter the planned ending address',
          ),
          _field('ssid', 'Wireless SSID'),
          _field(
            'wifi_password',
            'WPA2/WPA3 training password (8+ characters)',
            secret: true,
          ),
          _button('Save and reboot router', () {
            if (_check(
              _text('lan') == '$_subnet.10' &&
                  _text('mask') == '255.255.255.0' &&
                  _text('dhcp_start') == '$_subnet.1' &&
                  _text('dhcp_end') == '$_subnet.3' &&
                  _text('ssid').isNotEmpty &&
                  _text('wifi_password').length >= 8,
              'Check LAN .10, /24 mask, DHCP .1–.3, SSID and an 8+ character Wi-Fi password.',
            )) {
              _wait('router_configured');
            }
          }),
        ];
      case 6:
        return [
          _note(
            _has('adapter_disabled')
                ? 'Ethernet: disabled • link down'
                : 'Ethernet: enabled • old lease',
          ),
          _button('Disable Ethernet', () => _flag('adapter_disabled')),
          _button('Enable Ethernet', () {
            if (_check(
              _has('adapter_disabled'),
              'Disable the adapter before re-enabling it to refresh the lease.',
            )) {
              _wait('lease_renewed');
            }
          }),
        ];
      case 8:
        return [
          _connection('desktop_cable', 'Desktop Ethernet to router LAN 2', [
            'Desktop NIC ↔ LAN 2',
            'Router WAN',
          ], 'desktop_link'),
          _select('wifi_network', 'Laptop Wi-Fi network', [
            _text('ssid'),
            'Unrelated guest network',
          ]),
          _field('wifi_join_password', 'Laptop Wi-Fi password', secret: true),
          _button('Connect laptop', () {
            if (_check(
              _choice('wifi_network') == _text('ssid') &&
                  _text('wifi_join_password') == _text('wifi_password'),
              'Choose the configured SSID and its password.',
            )) {
              _flag('laptop_link');
            }
          }),
          _deviceSelector(),
          _field(
            'ip_$_device',
            '$_device static IPv4 address',
            hint: 'Enter the assigned address for $_device',
          ),
          _field(
            'group_$_device',
            '$_device workgroup',
            hint: 'Enter the shared workgroup name',
          ),
          _note(
            'All devices use mask 255.255.255.0 and gateway $_subnet.10. Static addresses are reserved in DHCP to avoid duplicates.',
          ),
          _button('Apply device settings', () {
            if (_check(
              _text('ip_$_device') == _ip(_device) &&
                  _text('group_$_device').toUpperCase() == 'CSSLAB',
              'Use the unique assigned address ${_ip(_device)} and workgroup CSSLAB.',
            )) {
              _flag('address_$_device');
            }
          }),
          _note(
            'Configured: ${_devices.where((d) => _has('address_$d')).join(', ')}',
          ),
          _button('Continue to connectivity tests', () {
            if (_check(
              _has('desktop_link') &&
                  _has('laptop_link') &&
                  _devices.every(
                    (d) =>
                        _has('address_$d') &&
                        _text('ip_$d') == _ip(d) &&
                        _text('group_$d').toUpperCase() == 'CSSLAB',
                  ),
              'Connect both clients and configure all three devices.',
            )) {
              _advance();
            }
          }),
        ];
      case 9:
        return _runWindow('cmd');
      case 10:
        return [
          _deviceSelector(),
          _note(
            '$_device • ${_ip(_device)} • peers: ${_devices.where((d) => d != _device).map(_ip).join(', ')}',
          ),
          _field('ping', 'Command Prompt', hint: 'ping <destination IP>'),
          _button('Run ping', () {
            final command = _text(
              'ping',
            ).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
            final peers = _devices.where(
              (d) => d != _device && command == 'ping ${_ip(d)}',
            );
            if (_check(
              peers.isNotEmpty,
              'Ping one of the other devices using its assigned IPv4 address.',
            )) {
              final target = peers.first;
              _flag('ping_${_device}_$target');
              setState(
                () => _terminal =
                    '$_device> $command\nReply from ${_ip(target)}: bytes=32 time<1ms TTL=128\nSent = 4, Received = 4, Lost = 0 (0% loss)',
              );
            }
          }),
          _console(),
          _note(
            'Successful directions: ${_flags.where((f) => f.startsWith('ping_')).length} / 6',
          ),
          _button('Finish ping tests', () {
            if (_check(
              _flags.where((f) => f.startsWith('ping_')).length == 6,
              'Ping both peers from Server, Desktop and Laptop.',
            )) {
              _advance();
            }
          }),
        ];
      case 11:
        return [
          _note(
            'Connectivity verified on the private lab network. Discovery and file-sharing configuration is separate from IP reachability.',
          ),
          _button('Open discovery configuration', _advance),
        ];
      case 12:
        return _runWindow('services.msc');
      case 13:
        return [
          _deviceSelector(),
          for (final service in _services) ...[
            _select('startup_${_device}_$service', '$service • Startup type', [
              'Manual',
              'Automatic',
              'Disabled',
            ]),
            _button('Start $service', () {
              if (_check(
                _choice('startup_${_device}_$service') == 'Automatic',
                'Set $service to Automatic before starting it.',
              )) {
                _flag('running_${_device}_$service');
              }
            }),
            Text(
              _has('running_${_device}_$service')
                  ? 'Status: Running'
                  : 'Status: Stopped',
            ),
          ],
          _note(
            'Running services: ${_flags.where((f) => f.startsWith('running_')).length} / 9',
          ),
          _button('Save service configuration', () {
            if (_check(
              _devices.every(
                (d) => _services.every(
                  (s) =>
                      _has('running_${d}_$s') &&
                      _choice('startup_${d}_$s') == 'Automatic',
                ),
              ),
              'Set Automatic and start all three services on each device.',
            )) {
              _advance();
            }
          }),
        ];
      case 14:
        return [
          _button('Network • Properties', () => _flag('network_properties')),
          if (_has('network_properties'))
            _button('Windows Defender Firewall', _advance),
        ];
      case 15:
        return [
          _deviceSelector(),
          _note(
            'ISOLATED WORKSHEET MODE • simulated switches only\nTurning off a firewall removes its filtering. Normal deployment: keep it on and use scoped rules.',
          ),
          _toggle(
            'firewall_off_${_device}_Private',
            'Turn off Private profile (worksheet)',
          ),
          _toggle(
            'firewall_off_${_device}_Public',
            'Turn off Public profile (worksheet)',
          ),
          _button('Apply worksheet firewall settings', () {
            if (_check(
              _devices.every(
                (d) => [
                  'Private',
                  'Public',
                ].every((p) => _has('firewall_off_${d}_$p')),
              ),
              'Apply the worksheet settings on all three simulated devices.',
            )) {
              _advance();
            }
          }),
        ];
      case 16:
        return [
          _deviceSelector(),
          _note(
            'Allow an app or feature • Change settings\nNetlogon and management features depend on installed roles and services. This training image exposes the worksheet entries.',
          ),
          for (final feature in _features) ...[
            Text(feature, style: const TextStyle(fontWeight: FontWeight.bold)),
            _toggle('rule_${_device}_${feature}_Private', 'Private'),
            _toggle(
              'rule_${_device}_${feature}_Public',
              'Public (isolated worksheet)',
            ),
          ],
          _button('Save allowed features', () {
            if (_check(
              _devices.every(
                (d) => _features.every(
                  (f) => [
                    'Private',
                    'Public',
                  ].every((p) => _has('rule_${d}_${f}_$p')),
                ),
              ),
              'Configure both worksheet profiles for all six features on each device.',
            )) {
              _advance();
            }
          }),
        ];
      default:
        return [
          _deviceSelector(),
          _toggle('discovery_$_device', 'Turn on network discovery'),
          _toggle('sharing_$_device', 'Turn on file and printer sharing'),
          _toggle(
            'public_folder_$_device',
            'Turn on public folder sharing (worksheet)',
          ),
          _toggle(
            'password_off_$_device',
            'Turn off password-protected sharing (worksheet)',
          ),
          _note(
            'Protected deployment: firewall ON for both profiles; private-network discovery/sharing only; password-protected sharing ON; enable remote access only when authorized. The worksheet state remains isolated here.',
          ),
          _toggle(
            'review_secure',
            'I can distinguish the worksheet settings from a protected deployment',
          ),
          _button('Verify network and finish', () {
            if (_check(
              _has('review_secure') &&
                  _devices.every(
                    (d) => [
                      'discovery',
                      'sharing',
                      'public_folder',
                      'password_off',
                    ].every((s) => _has('${s}_$d')),
                  ),
              'Apply sharing settings to all devices and review the protected deployment configuration.',
            )) {
              _advance();
            }
          }),
        ];
    }
  }

  List<Widget> _software() {
    switch (_step) {
      case 0:
        return [
          _note(
            'Approved manifest • chipset, LAN, printer driver; document editor and PDF reader. Use the installed Windows system from the OS lab.',
          ),
          _toggle(
            'manifest',
            'Verified OS compatibility, licenses and trusted package sources',
          ),
          _button('Open driver installer', () {
            if (_check(
              _has('manifest'),
              'Review and confirm the approved manifest.',
            )) {
              _advance();
            }
          }),
        ];
      case 1:
        return [
          for (final driver in ['Chipset', 'LAN', 'Printer'])
            _button('Install $driver driver', () {
              if (_check(
                driver == 'Chipset' || _has('driver_Chipset'),
                'Install the chipset driver before dependent devices.',
              )) {
                _wait('driver_$driver', advance: false);
              }
            }),
          _note(
            'Device Manager\n${['Chipset', 'LAN', 'Printer'].map((d) => '$d: ${_has('driver_$d') ? 'Working properly' : 'Driver missing'}').join('\n')}',
          ),
          _button('Verify Device Manager', () {
            if (_check(
              ['Chipset', 'LAN', 'Printer'].every((d) => _has('driver_$d')),
              'Install all required drivers and clear missing-device warnings.',
            )) {
              _advance();
            }
          }),
        ];
      case 2:
        return [
          for (final app in ['Document editor', 'PDF reader']) ...[
            _button('Install $app', () => _wait('app_$app', advance: false)),
            _button('Launch $app', () {
              if (_check(
                _has('app_$app'),
                'Install $app before launching it.',
              )) {
                _flag('launch_$app');
              }
            }),
            if (_has('launch_$app'))
              _note('$app opened successfully • sample file rendered'),
          ],
          _button('Verify applications', () {
            if (_check(
              ['Document editor', 'PDF reader'].every((a) => _has('launch_$a')),
              'Install and launch both approved applications.',
            )) {
              _advance();
            }
          }),
        ];
      case 3:
        return [
          _toggle('firewall_on', 'Windows Firewall enabled'),
          _toggle(
            'antivirus_on',
            'Real-time protection and current definitions',
          ),
          _toggle(
            'rdp_on',
            'Enable authorized Remote Desktop on the training Pro/Server edition',
          ),
          _toggle('nla_on', 'Require Network Level Authentication'),
          _field(
            'rdp_user',
            'Authorized remote-access account',
            hint: 'Enter the authorized local account',
          ),
          _button('Apply protection settings', () {
            if (_check(
              ['firewall_on', 'antivirus_on', 'rdp_on', 'nla_on'].every(_has) &&
                  _text('rdp_user') == 'LabTechnician',
              'Enable protection, NLA, and remote access for LabTechnician only.',
            )) {
              _advance();
            }
          }),
        ];
      case 4:
        return [
          _field(
            'printer_ip',
            'Printer TCP/IP address',
            hint: 'Enter the assigned printer address',
          ),
          _select('printer_driver', 'Printer driver', [
            'Approved lab printer driver',
            'Unrelated driver',
          ]),
          _button('Print test page', () {
            if (_check(
              _text('printer_ip') == '192.168.9.20' &&
                  _choice('printer_driver') == 'Approved lab printer driver',
              'Choose the installed lab printer driver and assigned IP address.',
            )) {
              _wait('test_page', advance: false);
            }
          }),
          if (_has('test_page'))
            _note('Printed: Windows Printer Test Page • queue empty'),
          _button('Confirm printed output', () {
            if (_check(
              _has('test_page'),
              'Print and inspect the test page first.',
            )) {
              _advance();
            }
          }),
        ];
      default:
        return [
          _note(
            'Verified: three drivers, two application launches, protection, authorized remote access and printer output.',
          ),
          _button(
            'Create restore point',
            () => _wait('restore', advance: false),
          ),
          _field(
            'service_record',
            'Service record • describe the checks and results',
          ),
          _button('Save record and finish', () {
            if (_check(
              _has('restore') && _text('service_record').length >= 20,
              'Create a restore point and write a meaningful service record (20+ characters).',
            )) {
              _advance();
            }
          }),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      SetupLabKind.operatingSystem => 'COC 1 • OS installation',
      SetupLabKind.software => 'COC 1 • Software configuration',
      SetupLabKind.network => 'COC 2 • Computer network setup',
    };
    return ColoredBox(
      color: const Color(0xFFECF2F8),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF12334C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _done
                        ? 'Practical complete • ${_log.length} operations verified'
                        : 'Step ${_step + 1} of ${_steps.length} • ${_steps[_step].$1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExpansionTile(
                    key: ValueKey('setup-scene-${widget.kind.name}'),
                    title: const Text('Training equipment reference'),
                    subtitle: const Text('View the equipment used in this lab'),
                    initiallyExpanded:
                        _step == 0 && MediaQuery.sizeOf(context).width >= 800,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          GuidedSetupData.sceneAsset(widget.kind),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          semanticLabel:
                              'Illustrative equipment reference for $title; use the controls below to perform the current step',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: _done ? 1 : _step / _steps.length,
                    minHeight: 6,
                  ),
                  _note(
                    _done
                        ? 'The simulated system passed the required checks. Review the operation record below.'
                        : _steps[_step].$2,
                  ),
                  const Text(
                    'Interactive training environment • no real disks, router settings or operating-system commands are changed.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF53677B)),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Container(
                              key: const ValueKey('setup-error'),
                              padding: const EdgeInsets.all(12),
                              color: const Color(0xFFFFE8E5),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFF8C2020),
                                ),
                              ),
                            ),
                          if (!_done)
                            ...switch (widget.kind) {
                              SetupLabKind.operatingSystem => _os(),
                              SetupLabKind.software => _software(),
                              SetupLabKind.network => _network(),
                            },
                          if (_busy)
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, _) => Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: _animation.value,
                                    ),
                                    Text(
                                      'Processing • ${(_animation.value * 100).round()}% • keep the device connected',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_done)
                            const Icon(
                              Icons.task_alt,
                              size: 60,
                              color: Colors.green,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    title: Text('Operation record (${_log.length})'),
                    children: [
                      for (final entry in _log)
                        ListTile(
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          title: Text(entry),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
