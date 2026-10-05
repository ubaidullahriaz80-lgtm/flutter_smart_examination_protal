import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/connectivity/connectivity_service.dart';

/// Deterministic fake — never touches the real connectivity_plus
/// platform channel. [emit] simulates a raw reading arriving from the
/// platform; [initialOnline] is what [checkIsOnline] resolves to.
class _FakeConnectivitySource implements ConnectivitySource {
  _FakeConnectivitySource({this.initialOnline = true});

  final bool initialOnline;
  final _controller = StreamController<bool>.broadcast();
  int checkCallCount = 0;

  @override
  Future<bool> checkIsOnline() async {
    checkCallCount++;
    return initialOnline;
  }

  @override
  Stream<bool> get onRawChange => _controller.stream;

  void emit(bool online) => _controller.add(online);

  Future<void> disposeFake() => _controller.close();
}

void main() {
  test('Test 1 — initial connectivity state is reported correctly', () async {
    final source = _FakeConnectivitySource(initialOnline: true);
    final service = ConnectivityService(source: source);

    await service.start();

    expect(service.currentStatus, NetworkStatus.online);
    expect(service.isOnline, isTrue);
    expect(source.checkCallCount, 1);

    await service.dispose();
    await source.disposeFake();
  });

  test('Test 1b — initial offline state is reported correctly', () async {
    final source = _FakeConnectivitySource(initialOnline: false);
    final service = ConnectivityService(source: source);

    await service.start();

    expect(service.currentStatus, NetworkStatus.offline);
    expect(service.isOnline, isFalse);

    await service.dispose();
    await source.disposeFake();
  });

  test('Test 2 — an online -> offline transition is detected', () async {
    final source = _FakeConnectivitySource(initialOnline: true);
    final service = ConnectivityService(source: source);
    await service.start();

    final statuses = <NetworkStatus>[];
    final sub = service.onStatusChange.listen(statuses.add);

    source.emit(false);
    await Future<void>.delayed(Duration.zero);

    expect(service.currentStatus, NetworkStatus.offline);
    expect(statuses, [NetworkStatus.offline]);

    await sub.cancel();
    await service.dispose();
    await source.disposeFake();
  });

  test('Test 3 — an offline -> online transition is detected', () async {
    final source = _FakeConnectivitySource(initialOnline: false);
    final service = ConnectivityService(source: source);
    await service.start();

    final statuses = <NetworkStatus>[];
    final sub = service.onStatusChange.listen(statuses.add);

    source.emit(true);
    await Future<void>.delayed(Duration.zero);

    expect(service.currentStatus, NetworkStatus.online);
    expect(statuses, [NetworkStatus.online]);

    await sub.cancel();
    await service.dispose();
    await source.disposeFake();
  });

  test(
    'Test 4 — repeated identical readings do not emit duplicate '
    'status changes',
    () async {
      final source = _FakeConnectivitySource(initialOnline: true);
      final service = ConnectivityService(source: source);
      await service.start();

      final statuses = <NetworkStatus>[];
      final sub = service.onStatusChange.listen(statuses.add);

      // Already online — repeating "online" must not emit anything.
      source.emit(true);
      source.emit(true);
      await Future<void>.delayed(Duration.zero);
      expect(statuses, isEmpty);

      // One real transition...
      source.emit(false);
      await Future<void>.delayed(Duration.zero);
      expect(statuses, [NetworkStatus.offline]);

      // ...then repeating "offline" must not emit again.
      source.emit(false);
      source.emit(false);
      await Future<void>.delayed(Duration.zero);
      expect(statuses, [NetworkStatus.offline]); // still just the one

      await sub.cancel();
      await service.dispose();
      await source.disposeFake();
    },
  );

  test(
    'Test 5 — multiple listeners can subscribe and all receive changes',
    () async {
      final source = _FakeConnectivitySource(initialOnline: true);
      final service = ConnectivityService(source: source);
      await service.start();

      final listenerA = <NetworkStatus>[];
      final listenerB = <NetworkStatus>[];
      final subA = service.onStatusChange.listen(listenerA.add);
      final subB = service.onStatusChange.listen(listenerB.add);

      source.emit(false);
      await Future<void>.delayed(Duration.zero);

      expect(listenerA, [NetworkStatus.offline]);
      expect(listenerB, [NetworkStatus.offline]);

      await subA.cancel();
      await subB.cancel();
      await service.dispose();
      await source.disposeFake();
    },
  );

  test('Test 6 — the service can be disposed safely', () async {
    final source = _FakeConnectivitySource();
    final service = ConnectivityService(source: source);
    await service.start();

    await service.dispose();

    // Emitting after dispose must not throw (subscription was cancelled).
    expect(() => source.emit(false), returnsNormally);

    await source.disposeFake();
  });

  test('start() is idempotent — calling it twice checks only once', () async {
    final source = _FakeConnectivitySource(initialOnline: true);
    final service = ConnectivityService(source: source);

    await service.start();
    await service.start();

    expect(source.checkCallCount, 1);

    await service.dispose();
    await source.disposeFake();
  });
}
