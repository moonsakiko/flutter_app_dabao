import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'config.dart';
import 'file_helper.dart';

/// 视频信息数据类
class VideoInfo {
  final String path;           // 文件路径
  final int durationMs;        // 时长（毫秒）
  final int width;             // 宽度
  final int height;            // 高度
  final String codec;          // 编码格式
  final int bitrate;           // 比特率
  final int fileSize;          // 文件大小（字节）

  VideoInfo({
    required this.path,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.codec,
    required this.bitrate,
    required this.fileSize,
  });

  /// 格式化时长显示
  String get formattedDuration {
    final int totalSeconds = durationMs ~/ 1000;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  /// 格式化分辨率显示
  String get resolution => "${width}x$height";
}

/// FFmpeg 处理结果
class FFmpegResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;

  FFmpegResult({
    required this.success,
    this.outputPath,
    this.errorMessage,
  });
}

/// FFmpeg 服务类
/// 封装视频切割、拼接等核心功能
class FFmpegService {
  
  /// 获取视频信息
  static Future<VideoInfo?> getVideoInfo(String inputPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = session.getMediaInformation();
      
      if (info == null) {
        if (ENABLE_DEBUG_LOG) print('无法获取视频信息');
        return null;
      }
      
      // 获取时长（毫秒）
      final durationStr = info.getDuration();
      final durationMs = durationStr != null 
          ? (double.parse(durationStr) * 1000).toInt() 
          : 0;
      
      // 获取比特率
      final bitrateStr = info.getBitrate();
      final bitrate = bitrateStr != null ? int.tryParse(bitrateStr) ?? 0 : 0;
      
      // 获取视频流信息
      int width = 0;
      int height = 0;
      String codec = "unknown";
      
      final streams = info.getStreams();
      if (streams != null) {
        for (final stream in streams) {
          final type = stream.getType();
          if (type == "video") {
            width = stream.getWidth() ?? 0;
            height = stream.getHeight() ?? 0;
            codec = stream.getCodec() ?? "unknown";
            break;
          }
        }
      }
      
      // 获取文件大小
      final file = File(inputPath);
      final fileSize = await file.length();
      
      return VideoInfo(
        path: inputPath,
        durationMs: durationMs,
        width: width,
        height: height,
        codec: codec,
        bitrate: bitrate,
        fileSize: fileSize,
      );
    } catch (e) {
      if (ENABLE_DEBUG_LOG) print('获取视频信息失败: $e');
      return null;
    }
  }
  
  /// 无损切割视频
  /// [inputPath] 输入视频路径
  /// [startMs] 开始时间（毫秒）
  /// [endMs] 结束时间（毫秒）
  /// [onProgress] 进度回调（0.0 - 1.0）
  static Future<FFmpegResult> trimVideo({
    required String inputPath,
    required int startMs,
    required int endMs,
    Function(double progress)? onProgress,
  }) async {
    try {
      // 生成输出路径
      final extension = FileHelper.getFileExtension(inputPath);
      final outputPath = await FileHelper.getOutputPath(
        prefix: TRIM_FILE_PREFIX,
        extension: extension.isNotEmpty ? extension : 'mp4',
      );
      
      // 转换时间为 FFmpeg 格式（HH:MM:SS.mmm）
      final startTime = _formatTime(startMs);
      final duration = _formatTime(endMs - startMs);
      
      // 构建 FFmpeg 命令
      // -ss 放在 -i 前面可以更快地定位（输入级别 seek）
      // -c copy 表示无损复制（不重新编码）
      // -avoid_negative_ts make_zero 避免时间戳问题
      final command = '-ss $startTime -i "$inputPath" -t $duration -c copy -avoid_negative_ts make_zero "$outputPath"';
      
      if (ENABLE_DEBUG_LOG) print('执行命令: ffmpeg $command');
      
      // 计算总时长用于进度计算
      final totalDurationMs = endMs - startMs;
      
      // 执行命令
      final session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          // 命令完成回调
          final returnCode = await session.getReturnCode();
          if (ENABLE_DEBUG_LOG) {
            print('FFmpeg 完成，返回码: $returnCode');
          }
        },
        (log) {
          // 日志回调
          if (ENABLE_DEBUG_LOG) print('FFmpeg: ${log.getMessage()}');
        },
        (Statistics statistics) {
          // 进度回调
          if (onProgress != null && totalDurationMs > 0) {
            final time = statistics.getTime();
            final progress = (time / totalDurationMs).clamp(0.0, 1.0);
            onProgress(progress);
          }
        },
      );
      
      // 等待完成
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        return FFmpegResult(success: true, outputPath: outputPath);
      } else {
        final logs = await session.getAllLogs();
        final errorMsg = logs.isNotEmpty ? logs.last.getMessage() : '未知错误';
        return FFmpegResult(success: false, errorMessage: errorMsg);
      }
    } catch (e) {
      return FFmpegResult(success: false, errorMessage: e.toString());
    }
  }
  
  /// 无损拼接视频
  /// [inputPaths] 输入视频路径列表（按顺序拼接）
  /// [onProgress] 进度回调（0.0 - 1.0）
  static Future<FFmpegResult> mergeVideos({
    required List<String> inputPaths,
    Function(double progress)? onProgress,
  }) async {
    if (inputPaths.length < 2) {
      return FFmpegResult(success: false, errorMessage: '至少需要2个视频文件');
    }
    
    try {
      // 生成 concat 文件（FFmpeg 拼接需要的列表文件）
      final tempDir = await FileHelper.getOutputPath(prefix: 'concat_list_');
      final concatFilePath = tempDir.replaceAll('.mp4', '.txt');
      
      // 写入文件列表
      final StringBuffer fileListContent = StringBuffer();
      for (final path in inputPaths) {
        // 使用单引号包裹路径，并转义单引号
        final escapedPath = path.replaceAll("'", "'\\''");
        fileListContent.writeln("file '$escapedPath'");
      }
      
      await File(concatFilePath).writeAsString(fileListContent.toString());
      
      if (ENABLE_DEBUG_LOG) {
        print('拼接文件列表:\n$fileListContent');
      }
      
      // 生成输出路径
      final extension = FileHelper.getFileExtension(inputPaths.first);
      final outputPath = await FileHelper.getOutputPath(
        prefix: MERGE_FILE_PREFIX,
        extension: extension.isNotEmpty ? extension : 'mp4',
      );
      
      // 构建 FFmpeg 命令
      // -f concat 使用拼接模式
      // -safe 0 允许使用绝对路径
      // -c copy 无损复制
      final command = '-f concat -safe 0 -i "$concatFilePath" -c copy "$outputPath"';
      
      if (ENABLE_DEBUG_LOG) print('执行命令: ffmpeg $command');
      
      // 计算总时长（用于进度估算）
      int totalDurationMs = 0;
      for (final path in inputPaths) {
        final info = await getVideoInfo(path);
        if (info != null) {
          totalDurationMs += info.durationMs;
        }
      }
      
      // 执行命令
      final session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          // 清理临时文件
          await FileHelper.deleteFile(concatFilePath);
        },
        (log) {
          if (ENABLE_DEBUG_LOG) print('FFmpeg: ${log.getMessage()}');
        },
        (Statistics statistics) {
          if (onProgress != null && totalDurationMs > 0) {
            final time = statistics.getTime();
            final progress = (time / totalDurationMs).clamp(0.0, 1.0);
            onProgress(progress);
          }
        },
      );
      
      // 等待完成
      final returnCode = await session.getReturnCode();
      
      // 清理临时文件
      await FileHelper.deleteFile(concatFilePath);
      
      if (ReturnCode.isSuccess(returnCode)) {
        return FFmpegResult(success: true, outputPath: outputPath);
      } else {
        final logs = await session.getAllLogs();
        final errorMsg = logs.isNotEmpty ? logs.last.getMessage() : '未知错误';
        return FFmpegResult(success: false, errorMessage: errorMsg);
      }
    } catch (e) {
      return FFmpegResult(success: false, errorMessage: e.toString());
    }
  }
  
  /// 检查多个视频是否兼容拼接
  /// 返回 null 表示兼容，否则返回不兼容的原因
  static Future<String?> checkMergeCompatibility(List<String> inputPaths) async {
    if (inputPaths.length < 2) {
      return '至少需要2个视频文件';
    }
    
    // 获取第一个视频的信息作为基准
    final firstInfo = await getVideoInfo(inputPaths.first);
    if (firstInfo == null) {
      return '无法读取第一个视频的信息';
    }
    
    // 检查其他视频是否兼容
    for (int i = 1; i < inputPaths.length; i++) {
      final info = await getVideoInfo(inputPaths[i]);
      if (info == null) {
        return '无法读取第${i + 1}个视频的信息';
      }
      
      // 检查分辨率
      if (info.width != firstInfo.width || info.height != firstInfo.height) {
        return '视频分辨率不一致\n'
            '视频1: ${firstInfo.resolution}\n'
            '视频${i + 1}: ${info.resolution}';
      }
      
      // 检查编码格式
      if (info.codec != firstInfo.codec) {
        return '视频编码格式不一致\n'
            '视频1: ${firstInfo.codec}\n'
            '视频${i + 1}: ${info.codec}';
      }
    }
    
    return null; // 兼容
  }
  
  /// 格式化时间（毫秒 -> HH:MM:SS.mmm）
  static String _formatTime(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final int millis = ms % 1000;
    
    return "${hours.toString().padLeft(2, '0')}:"
        "${minutes.toString().padLeft(2, '0')}:"
        "${seconds.toString().padLeft(2, '0')}."
        "${millis.toString().padLeft(3, '0')}";
  }
}
