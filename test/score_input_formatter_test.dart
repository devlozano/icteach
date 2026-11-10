import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/utils/score_input_formatter.dart';

void main() {
  test(
    'score cells reject text paste, signs, exponent and excess decimals',
    () {
      final formatter = ScoreInputFormatter();
      const previous = TextEditingValue(text: '25');
      for (final value in [
        'abc',
        '12 points',
        '-1',
        '1e3',
        'NaN',
        '1.234',
        '1000001',
      ]) {
        expect(
          formatter.formatEditUpdate(previous, TextEditingValue(text: value)),
          previous,
        );
      }
      for (final value in ['', '0', '25.', '25.50', '1000000']) {
        final next = TextEditingValue(text: value);
        expect(formatter.formatEditUpdate(previous, next), next);
      }
    },
  );
  test('submission grades accept whole numbers within 100', () {
    final formatter = ScoreInputFormatter(decimal: false, maximum: 100);
    const previous = TextEditingValue(text: '90');
    for (final value in ['101', '90.5', 'ninety']) {
      expect(
        formatter.formatEditUpdate(previous, TextEditingValue(text: value)),
        previous,
      );
    }
  });
}
