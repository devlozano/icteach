import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/staff_mobile_nav.dart';

void main() {
  for (final trainer in [false, true]) {
    for (final size in [const Size(360, 640), const Size(740, 360)]) {
      testWidgets('compact navigation trainer=$trainer size=$size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: Scaffold(
                bottomNavigationBar: StaffMobileNav(
                  trainer: trainer,
                  currentIndex: 3,
                  onChanged: (i) => selected = i,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3,
        );
        await tester.tap(find.text('Modules'));
        expect(selected, trainer ? 6 : 7);
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.text('Class Monitoring'), findsOneWidget);
        await tester.tap(find.text('Class Monitoring'));
        await tester.pumpAndSettle();
        expect(selected, 3);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
