import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  static final Dio _dio = Dio();

  /// Batch download media to Gallery
  static Future<Map<String, int>> downloadAll(
      List<String> urls, {
      Function(int, int)? onProgress,
      }) async {

    // 1. Request Permission
    // Gal handles permissions automatically usually, but good to check
    bool access = await Gal.hasAccess();
    if (!access) {
      access = await Gal.requestAccess();
      if (!access) throw Exception("暂无相册权限");
    }

    int success = 0;
    int fail = 0;

    // Use temporary directory
    final tempDir = await getTemporaryDirectory();

    for (int i = 0; i < urls.length; i++) {
      String url = urls[i];
      try {
        final isVideo = url.contains('.mp4') || url.contains('sns-video');
        final ext = isVideo ? 'mp4' : 'jpg';
        final savePath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.$ext';

        // 2. Download with Headers (No Referer!)
        await _dio.download(
          url,
          savePath,
          options: Options(
            headers: {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
              // CRITICAL: No Referer/Cookie
            },
          ),
        );

        // 3. Save to Gallery
        if (isVideo) {
          await Gal.putVideo(savePath, album: "RedBookDownload");
        } else {
          await Gal.putImage(savePath, album: "RedBookDownload");
        }
        
        // Cleanup temp file
        File(savePath).delete().ignore();

        success++;
      } catch (e) {
        print("Download Failed [$url]: $e");
        fail++;
      }

      if (onProgress != null) {
        onProgress(i + 1, urls.length);
      }
    }

    return {"success": success, "fail": fail};
  }
}
