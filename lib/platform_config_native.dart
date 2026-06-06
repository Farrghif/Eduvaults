import 'dart:io' show Platform;

/// Native implementation — safely uses dart:io since this file
/// is only loaded on non-web platforms (Android, iOS, desktop).
String getPlatformBaseUrl() {
  if (Platform.isAndroid) {
    // Android Emulator -> 10.0.2.2 adalah alias untuk host machine localhost
    return 'http://10.0.2.2:5000';
  }

  // iOS Simulator, macOS, Windows, Linux -> gunakan localhost
  return 'http://localhost:5000';
}
