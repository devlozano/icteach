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
        expect(find.byType(NavigationDestination), findsNWidgets(5));
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          4,
        );
        expect(find.text('Discussions'), findsOneWidget);
        expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
        await tester.tap(find.text('Profile'));
        expect(selected, trainer ? 2 : 4);
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.text('More tools'), findsOneWidget);
        expect(find.text('Modules'), findsOneWidget);
        expect(find.text('Class Monitoring'), findsOneWidget);
        await tester.ensureVisible(find.text('Class Monitoring'));
        await tester.tap(find.text('Class Monitoring'));
        await tester.pumpAndSettle();
        expect(selected, 3);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
