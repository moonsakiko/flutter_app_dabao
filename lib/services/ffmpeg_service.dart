// ========================================
// FFmpeg 服务 - 使用 ffmpeg_kit_flutter 插件
// ========================================

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'dart:io';
import '../utils/time_parser.dart';

/// FFmpeg 服务 - 通过 ffmpeg_kit_flutter 插件执行命令
class FFmpegService {
  /// 检查 FFmpeg 是否可用
  static Future<bool> isReady() async {
    try {
      // ffmpeg_kit 插件始终可用
      return true;
    } catch (e) {
      print('❌ isReady error: $e');
      return false;
    }
  }

  /// 分析视频元数据
  static Future<VideoMeta?> analyzeVideo(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      
      if (info == null) return null;
      
      final streams = info.getStreams();
      if (streams == null || streams.isEmpty) return null;
      
      // 查找视频流
      final videoStream = streams.firstWhere(
        (s) => s.getType() == 'video',
        orElse: () => streams.first,
      );
      
      final width = videoStream.getWidth() ?? 0;
      final height = videoStream.getHeight() ?? 0;
      final codec = videoStream.getCodec() ?? 'unknown';
      
      // 解析帧率
      double fps = 0;
      final fpsRaw = videoStream.getRealFrameRate() ?? '0';
      if (fpsRaw.contains('/')) {
        final parts = fpsRaw.split('/');
        final num = double.tryParse(parts[0]) ?? 0;
        final den = double.tryParse(parts[1]) ?? 1;
        fps = den > 0 ? num / den : 0;
      } else {
        fps = double.tryParse(fpsRaw) ?? 0;
      }
      
      // 获取时长
      final durationStr = info.getDuration() ?? '0';
      final duration = double.tryParse(durationStr) ?? 0;
      
      return VideoMeta(
        path: path,
        codec: codec,
        width: width,
        height: height,
        fps: fps,
        duration: duration,
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
      final startTime = TimeParser.formatForFFmpeg(startSeconds);
      final endTime = TimeParser.formatForFFmpeg(endSeconds);
      
      // 构建 FFmpeg 命令
      final command = '-y -ss $startTime -to $endTime -i "$input" -c copy -avoid_negative_ts 1 "$output"';
      
      print('🎬 执行剪切: $command');
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ 剪切成功: $output');
        return true;
      } else {
        final logs = await session.getLogsAsString();
        print('❌ 剪切失败: $logs');
        return false;
      }
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
      // 创建临时文件列表
      final tempDir = Directory.systemTemp;
      final listFile = File('${tempDir.path}/concat_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      // 写入文件列表
      final content = inputs.map((p) => "file '$p'").join('\n');
      await listFile.writeAsString(content);
      
      // 构建 FFmpeg 命令
      final command = '-y -f concat -safe 0 -i "${listFile.path}" -c copy "$output"';
      
      print('🎬 执行拼接: $command');
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      // 删除临时文件
      if (await listFile.exists()) {
        await listFile.delete();
      }
      
      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ 拼接成功: $output');
        return true;
      } else {
        final logs = await session.getLogsAsString();
        print('❌ 拼接失败: $logs');
        return false;
      }
    } catch (e) {
      print('❌ stitchVideos error: $e');
      return false;
    }
  }

  /// 异规格拼接 (需重编码)
  static Future<bool> stitchVideosTranscode({
    required List<String> inputs,
    required String output,
    int crf = 18,
  }) async {
    try {
      // 构建 filter_complex 命令
      final filterInputs = List.generate(inputs.length, (i) => '[$i:v][$i:a]').join('');
      final inputArgs = inputs.map((p) => '-i "$p"').join(' ');
      
      final command = '-y $inputArgs -filter_complex "${filterInputs}concat=n=${inputs.length}:v=1:a=1[outv][outa]" -map "[outv]" -map "[outa]" -c:v libx264 -crf $crf -preset fast -c:a aac "$output"';
      
      print('🎬 执行转码拼接: $command');
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ 转码拼接成功: $output');
        return true;
      } else {
        final logs = await session.getLogsAsString();
        print('❌ 转码拼接失败: $logs');
        return false;
      }
    } catch (e) {
      print('❌ stitchVideosTranscode error: $e');
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
