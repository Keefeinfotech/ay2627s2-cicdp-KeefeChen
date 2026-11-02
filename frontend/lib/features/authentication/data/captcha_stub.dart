/// Stub used on platforms without browser APIs (Android, iOS, desktop).
///
/// CAPTCHA is a web-only concern here; native apps should use the platform
/// attestation features offered by their stores instead.
bool get isCaptchaSupported => false;

/// Always returns null on non-web platforms.
Future<String?> requestCaptchaToken({required String siteKey}) async => null;
