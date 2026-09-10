enum CableKind { straight, crossover }

enum CableStage {
  jacket,
  spline,
  untwist,
  arrange,
  trim,
  insert,
  crimp,
  finished,
}

class CableEnd {
  CableStage stage = CableStage.jacket;
  final Set<int> separatedPairs = {};
  final List<int?> pins = List.filled(8, null);
  bool seated = false;
  void tool(String tool) {
    if (stage == CableStage.jacket && tool == 'stripper') {
      stage = CableStage.spline;
    } else if (stage == CableStage.spline && tool == 'cutters') {
      stage = CableStage.untwist;
    } else if (stage == CableStage.trim && tool == 'cutters') {
      stage = CableStage.insert;
    } else if (stage == CableStage.crimp && seated && tool == 'crimper') {
      stage = CableStage.finished;
    }
  }

  void untwist(int pair) {
    if (stage != CableStage.untwist || pair < 0 || pair > 3) return;
    separatedPairs.add(pair);
    if (separatedPairs.length == 4) stage = CableStage.arrange;
  }

  void place(int wire, int pin) {
    if (stage != CableStage.arrange ||
        wire < 0 ||
        wire > 7 ||
        pin < 0 ||
        pin > 7) {
      return;
    }
    final previous = pins.indexOf(wire);
    if (previous >= 0) pins[previous] = pins[pin];
    pins[pin] = wire;
  }

  void finishOrder() {
    if (stage == CableStage.arrange && pins.every((p) => p != null)) {
      stage = CableStage.trim;
    }
  }

  void insert() {
    if (stage != CableStage.insert) return;
    seated = true;
    stage = CableStage.crimp;
  }
}

class Rj45Session {
  // IDs are colors, never the student's assigned pin numbers.
  static const colors = [
    'White/Orange',
    'Orange',
    'White/Green',
    'Green',
    'White/Blue',
    'Blue',
    'White/Brown',
    'Brown',
  ];
  static const t568b = [0, 1, 2, 5, 4, 3, 6, 7];
  static const t568a = [2, 3, 0, 5, 4, 1, 6, 7];
  final CableKind kind;
  final List<CableEnd> ends = [CableEnd(), CableEnd()];
  final List<int?> ports = [null, null];
  Rj45Session(this.kind);
  bool get prepared => ends.every((e) => e.stage == CableStage.finished);
  bool get readyToTest =>
      prepared && ports[0] != null && ports[1] != null && ports[0] != ports[1];
  void connect(int end, int port) {
    if (!prepared || end < 0 || end > 1 || port < 0 || port > 1) return;
    for (var i = 0; i < 2; i++) {
      if (ports[i] == end) ports[i] = null;
    }
    ports[port] = end;
  }

  List<int> get wireMap {
    if (!readyToTest) return [];
    final main = ends[ports[0]!].pins;
    final remote = ends[ports[1]!].pins;
    return main.map((wire) => remote.indexOf(wire) + 1).toList();
  }

  List<int> get expectedMap => kind == CableKind.straight
      ? [1, 2, 3, 4, 5, 6, 7, 8]
      : [3, 6, 1, 4, 5, 2, 7, 8];
  bool same(List<int?> a, List<int> b) =>
      List.generate(8, (i) => a[i] == b[i]).every((v) => v);
  bool get standardEnds {
    final a = ends[0].pins, b = ends[1].pins;
    return kind == CableKind.straight
        ? (same(a, t568a) && same(b, t568a)) ||
              (same(a, t568b) && same(b, t568b))
        : (same(a, t568a) && same(b, t568b)) ||
              (same(a, t568b) && same(b, t568a));
  }

  bool get passed => readyToTest && standardEnds && same(wireMap, expectedMap);
  void reterminate(int end) {
    ends[end] = CableEnd();
    ports.fillRange(0, 2, null);
  }
}
