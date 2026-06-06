/// Stub implementation — this file is used as the default import
/// and should never actually be called at runtime.
/// The conditional import in config.dart will select the correct
/// platform-specific implementation (web or native).
String getPlatformBaseUrl() {
  throw UnsupportedError(
    'Cannot determine platform base URL without dart:io or dart:html',
  );
}
