import 'package:flutter/services.dart';

class RetrytechPlugin {
  final methodChannel = const MethodChannel('retrytech_plugin');

  Future<bool?> runTheCommand(String command) {
    return methodChannel.invokeMethod("runFFmpegCommand", command);
  }

  Future<bool?> shareToInstagram(String command) {
    return methodChannel.invokeMethod("shareToInstagram", command);
  }
}
