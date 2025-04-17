import 'package:flutter/services.dart';

class RetrytechPlugin {
  final methodChannel = const MethodChannel('retrytech_plugin');

  Future<bool?> runTheCommand(String command) {
    return methodChannel.invokeMethod("runFFmpegCommand", command);
  }

  Future<bool?> shareToInstagram(String command) {
    return methodChannel.invokeMethod("shareToInstagram", command);
  }

  Future<bool?> applyFilterAndAudioToVideo({
    required String inputPath,
    required String outputPath,
    bool shouldBothMusics = false,
    String? audioPath,
    List<double> filterValues = const [],
    double? audioStartTimeInMS,
  }) {
    return methodChannel.invokeMethod("applyFilterAndAudioToVideo", {
      'input_path': inputPath,
      'audio_path': audioPath,
      'filter_values': filterValues,
      'output_path': outputPath,
      'should_add_both_musics': shouldBothMusics,
      'audio_start_time_in_ms': audioStartTimeInMS,
    });
  }

  Future<bool?> extractAudio({
    required String inputPath,
    required String outputPath,
  }) {
    return methodChannel.invokeMethod("extractAudio", {
      'input_path': inputPath,
      'output_path': outputPath,
    });
  }

  Future<bool?> addWaterMarkInVideo({
    required String inputPath,
    required String thumbnailPath,
    required String username,
    required String outputPath,
  }) {
    return methodChannel.invokeMethod("addWaterMarkInVideo", {
      'input_path': inputPath,
      'thumbnail_path': thumbnailPath,
      'username': username,
      'output_path': outputPath,
    });
  }
}
