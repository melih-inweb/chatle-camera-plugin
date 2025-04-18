import 'package:flutter/services.dart';

class RetrytechPlugin {
  static var shared = RetrytechPlugin();
  final methodChannel = const MethodChannel('retrytech_plugin');

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

  Future<bool?> applyFilterToImage({
    required String inputPath,
    required List<double> filterValues,
    required String outputPath,
  }) {
    return methodChannel.invokeMethod("applyFilterToImage", {
      'input_path': inputPath,
      'filter_values': filterValues,
      'output_path': outputPath
    });
  }

  Future<bool?> createVideoFromImage({
    required String inputPath,
    required String outputPath,
    required bool shouldBothMusics,
    String? audioPath,
    List<double> filterValues = const [],
    double? audioStartTimeInMS,
    double videoTotalDurationInSec,
  }) {
    return methodChannel.invokeMethod("createVideoFromImage", {
      'input_path': inputPath,
      'audio_path': audioPath,
      'filter_values': filterValues,
      'output_path': outputPath,
      'should_add_both_musics': shouldBothMusics,
      'audio_start_time_in_ms': audioStartTimeInMS,
      'video_total_duration_in_sec': videoTotalDurationInSec,
    });
  }
}
