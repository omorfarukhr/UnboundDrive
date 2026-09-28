import 'package:flutter/foundation.dart';

class NetworkConfig {
  /// Default bridge host:
  /// On Web: localhost
  /// On Android / Mobile: 192.168.10.42 (the host machine running the MTProto Bridge)
  static String get defaultBridgeHost {
    if (kIsWeb) return "localhost";
    return "192.168.10.42";
  }

  static String get bridgeBaseUrl => "http://$defaultBridgeHost:8086/api";
  static String get authUrl => "$bridgeBaseUrl/auth";
  static String get driveUrl => "$bridgeBaseUrl/drive";
}
