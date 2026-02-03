import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  static final Dio _dio = Dio();

  /// 判断URL是否为视频
  static bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('video') || 
           lower.contains('.mp4') || 
           lower.contains('.mov') ||
           lower.contains('stream/') ||
           lower.contains('xhscdn.com/stream');
  }

  /// Batch download media to Gallery
  static Future<Map<String, int>> downloadAll(
      List<String> urls, {
      Function(int, int)? onProgress,
      }) async {

    // 1. Request Permission
    if (Platform.isAndroid) {
       await Permission.storage.request();
       await Permission.photos.request();
       await Permission.videos.request();
    }
    
    int success = 0;
    int fail = 0;

    for (int i = 0; i < urls.length; i++) {
      String url = urls[i];
      try {
        final bool isVideo = _isVideoUrl(url);
        
        // 2. Download Byte Stream
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
              "Referer": "https://www.xiaohongshu.com/",
              "Accept": "*/*",
            },
          ),
        );

        final bytes = Uint8List.fromList(response.data);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        
        dynamic result;
        
        if (isVideo) {
          // 3a. Save Video: 需要先保存到临时文件，再用 saveFile
          final tempDir = await getTemporaryDirectory();
          final tempPath = "${tempDir.path}/xhs_video_$timestamp.mp4";
          final file = File(tempPath);
          await file.writeAsBytes(bytes);
          
          result = await ImageGallerySaver.saveFile(
            tempPath,
            name: "xhs_video_$timestamp",
            isReturnPathOfIOS: true,
          );
          
          // 清理临时文件
          try { await file.delete(); } catch (_) {}
        } else {
          // 3b. Save Image
          result = await ImageGallerySaver.saveImage(
            bytes,
            quality: 100,
            name: "xhs_$timestamp",
          );
        }
        
        if (result != null && (result['isSuccess'] == true || result is String)) {
           success++;
           print("✅ Saved: ${isVideo ? 'VIDEO' : 'IMAGE'} (${bytes.length} bytes)");
        } else {
           print("❌ Save Failed: $result");
           fail++;
        }

      } catch (e) {
        print("❌ Download Failed [$url]: $e");
        fail++;
      }

      if (onProgress != null) {
        onProgress(i + 1, urls.length);
      }
    }

    return {"success": success, "fail": fail};
  }
}
