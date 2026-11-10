import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/guided_setup_data.dart';
import 'package:icteach/widgets/guided_setup_workbench.dart';

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_SETUP')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('setup-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-review/setup-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester, String key, String value) async {
  final finder = find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String> &&
        (w.key as ValueKey).value.toString().startsWith('$key-'),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<void> connect(
  WidgetTester tester,
  String token,
  String flag,
  String port,
) async {
  final source = find.byWidgetPredicate(
    (w) => w is Draggable<String> && w.data == token,
  );
  final target = find.byKey(ValueKey('port-$flag-$port'));
  await tester.ensureVisible(source);
  await tester.pumpAndSettle();
  await tester.dragFrom(
    tester.getCenter(source),
    tester.getCenter(target) - tester.getCenter(source),
  );
  await tester.pumpAndSettle();
}

Future<void> device(WidgetTester tester, String name) async {
  final finder = find.widgetWithText(ChoiceChip, name);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  SetupLabKind kind,
  void Function(int, int, bool) complete, {
  Size size = const bool.fromEnvironment('MOBILE_SETUP')
      ? const Size(390, 844)
      : const Size(1100, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        fontFamily: const bool.fromEnvironment('CAPTURE_SETUP')
            ? 'Review'
            : null,
      ),
      home: RepaintBoundary(
        key: const ValueKey('setup-capture'),
        child: Scaffold(
          body: GuidedSetupWorkbench(kind: kind, onComplete: complete),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_SETUP')) {
      final loader = FontLoader('Review');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
          ),
        ),
      );
      await loader.load();
    }
  });
  for (final kind in SetupLabKind.values) {
    for (final size in [const Size(360, 640), const Size(640, 320)]) {
      testWidgets('$kind initial screen fits $size', (tester) async {
        await mount(tester, kind, (_, _, _) {}, size: size);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'OS installation validates USB, firmware, partitions and boot loop',
    (tester) async {
      int? total;
      await mount(tester, SetupLabKind.operatingSystem, (_, t, _) => total = t);
      await tap(tester, 'Open preparation desktop');
      expect(find.byKey(const ValueKey('setup-error')), findsOneWidget);
      await connect(tester, 'usb', 'prep_usb', 'Preparation PC USB');
      await tap(tester, 'Open preparation desktop');
      await tap(tester, 'Open Rufus');
      await tap(tester, 'SELECT');
      await select(tester, 'iso', 'Windows 10 x64.iso');
      await tap(tester, 'Open ISO');
      await select(tester, 'partition_scheme', 'MBR');
      await select(tester, 'firmware', 'UEFI (non CSM)');
      await capture(tester, 'rufus');
      await tap(tester, 'erase_usb');
      await tap(tester, 'START');
      expect(find.textContaining('needs GPT/UEFI'), findsOneWidget);
      await select(tester, 'partition_scheme', 'GPT');
      await tap(tester, 'START');
      await tap(tester, 'Unplug USB');
      expect(find.textContaining('Eject the USB and wait'), findsOneWidget);
      await tap(tester, 'Eject Training USB');
      await tap(tester, 'Unplug USB');
      await tap(tester, 'target_off');
      await connect(tester, 'usb', 'target_usb', 'Target PC USB');
      await tap(tester, 'Check connection');
      await tap(tester, 'Power on target');
      await select(tester, 'setup_key', 'Delete');
      await tap(tester, 'Press selected key');
      await select(tester, 'boot', 'UEFI: Training USB');
      await tap(tester, 'F10 • Save and restart');
      await tap(tester, 'Boot installer');
      await select(tester, 'language', 'English • US');
      await tap(tester, 'license');
      await select(tester, 'install_type', 'Custom: install Windows only');
      await tap(tester, 'Next');
      await tap(tester, 'disk_authorized');
      await enter(tester, 'windows_size', '40960');
      await enter(tester, 'data_size', '61440');
      await tap(tester, 'Apply partition layout');
      await select(tester, 'destination', 'Data • 61440 MiB');
      await tap(tester, 'Next');
      expect(
        find.textContaining('Select the Windows partition.'),
        findsOneWidget,
      );
      await select(tester, 'destination', 'Windows • 40960 MiB');
      await tap(tester, 'Next');
      await tap(tester, 'Install Windows');
      await tap(tester, 'Continue restart');
      expect(find.textContaining('installer would load again'), findsOneWidget);
      await tap(tester, 'Remove installer USB');
      await tap(tester, 'Continue restart');
      expect(total, isNull);
      await enter(tester, 'username', 'Student');
      await enter(tester, 'password', 'Training123!');
      await enter(tester, 'confirm_password', 'Training123!');
      await tap(tester, 'Create account and verify desktop');
      expect(total, 14);
      expect(find.textContaining('Practical complete'), findsOneWidget);
    },
  );

  testWidgets(
    'software installs drivers, tests apps and printer before completion',
    (tester) async {
      int? total;
      await mount(tester, SetupLabKind.software, (_, t, _) => total = t);
      await tap(tester, 'manifest');
      await tap(tester, 'Open driver installer');
      await tap(tester, 'Install LAN driver');
      expect(
        find.textContaining('Install the chipset driver before'),
        findsOneWidget,
      );
      for (final d in ['Chipset', 'LAN', 'Printer']) {
        await tap(tester, 'Install $d driver');
      }
      await tap(tester, 'Verify Device Manager');
      for (final app in ['Document editor', 'PDF reader']) {
        await tap(tester, 'Install $app');
        await tap(tester, 'Launch $app');
      }
      await tap(tester, 'Verify applications');
      for (final flag in ['firewall_on', 'antivirus_on', 'rdp_on', 'nla_on']) {
        await tap(tester, flag);
      }
      await enter(tester, 'rdp_user', 'LabTechnician');
      await tap(tester, 'Apply protection settings');
      await enter(tester, 'printer_ip', '192.168.9.20');
      await select(tester, 'printer_driver', 'Approved lab printer driver');
      await tap(tester, 'Print test page');
      await tap(tester, 'Confirm printed output');
      await tap(tester, 'Create restore point');
      await enter(
        tester,
        'service_record',
        'Drivers loaded, both apps opened and test page printed.',
      );
      await tap(tester, 'Save record and finish');
      expect(total, 6);
    },
  );

  testWidgets(
    'network config requires all devices and six directional ping checks',
    (tester) async {
      int? total;
      await mount(tester, SetupLabKind.network, (_, t, _) => total = t);
      await enter(tester, 'station', '9');
      await connect(tester, 'ethernet_server', 'server_nic', 'Server NIC');
      await connect(tester, 'ethernet_router', 'router_lan', 'Router LAN 1');
      await tap(tester, 'Check link');
      await tap(tester, 'reset_authorized');
      await tap(tester, 'Hold Reset • simulated 15 seconds');
      await tap(tester, 'Windows + R');
      await enter(tester, 'run_2', 'cmd');
      await tap(tester, 'OK');
      await enter(tester, 'command', 'ipconfig');
      await tap(tester, 'Run command');
      await tap(tester, 'Record network details');
      await enter(tester, 'browser', '192.168.0.1');
      await enter(tester, 'router_user', 'admin');
      await enter(tester, 'router_password', 'admin');
      await tap(tester, 'Sign in');
      for (final entry in {
        'lan': '192.168.9.10',
        'mask': '255.255.255.0',
        'dhcp_start': '192.168.9.1',
        'dhcp_end': '192.168.9.3',
        'ssid': 'CSS Lab',
        'wifi_password': 'Training123!',
      }.entries) {
        await enter(tester, entry.key, entry.value);
      }
      await tap(tester, 'Save and reboot router');
      await tap(tester, 'Disable Ethernet');
      await tap(tester, 'Enable Ethernet');
      await enter(tester, 'command', 'ipconfig');
      await tap(tester, 'Run command');
      await tap(tester, 'Record network details');
      await connect(
        tester,
        'desktop_cable',
        'desktop_link',
        'Desktop NIC ↔ LAN 2',
      );
      await select(tester, 'wifi_network', 'CSS Lab');
      await enter(tester, 'wifi_join_password', 'Training123!');
      await tap(tester, 'Connect laptop');
      const devices = ['Server', 'Desktop', 'Laptop'];
      for (var i = 0; i < devices.length; i++) {
        await device(tester, devices[i]);
        await enter(tester, 'ip_${devices[i]}', '192.168.9.${i + 1}');
        await enter(tester, 'group_${devices[i]}', 'CSSLAB');
        await tap(tester, 'Apply device settings');
      }
      await tap(tester, 'Continue to connectivity tests');
      await tap(tester, 'Windows + R');
      await enter(tester, 'run_9', 'cmd');
      await tap(tester, 'OK');
      await tap(tester, 'Finish ping tests');
      expect(total, isNull);
      for (final d in devices) {
        await device(tester, d);
        for (var i = 0; i < devices.length; i++) {
          if (devices[i] == d) continue;
          await enter(tester, 'ping', 'ping 192.168.9.${i + 1}');
          await tap(tester, 'Run ping');
        }
      }
      await tap(tester, 'Finish ping tests');
      await tap(tester, 'Open discovery configuration');
      await tap(tester, 'Windows + R');
      await enter(tester, 'run_12', 'services.msc');
      await tap(tester, 'OK');
      for (final d in devices) {
        await device(tester, d);
        for (final service in [
          'Function Discovery Resource Publication',
          'SSDP Discovery',
          'UPnP Device Host',
        ]) {
          await select(tester, 'startup_${d}_$service', 'Automatic');
          await tap(tester, 'Start $service');
        }
      }
      await tap(tester, 'Save service configuration');
      await tap(tester, 'Network • Properties');
      await tap(tester, 'Windows Defender Firewall');
      for (final d in devices) {
        await device(tester, d);
        for (final p in ['Private', 'Public']) {
          await tap(tester, 'firewall_off_${d}_$p');
        }
      }
      await tap(tester, 'Apply worksheet firewall settings');
      for (final d in devices) {
        await device(tester, d);
        for (final f in [
          'File and Printer Sharing',
          'Netlogon Services',
          'Network Discovery',
          'Remote Desktop',
          'Windows Firewall Remote Management',
          'Windows Remote Management',
        ]) {
          for (final p in ['Private', 'Public']) {
            await tap(tester, 'rule_${d}_${f}_$p');
          }
        }
      }
      await tap(tester, 'Save allowed features');
      for (final d in devices) {
        await device(tester, d);
        for (final s in [
          'discovery',
          'sharing',
          'public_folder',
          'password_off',
        ]) {
          await tap(tester, '${s}_$d');
        }
      }
      await tap(tester, 'review_secure');
      await tap(tester, 'Verify network and finish');
      expect(total, 18);
    },
  );
}
