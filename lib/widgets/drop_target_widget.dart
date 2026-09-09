import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/simulation_model.dart';

class DropTargetWidget extends StatelessWidget {
  final String slotId;
  final DraggableItem? placedItem;
  final bool isComplete;
  final Function(String, String) onDrop;
  final double width;
  final double height;
  final bool immersive;
  final bool Function(String itemId)? canAccept;
  final DraggableItem? specimenItem;
  final VoidCallback? onInspectSpecimen;
  final bool workflowMode;
  final bool compact;

  const DropTargetWidget({
    super.key,
    required this.slotId,
    this.placedItem,
    required this.isComplete,
    required this.onDrop,
    this.width = 120,
    this.height = 100,
    this.immersive = false,
    this.canAccept,
    this.specimenItem,
    this.onInspectSpecimen,
    this.workflowMode = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = placedItem != null;

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        onDrop(details.data, slotId);
      },
      builder: (context, candidateData, rejectedData) {
        final candidateCompatible =
            candidateData.isNotEmpty &&
            (canAccept?.call(candidateData.first!) ?? true);
        final hasCandidate = candidateData.isNotEmpty && candidateCompatible;
        final hasRejected =
            rejectedData.isNotEmpty ||
            (candidateData.isNotEmpty && !candidateCompatible);
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: specimenItem != null
                ? const Color(0xFF132C46)
                : immersive && isFilled
                ? Colors.transparent
                : isFilled
                ? _getColorForCategory(
                    placedItem!.category,
                  ).withValues(alpha: 0.1)
                : (hasCandidate
                      ? Colors.green.withValues(alpha: 0.25)
                      : hasRejected
                      ? Colors.red.withValues(alpha: 0.25)
                      : immersive
                      ? Colors.black.withValues(alpha: 0.22)
                      : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(immersive ? 5 : 10),
            border: Border.all(
              color: specimenItem != null
                  ? const Color(0xFF132C46)
                  : immersive && isFilled
                  ? Colors.transparent
                  : isFilled
                  ? _getColorForCategory(placedItem!.category)
                  : (hasCandidate
                        ? Colors.greenAccent
                        : hasRejected
                        ? Colors.redAccent
                        : immersive
                        ? Colors.white70
                        : Colors.grey.shade300),
              width: isFilled ? (immersive ? 0 : 2) : 1,
            ),
            boxShadow: [
              if (hasCandidate || hasRejected)
                BoxShadow(
                  color: (hasCandidate ? Colors.green : Colors.red).withValues(
                    alpha: 0.35,
                  ),
                  blurRadius: 14,
                ),
            ],
          ),
          child: compact && specimenItem == null
              ? Tooltip(
                  message: placedItem?.name ?? _getSlotLabel(slotId),
                  child: _compactContent(),
                )
              : isFilled
              ? workflowMode
                    ? _buildWorkflowComplete()
                    : specimenItem != null
                    ? _buildIdentifiedSpecimen()
                    : immersive
                    ? Center(
                        child: _buildImage(
                          placedItem!,
                          imageWidth: width,
                          imageHeight: height,
                        ),
                      )
                    : Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildImage(
                                  placedItem!,
                                  imageWidth: width * 0.88,
                                  imageHeight: height * 0.76,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  placedItem!.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _getColorForCategory(
                                      placedItem!.category,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isComplete)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: placedItem!.correctSlot == slotId
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      placedItem!.correctSlot == slotId
                                          ? '✓'
                                          : '✗',
                                      style: TextStyle(
                                        color: placedItem!.correctSlot == slotId
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isComplete)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: placedItem!.correctSlot == slotId
                                      ? Colors.green
                                      : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  placedItem!.correctSlot == slotId
                                      ? Icons.check
                                      : Icons.close,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      )
              : specimenItem != null
              ? _buildSpecimenCard()
              : immersive && slotId.startsWith('pin')
              ? Center(
                  child: Text(
                    'PIN ${slotId.replaceFirst('pin', '')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getSlotIcon(slotId),
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSlotLabel(slotId),
                      style: TextStyle(
                        fontSize: 11,
                        color: immersive ? Colors.white : Colors.grey.shade500,
                        fontWeight: immersive
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _compactContent() {
    if (placedItem != null && immersive) {
      return Center(
        child: _buildImage(placedItem!, imageWidth: width, imageHeight: height),
      );
    }
    if (placedItem != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFittedImage(
                placedItem!,
                imageWidth: width,
                imageHeight: height,
              ),
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            bottom: 2,
            child: Text(
              placedItem!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          _getSlotLabel(slotId),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: immersive ? Colors.white : const Color(0xFF334E68),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowComplete() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE6085D48),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STAGE ${placedItem!.step} VERIFIED',
                  style: const TextStyle(
                    color: Color(0xFFA7F3D0),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                Text(
                  placedItem!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentifiedSpecimen() {
    return InkWell(
      onTap: onInspectSpecimen,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
              child: _buildFittedImage(
                specimenItem!,
                imageWidth: width,
                imageHeight: height,
              ),
            ),
          ),
          Positioned(
            left: 5,
            right: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xE6006D4A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      placedItem!.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecimenCard() {
    final specimenNumber = switch (slotId) {
      'cpu_target' => '01',
      'ram_target' => '02',
      'gpu_target' => '03',
      'motherboard_target' => '04',
      'storage_target' => '05',
      'psu_target' => '06',
      _ => '--',
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInspectSpecimen,
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 22, 8, 24),
                child: _buildFittedImage(
                  specimenItem!,
                  imageWidth: width,
                  imageHeight: height,
                ),
              ),
            ),
            Positioned(
              left: 7,
              top: 5,
              child: Text(
                'SPECIMEN $specimenNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const Positioned(
              right: 6,
              top: 4,
              child: Icon(
                Icons.zoom_in_rounded,
                color: Color(0xFF7DD3FC),
                size: 18,
              ),
            ),
            const Positioned(
              left: 7,
              right: 7,
              bottom: 5,
              child: Text(
                'Inspect or drop label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBAE6FD),
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(
    DraggableItem item, {
    required double imageWidth,
    required double imageHeight,
  }) {
    if (immersive && slotId == 'ram_slot') {
      return SizedBox(
        width: imageWidth,
        height: imageHeight,
        child: RotatedBox(
          quarterTurns: 1,
          child: _buildFittedImage(
            item,
            imageWidth: imageHeight,
            imageHeight: imageWidth,
          ),
        ),
      );
    }
    return _buildFittedImage(
      item,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  Widget _buildFittedImage(
    DraggableItem item, {
    required double imageWidth,
    required double imageHeight,
  }) {
    if (item.imageUrl.endsWith('.svg')) {
      return SvgPicture.asset(
        item.imageUrl,
        width: imageWidth,
        height: imageHeight,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      item.imageUrl,
      width: imageWidth,
      height: imageHeight,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.devices_other_rounded, color: Color(0xFF486581)),
    );
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'processor':
        return Colors.purple;
      case 'memory':
        return Colors.blue;
      case 'graphics':
        return Colors.green;
      case 'power':
        return Colors.orange;
      case 'storage':
        return Colors.red;
      case 'motherboard':
        return Colors.cyan;
      case 'network':
        return Colors.indigo;
      case 'cable':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getSlotIcon(String slotId) {
    if (slotId.contains('cpu') || slotId.contains('processor')) {
      return Icons.memory_rounded;
    }
    if (slotId.contains('ram') || slotId.contains('storage')) {
      return Icons.storage_rounded;
    }
    if (slotId.contains('power') || slotId.contains('psu')) {
      return Icons.power_rounded;
    }
    if (slotId.contains('router') ||
        slotId.contains('switch') ||
        slotId.contains('network') ||
        slotId.contains('gateway') ||
        slotId.contains('dns')) {
      return Icons.lan_outlined;
    }
    if (slotId.contains('pin') || slotId.contains('cable')) {
      return Icons.cable_rounded;
    }
    if (slotId.contains('install') ||
        slotId.contains('config') ||
        slotId.contains('stage')) {
      return Icons.build_circle_outlined;
    }
    if (slotId.contains('check') || slotId.contains('test')) {
      return Icons.troubleshoot_rounded;
    }
    return Icons.add_circle_outline_rounded;
  }

  String _getSlotLabel(String slotId) {
    if (slotId.startsWith('pin')) return 'PIN ${slotId.substring(3)}';
    switch (slotId) {
      case 'cpu_socket':
        return 'CPU Socket';
      case 'ram_slot':
        return 'RAM Slot';
      case 'pcie_slot':
        return 'PCIe Slot';
      case 'psu_mount':
        return 'PSU Mount';
      case 'storage_bay':
        return 'Storage Bay';
      case 'motherboard_tray':
        return 'Motherboard Tray';
      case 'power_slot':
        return 'ATX 24-PIN\nMAIN POWER';
      case 'cpu_power_slot':
        return 'EPS12V 8-PIN\nCPU POWER';
      case 'gpu_power_slot':
        return 'PCIe 6+2-PIN\nGPU POWER';
      case 'sata_slot':
        return 'SATA 7-PIN\nDATA PORT';
      case 'front_panel_slot':
        return 'F_PANEL\nHEADER PINS';
      case 'readiness_check':
        return '01  READINESS + BACKUP';
      case 'boot_media':
        return '02  VERIFIED INSTALL MEDIA';
      case 'firmware_setup':
        return '03  UEFI FIRMWARE SETUP';
      case 'installer_setup':
        return '04  INSTALLER + EDITION';
      case 'storage_setup':
        return '05  GPT DISK PARTITIONING';
      case 'system_install':
        return '06  INSTALL SYSTEM FILES';
      case 'oobe_setup':
        return '07  OUT-OF-BOX SETUP';
      case 'driver_install':
        return '08  DRIVERS + DEVICE CHECK';
      case 'update_system':
        return '09  UPDATES + ACTIVATION';
      case 'validation_stage':
        return '10  FINAL VALIDATION';
      case 'assembly_test_station':
        return 'POST + SAFETY TEST';
      case 'cable_test_station':
        return 'INSPECT + POWER TEST';
      case 'software_requirements':
        return 'CLIENT REQUIREMENTS';
      case 'cpu_target':
      case 'ram_target':
      case 'gpu_target':
      case 'psu_target':
      case 'motherboard_target':
      case 'storage_target':
        return 'Label Here';
      case 'router_position':
        return 'Router';
      case 'switch_position':
        return 'Switch';
      case 'pc_position':
        return 'PC';
      case 'server_position':
        return 'Server';
      case 'printer_position':
        return 'Printer';
      case 'modem_position':
        return 'Modem';
      default:
        return slotId.replaceAll('_', ' ').toUpperCase();
    }
  }
}
