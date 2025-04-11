import 'package:flutter/services.dart';

import 'retrytech_plugin_platform_interface.dart';

class RetrytechPlugin {
  final methodChannel = const MethodChannel('retrytech_plugin');

  Future<bool?> runTheCommand(String command) {
    return methodChannel.invokeMethod("runFFmpegCommand", command);
  }

  void shareToInstagram(String text) async {
    await methodChannel.invokeMethod('shareToInstagram', text);
  }

}
