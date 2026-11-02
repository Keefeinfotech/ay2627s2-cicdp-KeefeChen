// Cloudflare Turnstile for Flutter Web.
//
// The widget script is loaded once, then a token is requested on demand.
// The token is short-lived and single-use; it is sent to the backend which
// validates it with the secret key.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('turnstile')
external _TurnstileWidget get _turnstile;

extension type _TurnstileWidget._(JSObject _) implements JSObject {
  external JSString render(web.HTMLElement container, JSObject options);
  external void execute(JSString widgetId);
  external void remove(JSString widgetId);
}

const String _scriptUrl =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

bool get isCaptchaSupported => true;

Future<void> _ensureScript() async {
  if (globalContext.has('turnstile')) return;

  final existing = web.document.querySelector('script[data-auxilia-turnstile]');
  if (existing == null) {
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src = _scriptUrl;
    script.async = true;
    script.setAttribute('data-auxilia-turnstile', 'true');

    final loaded = Completer<void>();
    script.onload = ((web.Event _) {
      if (!loaded.isCompleted) loaded.complete();
    }).toJS;
    script.onerror = ((web.Event _) {
      if (!loaded.isCompleted) loaded.completeError('turnstile_load_failed');
    }).toJS;

    web.document.head?.append(script);
    await loaded.future.timeout(const Duration(seconds: 15));
  }

  for (var attempt = 0; attempt < 50; attempt++) {
    if (globalContext.has('turnstile')) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('turnstile_unavailable');
}

/// Renders an invisible Turnstile widget and resolves with its token.
///
/// Returns null when the challenge fails, times out, or the script cannot load
/// so callers can surface a friendly message instead of hanging.
Future<String?> requestCaptchaToken({required String siteKey}) async {
  try {
    await _ensureScript();
  } catch (_) {
    return null;
  }

  final completer = Completer<String?>();
  final container = web.document.createElement('div') as web.HTMLDivElement;
  container.id = 'auxilia-turnstile-${DateTime.now().microsecondsSinceEpoch}';
  container.style.display = 'none';
  web.document.body?.append(container);

  void cleanup() {
    container.remove();
  }

  final options = JSObject()
    ..setProperty('sitekey'.toJS, siteKey.toJS)
    ..setProperty(
      'callback'.toJS,
      ((JSString token) {
        if (!completer.isCompleted) completer.complete(token.toDart);
        cleanup();
      }).toJS,
    )
    ..setProperty(
      'error-callback'.toJS,
      ((JSAny? _) {
        if (!completer.isCompleted) completer.complete(null);
        cleanup();
      }).toJS,
    )
    ..setProperty(
      'expired-callback'.toJS,
      ((JSAny? _) {
        if (!completer.isCompleted) completer.complete(null);
        cleanup();
      }).toJS,
    );

  try {
    final widget = _turnstile.render(container, options);
    _turnstile.execute(widget);
  } catch (_) {
    cleanup();
    return null;
  }

  return completer.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      cleanup();
      return null;
    },
  );
}
