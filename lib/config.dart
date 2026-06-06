// Conditional import: selects the correct platform implementation at compile time.
// - On web: loads platform_config_web.dart (no dart:io)
// - On native (Android/iOS/desktop): loads platform_config_native.dart (uses dart:io)
import 'platform_config_stub.dart'
    if (dart.library.js_interop) 'platform_config_web.dart'
    if (dart.library.io) 'platform_config_native.dart';

class ApiConfig {
  static String get baseUrl => getPlatformBaseUrl();
}
