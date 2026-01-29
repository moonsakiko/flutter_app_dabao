// ========================================
// FFmpeg 服务 - 通过 MethodChannel 调用 Kotlin 原生层
// ========================================

import 'package:flutter/services.dart';
import '../utils/time_parser.dart';

/// FFmpeg 服务 - 通过 MethodChannel 调用 Kotlin 原生层
class FFmpegService {
  static const _channel = MethodChannel('com.videocutter/ffmpeg');

  /// 检查 FFmpeg 是否可用
  static Future<bool> isReady() async {
    try {
      return await _channel.invokeMethod('isReady') == true;
    } catch (e) {
      print('❌ isReady error: $e');
      return false;
    }
  }

  /// 分析视频元数据
  static Future<VideoMeta?> analyzeVideo(String path) async {
    try {
      final result = await _channel.invokeMethod('analyzeVideo', {'path': path});
      if (result == null) return null;
      
      final map = Map<String, dynamic>.from(result);
      
      // 解析帧率 (可能是 "30/1" 格式)
      double fps = 0;
      final fpsRaw = map['fps']?.toString() ?? '0';
      if (fpsRaw.contains('/')) {
        final parts = fpsRaw.split('/');
        final num = double.tryParse(parts[0]) ?? 0;
        final den = double.tryParse(parts[1]) ?? 1;
        fps = den > 0 ? num / den : 0;
      } else {
        fps = double.tryParse(fpsRaw) ?? 0;
      }
      
      return VideoMeta(
        path: path,
        codec: map['codec'] ?? 'unknown',
        width: map['width'] ?? 0,
        height: map['height'] ?? 0,
        fps: fps,
        duration: (map['duration'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      print('❌ analyzeVideo error: $e');
      return null;
    }
  }

  /// 无损剪切视频
  static Future<bool> cutVideo({
    required String input,
    required String output,
    required double startSeconds,
    required double endSeconds,
  }) async {
    try {
      return await _channel.invokeMethod('cutVideo', {
        'input': input,
        'output': output,
        'start': TimeParser.formatForFFmpeg(startSeconds),
        'end': TimeParser.formatForFFmpeg(endSeconds),
      }) == true;
    } catch (e) {
      print('❌ cutVideo error: $e');
      return false;
    }
  }

  /// 无损拼接视频 (同规格)
  static Future<bool> stitchVideos({
    required List<String> inputs,
    required String output,
  }) async {
    try {
      return await _channel.invokeMethod('stitchVideos', {
        'inputs': inputs,
        'output': output,
      }) == true;
    } catch (e) {
      print('❌ stitchVideos error: $e');
      return false;
    }
  }
}

/// 视频元数据
class VideoMeta {
  final String path;
  final String codec;
  final int width;
  final int height;
  final double fps;
  final double duration;
  
  String? groupLabel;
  int? groupColorIndex;
  
  VideoMeta({
    required this.path,
    required this.codec,
    required this.width,
    required this.height,
    required this.fps,
    required this.duration,
  });
  
  String get fingerprint => '${codec}_${width}x${height}_${fps.round()}';
  String get fileName => path.split('/').last;
  String get resolution => '${width}x$height';
  
  String formatDuration() => TimeParser.formatSeconds(duration);
}
