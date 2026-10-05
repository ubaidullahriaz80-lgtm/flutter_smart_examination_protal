import 'dart:async';

import 'package:flutter/widgets.dart';

enum FocusEvent { lost, regained, tabSwitched }

/// Monitors app lifecycle focus events for behavioral analysis during exams.
class FocusMonitor with WidgetsBindingObserver {
  FocusMonitor()
      : _controller = StreamController<FocusEvent>.broadcast();

  final StreamController<FocusEvent> _controller;

  Stream<FocusEvent> get onFocusChange => _controller.stream;

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void dispose() {
    stop();
    _controller.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden) {
      _controller.add(FocusEvent.tabSwitched);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.add(FocusEvent.lost);
    } else if (state == AppLifecycleState.resumed) {
      _controller.add(FocusEvent.regained);
    }
  }
}
