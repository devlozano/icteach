import 'package:flutter/material.dart';
import '../services/workspace_navigation.dart';

/// Retains a request through rebuilds; refreshes when its page is reopened.
class RetainedFutureBuilder<T> extends StatefulWidget {
  const RetainedFutureBuilder({
    super.key,
    required this.requestKey,
    required this.load,
    required this.builder,
    this.active = true,
  });
  final Object? requestKey;
  final Future<T> Function() load;
  final AsyncWidgetBuilder<T> builder;
  final bool active;
  @override
  State<RetainedFutureBuilder<T>> createState() =>
      _RetainedFutureBuilderState<T>();
}

class _RetainedFutureBuilderState<T> extends State<RetainedFutureBuilder<T>> {
  Future<T>? _future;
  Route<dynamic>? _route;
  bool _covered = false;
  @override
  void initState() {
    super.initState();
    if (widget.active) _future = widget.load();
    WorkspaceNavigation.instance.topPage.addListener(_navigationChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  void _navigationChanged() {
    final top = WorkspaceNavigation.instance.topPage.value;
    if (top == null || _route == null) return;
    if (top != _route) {
      _covered = true;
      return;
    }
    if (_covered) {
      _covered = false;
      if (widget.active && mounted) setState(() => _future = widget.load());
    }
  }

  @override
  void didUpdateWidget(covariant RetainedFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active || oldWidget.requestKey != widget.requestKey))
      _future = widget.load();
  }

  @override
  void dispose() {
    WorkspaceNavigation.instance.topPage.removeListener(_navigationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<T>(future: _future, builder: widget.builder);
}
