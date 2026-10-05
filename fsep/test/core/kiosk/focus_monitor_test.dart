import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/kiosk/focus_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('emits when the app becomes inactive, paused, or hidden', () async {
    final monitor = FocusMonitor();
    final events = <FocusEvent>[];
    final subscription = monitor.onFocusChange.listen(events.add);

    monitor.didChangeAppLifecycleState(AppLifecycleState.inactive);
    monitor.didChangeAppLifecycleState(AppLifecycleState.paused);
    monitor.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await Future<void>.delayed(Duration.zero);

    expect(events, [FocusEvent.lost, FocusEvent.lost, FocusEvent.tabSwitched]);

    await subscription.cancel();
    monitor.dispose();
  });

  test('onFocusChange emits regained when the app resumes', () async {
    final monitor = FocusMonitor();
    final events = <FocusEvent>[];
    final subscription = monitor.onFocusChange.listen(events.add);

    monitor.didChangeAppLifecycleState(AppLifecycleState.inactive);
    monitor.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(events, [FocusEvent.lost, FocusEvent.regained]);

    await subscription.cancel();
    monitor.dispose();
  });
}
