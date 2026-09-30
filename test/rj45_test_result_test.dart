import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/rj45_session.dart';
import 'package:icteach/widgets/rj45_test_result.dart';

void _finish(CableEnd end, List<int> order) {
  end.tool('stripper');
  end.tool('cutters');
  for (var pair = 0; pair < 4; pair++) {
    end.untwist(pair);
  }
  for (var pin = 0; pin < 8; pin++) {
    end.place(order[pin], pin);
  }
  end.finishOrder();
  end.tool('cutters');
  end.insert();
  end.tool('crimper');
}

Rj45Session _testedSession({required bool valid}) {
  final session = Rj45Session(CableKind.straight);
  final first = List<int>.of(Rj45Session.t568b);
  if (!valid) {
    first[0] = 1;
    first[1] = 0;
  }
  _finish(session.ends[0], first);
  _finish(session.ends[1], Rj45Session.t568b);
  session.connect(0, 0);
  session.connect(1, 1);
  return session;
}

void main() {
  for (final size in [const Size(360, 800), const Size(1000, 800)]) {
    testWidgets('LAN result is responsive at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Rj45TestResult(
                session: _testedSession(valid: false),
                onRetry: (_) {},
                onSubmit: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('LAN TEST FAILED'), findsOneWidget);
      expect(find.byKey(const ValueKey('lan-pin-1')), findsOneWidget);
      expect(find.text('Expected 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('passing result uses success summary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Rj45TestResult(
            session: _testedSession(valid: true),
            onRetry: (_) {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    expect(find.text('LAN TEST PASSED'), findsOneWidget);
    expect(find.text('8/8'), findsOneWidget);
    expect(
      find.text('All pins match the selected cable standard.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
