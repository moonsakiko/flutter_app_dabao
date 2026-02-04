import 'package:permission_handler/permission_handler.dart';

/// 权限管理辅助类
/// 封装了安卓系统权限申请的复杂逻辑
class PermissionHelper {
  
  /// 申请存储和媒体库权限
  /// 返回 true 表示权限已授予，false 表示被拒绝
  static Future<bool> requestStoragePermission() async {
    // Android 13+ 使用新的媒体权限
    if (await Permission.videos.request().isGranted) {
      return true;
    }
    
    // Android 10-12 使用存储权限
    if (await Permission.storage.request().isGranted) {
      return true;
    }
    
    // 兼容旧版本：请求外部存储权限
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    
    return false;
  }
  
  /// 检查是否拥有存储权限（不弹窗）
  static Future<bool> hasStoragePermission() async {
    // 优先检查视频权限（Android 13+）
    if (await Permission.videos.isGranted) {
      return true;
    }
    // 检查存储权限（Android 10-12）
    if (await Permission.storage.isGranted) {
      return true;
    }
    return false;
  }
  
  /// 打开系统设置页面（当用户永久拒绝权限时使用）
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
