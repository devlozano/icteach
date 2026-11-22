import 'package:flutter/material.dart';
import '../data/motherboard_parts.dart';

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

  Future<void> _locate(Offset point) async {
    if (_located || _finished) return;
    final part = MotherboardParts.entries[_index];
    final correct = part.$3.contains(point);
    setState(() {
      _located = correct;
      if (_located) {
        _feedback = 'Correct. Loading the next part...';
      } else {
        _mistakes++;
        _feedback = 'Incorrect location. Inspect the board and try again.';
      }
    });
    if (!correct) return;
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    if (_index == MotherboardParts.entries.length - 1) {
      final score = (MotherboardParts.entries.length - _mistakes).clamp(
        0,
        MotherboardParts.entries.length,
      );
      setState(() => _finished = true);
      widget.onComplete(
        score,
        MotherboardParts.entries.length,
        score / MotherboardParts.entries.length >= .8,
      );
      return;
    }
    setState(() {
      _index++;
      _located = false;
      _feedback = null;
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PART ${_index + 1} OF ${parts.length}',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.touch_app_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  const Flexible(
                    child: Text(
                      'Tap the exact part',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_index + 1) / parts.length,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _finished ? 'Quiz complete' : 'Find the ${part.$2}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pinch to zoom and drag to inspect the motherboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              if (_feedback != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _located
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFFE8E5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _located
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFF2B8B5),
                    ),
                  ),
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _located
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF8C2020),
                      fontWeight: FontWeight.w700,
                    ),
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
                    child: Image.asset(
                      MotherboardParts.asset,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
