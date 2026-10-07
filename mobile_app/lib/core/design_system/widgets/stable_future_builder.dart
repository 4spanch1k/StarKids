import 'package:flutter/widgets.dart';

/// Keeps the in-flight result across rebuilds and reloads only when [cacheKey]
/// changes. This prevents API calls from restarting when an ancestor rebuilds.
class StableFutureBuilder<T> extends StatefulWidget {
  const StableFutureBuilder({
    super.key,
    required this.cacheKey,
    required this.futureFactory,
    required this.builder,
  });

  final Object cacheKey;
  final Future<T> Function() futureFactory;
  final AsyncWidgetBuilder<T> builder;

  @override
  State<StableFutureBuilder<T>> createState() => _StableFutureBuilderState<T>();
}

class _StableFutureBuilderState<T> extends State<StableFutureBuilder<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.futureFactory();
  }

  @override
  void didUpdateWidget(StableFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      _future = widget.futureFactory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(future: _future, builder: widget.builder);
  }
}
