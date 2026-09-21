import 'dart:async';

Stream<List<T>> combineLatest<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) return Stream.value([]);
  late StreamController<List<T>> output;
  final subscriptions = <StreamSubscription<T>>[];
  final values = <int, T>{};
  output = StreamController(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        final index = i;
        subscriptions.add(
          streams[i].listen((value) {
            values[index] = value;
            if (values.length == streams.length)
              output.add([
                for (var j = 0; j < streams.length; j++) values[j] as T,
              ]);
          }, onError: output.addError),
        );
      }
    },
    onCancel: () async {
      await Future.wait(subscriptions.map((s) => s.cancel()));
    },
  );
  return output.stream;
}
