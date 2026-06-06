/// Web implementation — no dart:io import needed.
/// On Flutter Web, the server runs on the same host (localhost).
String getPlatformBaseUrl() {
  return 'http://localhost:5000';
}
