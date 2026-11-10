import 'package:flutter/services.dart';

/// Rejects invalid edits in full, including mixed text pasted into a score cell.
class ScoreInputFormatter extends TextInputFormatter {
  ScoreInputFormatter({this.decimal = true, this.maximum = 1000000});
  final bool decimal;
  final double maximum;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final pattern = decimal ? RegExp(r'^\d+(\.\d{0,2})?$') : RegExp(r'^\d+$');
    final number = double.tryParse(text);
    return pattern.hasMatch(text) && number != null && number <= maximum
        ? newValue
        : oldValue;
  }
}
