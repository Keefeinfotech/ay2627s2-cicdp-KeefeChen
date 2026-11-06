import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../home/data/task_store.dart';

/// Platform connectivity source, kept behind an interface so the background
/// sync handler can be tested without a device or plugin implementation.
abstract class ConnectivityAdapter {
  const ConnectivityAdapter();

  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

class PlusConnectivityAdapter extends ConnectivityAdapter {
  PlusConnectivityAdapter({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}

/// Drives the offline queue while the app is running.
///
/// This is intentionally not an OS-level background task: sync is attempted
/// on launch, on app resume, on every connectivity change to a usable network,
/// and on a periodic interval while the UI is alive.
class BackgroundSyncHandler with WidgetsBindingObserver {
  BackgroundSyncHandler({
    required this.store,
    ConnectivityAdapter? connectivity,
    this.interval = const Duration(minutes: 5),
  }) : _connectivity = connectivity ?? PlusConnectivityAdapter();

  final TaskStore store;
  final ConnectivityAdapter _connectivity;
  final Duration interval;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _timer;
  bool _started = false;

  bool get isRunning => _started;

  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (_) {},
    );
    _timer = Timer.periodic(interval, (_) => unawaited(_sync()));
    unawaited(_sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sync());
    }
  }

  void stop() {
    if (!_started) return;
    _started = false;

    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasNetwork = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (hasNetwork) {
      unawaited(_sync());
    }
  }

  Future<void> _sync() async {
    if (!store.isSyncAware) return;
    await store.retrySync();
  }
}
