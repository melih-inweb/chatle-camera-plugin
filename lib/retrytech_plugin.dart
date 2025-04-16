import 'package:flutter/services.dart';

class RetrytechPlugin {
  final methodChannel = const MethodChannel('retrytech_plugin');

  Future<bool?> runTheCommand(String command) {
    return methodChannel.invokeMethod("runFFmpegCommand", command);
  }

  Future<bool?> shareToInstagram(String command) {
    return methodChannel.invokeMethod("shareToInstagram", command);
  }

  Future<bool?> mergeAudioAndVideo(
      {required String inputPath, required String audioPath, required String outputPath}) {
    return methodChannel.invokeMethod("mergeAudioAndVideo", {
      'input_path': inputPath,
      'audio_path': audioPath,
      'output_path': outputPath
    });
  }

  Future<bool?> extractAudio(
      {required String inputPath, required String outputPath}) {
    return methodChannel.invokeMethod("extractAudio", {
      'input_path': inputPath,
      'output_path': outputPath
    });
  }

  Future<bool?> addWaterMarkInVideo(
      {required String inputPath, required String thumbnailPath, required String username, required String outputPath}) {
    return methodChannel.invokeMethod("addWaterMarkInVideo", {
      'input_path': inputPath,
      'thumbnail_path': thumbnailPath,
      'username': username,
      'output_path': outputPath
    });
  }

}






