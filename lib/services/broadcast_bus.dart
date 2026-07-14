import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Thin wrapper around the browser [BroadcastChannel] API exposing a simple
/// string in / string out message bus.
///
/// A BroadcastChannel is shared by every same-origin tab, and crucially does
/// **not** echo messages back to the sender. That makes it a neat, dependency
/// free way to let a "leader" tab drive one or more "member" tabs — perfect for
/// trying the live session flow on a static host such as GitHub Pages.
class BroadcastBus {
  BroadcastBus(String name) : _channel = web.BroadcastChannel(name) {
    _listener = _handleEvent.toJS;
    _channel.addEventListener('message', _listener);
  }

  final web.BroadcastChannel _channel;
  late final JSFunction _listener;
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  Stream<String> get messages => _controller.stream;

  void _handleEvent(web.Event event) {
    final web.MessageEvent message = event as web.MessageEvent;
    final Object? data = message.data.dartify();
    if (data is String && !_controller.isClosed) {
      _controller.add(data);
    }
  }

  void send(String message) {
    _channel.postMessage(message.toJS);
  }

  void close() {
    _channel.removeEventListener('message', _listener);
    _channel.close();
    _controller.close();
  }
}
