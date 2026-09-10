import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/rj45_session.dart';

void finish(CableEnd e, List<int> order) {
  e.tool('stripper');
  e.tool('cutters');
  for (var p = 0; p < 4; p++) {
    e.untwist(p);
  }
  for (var p = 0; p < 8; p++) {
    e.place(order[p], p);
  }
  e.finishOrder();
  e.tool('cutters');
  e.insert();
  e.tool('crimper');
}

void main() {
  test('tools and all four untwists enforce preparation order', () {
    final e = CableEnd();
    e.tool('crimper');
    e.insert();
    expect(e.stage, CableStage.jacket);
    e.tool('stripper');
    expect(e.stage, CableStage.spline);
    e.untwist(0);
    expect(e.separatedPairs, isEmpty);
    e.tool('cutters');
    for (var p = 0; p < 3; p++) {
      e.untwist(p);
    }
    expect(e.stage, CableStage.untwist);
    e.untwist(3);
    expect(e.stage, CableStage.arrange);
    e.finishOrder();
    expect(e.stage, CableStage.arrange);
  });
  for (final kind in CableKind.values) {
    test('${kind.name} wire map is computed from both manual connections', () {
      final s = Rj45Session(kind);
      finish(s.ends[0], Rj45Session.t568b);
      finish(
        s.ends[1],
        kind == CableKind.straight ? Rj45Session.t568b : Rj45Session.t568a,
      );
      expect(s.ports, [null, null]);
      expect(s.readyToTest, isFalse);
      s.connect(0, 0);
      expect(s.readyToTest, isFalse);
      s.connect(1, 1);
      expect(s.readyToTest, isTrue);
      expect(s.wireMap, s.expectedMap);
      expect(s.passed, isTrue);
      s.connect(0, 1);
      expect(s.readyToTest, isFalse);
      s.connect(1, 0);
      expect(s.passed, isTrue);
    });
  }
  test(
    'wrong color order is accepted until testing and crimp is immutable',
    () {
      final s = Rj45Session(CableKind.straight);
      final wrong = List<int>.of(Rj45Session.t568b)
        ..[0] = 1
        ..[1] = 0;
      finish(s.ends[0], wrong);
      finish(s.ends[1], Rj45Session.t568b);
      expect(s.prepared, isTrue);
      s.ends[0].place(0, 0);
      expect(s.ends[0].pins, wrong);
      s.connect(0, 0);
      s.connect(1, 1);
      expect(s.wireMap, [2, 1, 3, 4, 5, 6, 7, 8]);
      expect(s.passed, isFalse);
      s.reterminate(0);
      expect(s.ends[0].stage, CableStage.jacket);
      expect(s.ports, [null, null]);
      expect(s.ends[1].stage, CableStage.finished);
    },
  );
  test('identical nonstandard wiring does not pass training inspection', () {
    final s = Rj45Session(CableKind.straight);
    finish(s.ends[0], [0, 1, 2, 3, 4, 5, 6, 7]);
    finish(s.ends[1], [0, 1, 2, 3, 4, 5, 6, 7]);
    s.connect(0, 0);
    s.connect(1, 1);
    expect(s.wireMap, [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(s.standardEnds, isFalse);
    expect(s.passed, isFalse);
  });
}
