# Guided OS, software and network practicals

The bundled catalog routes these activities to `GuidedSetupWorkbench`:

| Activity | ID | Required interactions |
| --- | --- | --- |
| COC1 Operating System Installation | `sim_coc1_os_install` | 14 stages: USB attachment, Rufus ISO selection and GPT/UEFI settings, safe removal, target power state, firmware entry, boot priority, Custom installation, 40/60 partitioning, destination selection, installation/restart, first account |
| COC1 Software Configuration | `sim_coc1_software_config` | 6 stages: manifest, chipset/LAN/printer drivers, application installation and launches, protection/authorized RDP, printer test, restore point and service record |
| COC2 Computer Network Setup | `sim_coc2_network_setup` | 18 stages: Ethernet ends, authorized reset, Run/terminal commands, router login, LAN/DHCP/Wi-Fi, adapter refresh, unique addresses/workgroup, six ping directions, discovery services, firewall profiles/features and sharing |

The practice walkthrough uses the same controls without awarding assessment credit. Assessment completion is emitted once, after all required stages pass. Each rejected action is included in the feedback and deducts one point from the stage total, with a floor of zero. Existing assessment persistence remains responsible for saving results; this workbench itself executes no commands, accesses no disks or routers, and does not save credentials.

## Worksheet interpretation

The three provided attachments contain the same older Windows 7/Server 2008 R2 worksheet. The user's newer 14-step Rufus and 18-step network procedure takes precedence. The OS selector provides Windows 10 and Windows Server 2022 training images. This is a behavioral training simulation, not a pixel-exact replica of any particular firmware, router or Windows version.

- The ISO is on the preparation computer; the target USB is erased when Rufus writes it.
- The selected fixture uses UEFI/GPT. Firmware keys vary; this board's displayed setup key is Delete. F12 is described as a typical one-time boot-menu key.
- The 40/60 exercise applies to 102400 MiB of usable space after system-reserved space: Windows 40960 MiB, Data 61440 MiB. Required EFI/MSR/recovery partitions are represented separately, not as data partitions students should overwrite.
- USB removal occurs at the restart boundary. Choosing Windows Boot Manager is also accepted to avoid rebooting into the installer.
- The isolated router's factory address and credentials are printed as fixture information, not universal defaults. Station N sets the new router to 192.168.N.10 and the three reserved host addresses to .1/.2/.3. DHCP request order alone does not guarantee these leases.
- Matching workgroups are used for the worksheet but are not an IP ping requirement. The fixture permits private-network ICMP echo before ping tests. All six directions are required across Server, Desktop and Laptop.
- Services are configured on all three devices. DNS Client is already running. The three specified discovery services require Automatic startup and Running state.
- Firewall-off, public-profile feature access, public-folder sharing and password-protection-off controls reproduce the isolated worksheet. Their consequences and a protected deployment configuration are shown in the lab. Rules do not filter traffic while the firewall is disabled. No host settings are changed.
- Software configuration separately teaches enabled protection and authorized RDP with NLA. Its printer fixture uses 192.168.9.20.

## Technical references

- [Rufus official FAQ](https://github.com/pbatard/rufus/wiki/FAQ): firmware/partition compatibility and file-system handling.
- [Microsoft Windows Setup partition styles](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-installing-using-the-mbr-or-gpt-partition-style?view=windows-11): UEFI/GPT installation.
- [Microsoft network discovery dependencies](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/cannot-turn-on-network-discovery): service and firewall requirements.
- [Microsoft Windows Firewall overview](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/): profiles, traffic rules and default filtering.

## Verification

`test/guided_setup_workbench_test.dart` exercises complete successful workflows plus wrong USB sequence, MBR/UEFI mismatch, wrong partition, USB boot loop, driver ordering and incomplete ping checks. `MOBILE_SETUP=true` repeats the flows at phone width. `CAPTURE_SETUP=true` writes a rendered Rufus review image under `build/ui-review`.

Catalog, layout, walkthrough and existing generic-operation tests verify that the new labs are used in the correct routes without replacing unrelated simulations.
