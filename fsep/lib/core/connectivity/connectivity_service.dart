import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

abstract class ConnectivitySource {
  Future<bool> checkIsOnline();
  Stream<bool> get onRawChange;
}

class ConnectivityPlusSource implements ConnectivitySource {
  ConnectivityPlusSource({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> checkIsOnline() async {
    return _isOnline(await _connectivity.checkConnectivity());
  }

  @override
  Stream<bool> get onRawChange =>
      _connectivity.onConnectivityChanged.map(_isOnline);
}

/// Reports device connectivity status and broadcasts changes.
class ConnectivityService {
  ConnectivityService({ConnectivitySource? source})
      : _source = source ?? ConnectivityPlusSource();

  final ConnectivitySource _source;
  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();

  StreamSubscription<bool>? _subscription;

  NetworkStatus _current = NetworkStatus.online;

  NetworkStatus get currentStatus => _current;

  bool get isOnline => _current == NetworkStatus.online;

  Stream<NetworkStatus> get onStatusChange => _controller.stream;

  Future<void> start() async {
    if (_subscription != null) {
      return;
    }

    final online = await _source.checkIsOnline();
    _current = online ? NetworkStatus.online : NetworkStatus.offline;

    _subscription = _source.onRawChange.listen(_handleRawChange);
  }

  void _handleRawChange(bool online) {
    final next = online ? NetworkStatus.online : NetworkStatus.offline;
    if (next == _current) {
      return;
    }
    _current = next;
    _controller.add(next);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
