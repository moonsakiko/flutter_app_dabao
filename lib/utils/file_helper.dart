import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'config.dart';

/// 文件操作辅助类
/// 封装视频文件选择、路径生成、文件保存等功能
class FileHelper {
  
  /// 选择单个视频文件
  /// 返回文件路径，用户取消返回 null
  static Future<String?> pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        return result.files.first.path;
      }
      return null;
    } catch (e) {
      if (ENABLE_DEBUG_LOG) print('选择视频失败: $e');
      return null;
    }
  }
  
  /// 选择多个视频文件（用于拼接功能）
  /// 返回文件路径列表，用户取消返回空列表
  static Future<List<String>> pickMultipleVideos() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        // 过滤掉 path 为 null 的文件
        return result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
      }
      return [];
    } catch (e) {
      if (ENABLE_DEBUG_LOG) print('选择多个视频失败: $e');
      return [];
    }
  }
  
  /// 生成输出文件路径
  /// [prefix] 文件名前缀，如 "trimmed_" 或 "merged_"
  /// [extension] 文件扩展名，默认 "mp4"
  static Future<String> getOutputPath({
    String prefix = "",
    String extension = "mp4",
  }) async {
    // 获取应用缓存目录
    final Directory cacheDir = await getTemporaryDirectory();
    
    // 生成带时间戳的唯一文件名
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName = "$prefix$timestamp.$extension";
    
    return "${cacheDir.path}/$fileName";
  }
  
  /// 获取输出目录路径（用于保存到相册后的提示）
  static Future<String> getOutputDirectory() async {
    // Android 外部存储的 Movies 目录
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      return externalDir.path;
    }
    // 回退到应用文档目录
    final Directory docDir = await getApplicationDocumentsDirectory();
    return docDir.path;
  }
  
  /// 从路径中提取文件名
  static String getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
  
  /// 从路径中提取文件扩展名
  static String getFileExtension(String path) {
    final parts = path.split('.');
    return parts.isNotEmpty ? parts.last.toLowerCase() : '';
  }
  
  /// 格式化文件大小（字节 -> 可读字符串）
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";
    }
    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
  
  /// 检查文件是否存在
  static Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }
  
  /// 删除临时文件
  static Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (ENABLE_DEBUG_LOG) print('删除文件失败: $e');
    }
  }
}
