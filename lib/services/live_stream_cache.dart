import 'dart:async';

/// Shares one live subscription and replays its latest event to new listeners.
/// Owned by a signed-in workspace; clear it when that workspace ends.
class LiveStreamCache {
  final Map<String, _Entry<dynamic>> _entries = {};
  Stream<T> watch<T>(String key, Stream<T> Function() create) {
    final previous = _entries[key];
    if (previous?.hasError == true) {
      _entries.remove(key);
      previous!.dispose();
    }
    final entry = _entries.putIfAbsent(key, () => _Entry<T>(create));
    return (entry as _Entry<T>).stream;
  }

  Future<void> clear() async {
    final old = _entries.values.toList();
    _entries.clear();
    await Future.wait(old.map((entry) => entry.dispose()));
  }
}

class _Entry<T> {
  _Entry(this.create);
  final Stream<T> Function() create;
  final _events = StreamController<T>.broadcast(sync: true);
  StreamSubscription<T>? _source;
  T? _latest;
  bool _hasValue = false, _disposed = false;
  Object? _error;
  bool get hasError => _error != null;
  StackTrace? _trace;
  late final Stream<T> stream = Stream<T>.multi((listener) {
    if (_disposed) {
      listener.close();
      return;
    }
    final subscription = _events.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
    if (_error != null) {
      listener.addError(_error!, _trace);
    } else if (_hasValue) {
      listener.add(_latest as T);
    }
    _source ??= create().listen(
      (value) {
        if (_disposed) return;
        _latest = value;
        _hasValue = true;
        _error = null;
        _events.add(value);
      },
      onError: (Object error, StackTrace trace) {
        if (_disposed) return;
        _error = error;
        _trace = trace;
        _events.addError(error, trace);
      },
    );
  }, isBroadcast: true);
  Future<void> dispose() async {
    _disposed = true;
    await _source?.cancel();
    await _events.close();
  }
}
