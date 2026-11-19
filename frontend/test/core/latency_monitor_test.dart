import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/network/latency_monitor.dart';

void main() {
  late LatencyMonitor monitor;

  setUp(() {
    monitor = LatencyMonitor.instance;
    monitor.reset();
  });

  tearDown(() => monitor.reset());

  Duration ms(int value) => Duration(milliseconds: value);

  test('starts good with no samples and hides the banner', () {
    expect(monitor.quality, NetworkQuality.good);
    expect(monitor.shouldShowBanner, isFalse);
    expect(monitor.averageLatency, isNull);
  });

  test('fast samples keep quality good', () {
    for (var i = 0; i < 6; i++) {
      monitor.record(ms(200));
    }
    expect(monitor.quality, NetworkQuality.good);
    expect(monitor.shouldShowBanner, isFalse);
  });

  test('slow rolling average flips to degraded', () {
    for (var i = 0; i < 3; i++) {
      monitor.record(ms(1800));
    }
    expect(monitor.quality, NetworkQuality.degraded);
    expect(monitor.shouldShowBanner, isTrue);
  });

  test('a single very slow sample flips to slow', () {
    monitor.record(ms(5000));
    expect(monitor.quality, NetworkQuality.slow);
  });

  test('consecutive timeouts force slow even after fast samples', () {
    for (var i = 0; i < 5; i++) {
      monitor.record(ms(100));
    }
    monitor.record(ms(12000), failed: true);
    monitor.record(ms(12000), failed: true);
    expect(monitor.quality, NetworkQuality.slow);
    expect(monitor.failureStreak, 2);
  });

  test('a fast request clears the failure streak', () {
    monitor.record(ms(12000), failed: true);
    monitor.record(ms(150));
    expect(monitor.failureStreak, 0);
  });

  test('dismiss hides the banner until recovery and re-degradation', () {
    for (var i = 0; i < 3; i++) {
      monitor.record(ms(1800));
    }
    expect(monitor.shouldShowBanner, isTrue);

    monitor.dismiss();
    expect(monitor.shouldShowBanner, isFalse);

    // Recovery re-arms the banner for the next degraded episode.
    for (var i = 0; i < 10; i++) {
      monitor.record(ms(100));
    }
    expect(monitor.shouldShowBanner, isFalse);
    for (var i = 0; i < 3; i++) {
      monitor.record(ms(1800));
    }
    expect(monitor.shouldShowBanner, isTrue);
  });

  test('recordServerError trips degraded state on its own', () {
    monitor.recordServerError();
    monitor.recordServerError();
    expect(monitor.quality, NetworkQuality.slow);
  });

  test('summary is human readable', () {
    monitor.record(ms(200));
    expect(monitor.summary, contains('ms'));
    expect(monitor.summary, contains('failure'));
  });

  test('window is bounded', () {
    for (var i = 0; i < LatencyMonitor.windowSize + 5; i++) {
      monitor.record(ms(100));
    }
    expect(monitor.averageLatency, ms(100));
  });
}
