import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Network quality derived from recent request latency.
enum NetworkQuality { good, degraded, slow }

/// Rolling API-latency monitor fed by `ApiClient` (AUX-178).
///
/// Keeps a rolling window of recent request durations and consecutive
/// transport failures, and notifies listeners when quality changes so the
/// UI can show a dismissible "slow connection" banner.
class LatencyMonitor extends ChangeNotifier {
  LatencyMonitor._();

  static final LatencyMonitor instance = LatencyMonitor._();

  static const int windowSize = 10;

  /// Rolling average at or above this marks the connection degraded.
  static const Duration degradedThreshold = Duration(milliseconds: 1500);

  /// Any sample at or above this is treated as slow.
  static const Duration slowSample = Duration(milliseconds: 4000);

  /// Consecutive transport failures at or above this force slow.
  static const int slowFailureStreak = 2;

  final Queue<Duration> _samples = Queue<Duration>();
  int _failureStreak = 0;
  NetworkQuality _quality = NetworkQuality.good;
  bool _dismissed = false;

  NetworkQuality get quality => _quality;
  bool get dismissed => _dismissed;

  /// True while quality is degraded and the warning was not dismissed.
  bool get shouldShowBanner => !_dismissed && _quality != NetworkQuality.good;

  /// Rolling average over the retained window, null when empty.
  Duration? get averageLatency {
    if (_samples.isEmpty) return null;
    final totalMs = _samples.fold<int>(0, (s, d) => s + d.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ _samples.length);
  }

  int get failureStreak => _failureStreak;

  /// Rolling average in milliseconds, null before the first sample.
  int? get averageMs => averageLatency?.inMilliseconds;

  /// One-line diagnostic for logs/snackbars.
  String get summary {
    if (_samples.isEmpty && _failureStreak == 0) {
      return 'No network samples yet';
    }
    final avg = averageMs == null ? 'n/a' : '$averageMs ms';
    return 'avg $avg, $_failureStreak consecutive failure(s)';
  }

  /// Server returned 5xx. Fast error responses carry no latency signal, but
  /// a struggling backend should still trip the degraded state.
  void recordServerError() {
    _failureStreak += 1;
    final previous = _quality;
    _quality = _derive();
    if (_quality != previous) notifyListeners();
  }

  /// Record one completed call. Pass [failed] for timeouts/transport errors
  /// so sustained failure flips quality to slow.
  void record(Duration elapsed, {bool failed = false}) {
    _samples.addLast(elapsed);
    while (_samples.length > windowSize) {
      _samples.removeFirst();
    }
    _failureStreak = failed ? _failureStreak + 1 : 0;

    final previous = _quality;
    _quality = _derive();
    if (_quality == NetworkQuality.good) _dismissed = false;

    if (_quality != previous || failed) notifyListeners();
  }

  /// Hide the banner until the connection recovers and degrades again.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  /// Clears all tracked state. Called on logout so one user's degraded
  /// session does not leak into the next; also used by tests.
  void reset() {
    _samples.clear();
    _failureStreak = 0;
    _quality = NetworkQuality.good;
    _dismissed = false;
    notifyListeners();
  }

  NetworkQuality _derive() {
    if (_failureStreak >= slowFailureStreak) return NetworkQuality.slow;
    final avg = averageLatency;
    final last = _samples.isEmpty ? null : _samples.last;
    if ((avg != null && avg >= slowSample) ||
        (last != null && last >= slowSample)) {
      return NetworkQuality.slow;
    }
    if ((avg != null && avg >= degradedThreshold) ||
        (last != null && last >= degradedThreshold)) {
      return NetworkQuality.degraded;
    }
    return NetworkQuality.good;
  }
}
