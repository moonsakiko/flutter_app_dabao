import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
    // Android 13+ use photos/videos permission, older use storage
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
        // 2. Download Byte Stream (Memory)
        // ImageGallerySaver can save from Uint8List directly, which is better than temp file often
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            },
          ),
        );

        // 3. Save to Gallery
        final result = await ImageGallerySaver.saveImage(
            Uint8List.fromList(response.data),
            quality: 100,
            name: "xhs_${DateTime.now().millisecondsSinceEpoch}"
        );
        
        // Result is Map usually {'isSuccess': true}
        if (result['isSuccess'] == true) {
           success++;
        } else {
           print("Save Failed: $result");
           fail++;
        }

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
