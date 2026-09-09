import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

import '../models/simulation_model.dart';

class DraggableItemWidget extends StatelessWidget {
  final DraggableItem item;
  final bool isComplete;
  final bool compact;
  final VoidCallback? onInspect;
  final bool isFocused;
  final bool labelOnly;

  const DraggableItemWidget({
    super.key,
    required this.item,
    required this.isComplete,
    this.compact = false,
    this.onInspect,
    this.isFocused = false,
    this.labelOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: item.id,
      feedback: Material(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width: 110,
          height: 82,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildVisual(size: 36),
              const SizedBox(height: 4),
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildItemCard()),
      onDragStarted: () {
        HapticFeedback.mediumImpact();
      },
      child: InkWell(
        onTap: onInspect,
        borderRadius: BorderRadius.circular(7),
        child: _buildItemCard(),
      ),
    );
  }

  Widget _buildItemCard() {
    if (compact) {
      return Container(
        width: double.infinity,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isFocused
                ? const Color(0xFF0EA5E9)
                : const Color(0xFFDCE3EA),
            width: isFocused ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (!labelOnly) ...[
              _buildVisual(size: 32),
            ] else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF172554),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.sell_outlined,
                  color: Color(0xFF93C5FD),
                  size: 16,
                ),
              ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (labelOnly)
                    const Text(
                      'IDENTIFICATION LABEL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF64748B),
                        letterSpacing: .3,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.drag_indicator_rounded,
              size: 16,
              color: Color(0xFF9AA9B7),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 110,
      height: 82,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildVisual(size: 42),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVisual({required double size}) {
    final color = _getColorForCategory(item.category);
    return SizedBox(
      width: size + 10,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildImage(size: size)),
          Positioned(
            right: -3,
            bottom: -2,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(
                _getIconForCategory(item.category),
                color: Colors.white,
                size: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage({required double size}) {
    if (item.imageUrl.endsWith('.svg')) {
      return SvgPicture.asset(
        item.imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      item.imageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        _getIconForCategory(item.category),
        size: size * .75,
        color: _getColorForCategory(item.category),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'processor':
        return Icons.memory;
      case 'memory':
        return Icons.storage;
      case 'graphics':
        return Icons.important_devices;
      case 'power':
        return Icons.power;
      case 'storage':
        return Icons.save;
      case 'motherboard':
        return Icons.settings_ethernet;
      case 'network':
        return Icons.wifi;
      case 'cable':
        return Icons.cable_rounded;
      case 'procedure':
        return Icons.format_list_numbered_rounded;
      case 'diagnostic':
        return Icons.troubleshoot_rounded;
      default:
        return Icons.device_hub;
    }
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
      case 'procedure':
        return Colors.blueGrey;
      case 'diagnostic':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}
