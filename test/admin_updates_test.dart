import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/utils/staff_password.dart';
import 'package:icteach/widgets/performance_pie_chart.dart';

void main() {
  test(
    'staff passwords have a readable stem, four digits and a familiar symbol',
    () {
      for (var i = 0; i < 500; i++) {
        final password = generateStaffPassword();
        expect(password.length, 11);
        expect(RegExp(r'[A-Z]').allMatches(password).length, 1);
        expect(RegExp(r'[0-9]').allMatches(password).length, 4);
        expect(
          RegExp(r'^[A-Z][a-z]{5}[0-9]{4}[#!@_()&]$').hasMatch(password),
          isTrue,
        );
      }
    },
  );
  test('pie chart counts boundary scores once and ignores invalid data', () {
    expect(
      PerformancePieChart.countsFor([
        for (final score in [0, 74, 75, 89, 90, 100, -1, 101, double.nan, null])
          {'percentage': score},
      ]),
      [2, 2, 2],
    );
  });
  for (final width in [320.0, 1000.0]) {
    testWidgets('pie chart fits width ' + width.toString(), (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PerformancePieChart(
                entries: const [
                  {'percentage': 95},
                  {'percentage': 80},
                  {'percentage': 50},
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('1 (33.3%)'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty chart has no slices or invalid percentages', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PerformancePieChart(entries: [])),
      ),
    );
    expect(find.text('No performance data yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
