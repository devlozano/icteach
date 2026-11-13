import 'package:flutter/material.dart';
import '../data/motherboard_parts.dart';
import 'simulation_description.dart';

class MotherboardIdentification extends StatefulWidget {
  const MotherboardIdentification({super.key, required this.onComplete});
  final void Function(int, int, bool) onComplete;
  @override
  State<MotherboardIdentification> createState() =>
      _MotherboardIdentificationState();
}

class _MotherboardIdentificationState extends State<MotherboardIdentification> {
  int _index = 0, _mistakes = 0;
  bool _located = false, _finished = false;
  String? _feedback;

  void _locate(Offset point) {
    if (_located || _finished) return;
    final part = MotherboardParts.entries[_index];
    setState(() {
      _located = part.$3.contains(point);
      if (_located) {
        _feedback = part.$4;
      } else {
        _mistakes++;
        _feedback =
            'That is not the ${part.$2}. Inspect the board and try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final parts = MotherboardParts.entries;
    final part = parts[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                _finished
                    ? 'Motherboard inspection complete'
                    : 'Locate: ${part.$2}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Part ${_index + 1} of ${parts.length} • Pinch to zoom, drag to pan, tap the actual part.',
              ),
              if (_feedback != null)
                _located
                    ? SimulationDescriptionSection(
                        title: 'Part description',
                        text: _feedback!,
                      )
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8E5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF2B8B5)),
                        ),
                        child: Text(
                          _feedback!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF8C2020)),
                        ),
                      ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1168 / 1360,
                child: LayoutBuilder(
                  builder: (context, size) => GestureDetector(
                    key: const ValueKey('motherboard-image'),
                    onTapUp: (details) => _locate(
                      Offset(
                        details.localPosition.dx / size.maxWidth,
                        details.localPosition.dy / size.maxHeight,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(MotherboardParts.asset, fit: BoxFit.fill),
                        if (_located)
                          Positioned.fromRect(
                            rect: Rect.fromLTWH(
                              part.$3.left * size.maxWidth,
                              part.$3.top * size.maxHeight,
                              part.$3.width * size.maxWidth,
                              part.$3.height * size.maxHeight,
                            ),
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: .25),
                                  border: Border.all(
                                    color: Colors.greenAccent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: !_located || _finished
                ? null
                : () {
                    if (_index == parts.length - 1) {
                      setState(() => _finished = true);
                      final score = (parts.length - _mistakes).clamp(
                        0,
                        parts.length,
                      );
                      widget.onComplete(
                        score,
                        parts.length,
                        score / parts.length >= .8,
                      );
                    } else {
                      setState(() {
                        _index++;
                        _located = false;
                        _feedback = null;
                      });
                    }
                  },
            child: Text(
              _index == parts.length - 1 ? 'Finish inspection' : 'Next part',
            ),
          ),
        ),
      ],
    );
  }
}
