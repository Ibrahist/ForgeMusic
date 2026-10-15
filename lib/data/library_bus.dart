import 'dart:async';

/// Tells the interface that songs, history, or folders changed.
class LibraryBus {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void ping() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
