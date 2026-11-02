// Platform-selected CAPTCHA helper.
//
// Turnstile only exists in a browser, so native builds use the stub.
export 'captcha_stub.dart' if (dart.library.js_interop) 'captcha_web.dart';
