class XHSNote {
  final String title;
  final String noteId;
  final List<MediaItem> resources;
  final List<String> tags;

  XHSNote({
    required this.title,
    required this.noteId,
    required this.resources,
    required this.tags,
  });

  // Factory to parse the raw JSON from window.__INITIAL_STATE__
  static XHSNote? fromJson(Map<String, dynamic> rawState) {
    try {
      final noteMap = rawState['note']['noteDetailMap'] ?? {};
      if (noteMap.isEmpty) return null;

      // Extract the first key (noteId)
      final String id = noteMap.keys.first;
      final info = noteMap[id];
      if (info == null) return null;

      final title = info['title'] ?? info['desc'] ?? 'Untitled';
      final List<String> tags = (info['tagList'] as List? ?? [])
          .map((e) => e['name']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .cast<String>()
          .toList();

      List<MediaItem> resources = [];

      // 1. Process Images
      final imageList = (info['imageList'] as List? ?? []);
      for (var img in imageList) {
        String? traceId = img['traceId'];
        if (traceId != null) {
          resources.add(MediaItem(
            url: "https://ci.xiaohongshu.com/$traceId?imageView2/2/w/format/jpg",
            type: MediaType.image,
            traceId: traceId,
          ));
        }
      }

      // 2. Process Video (V3.6 Logic Port)
      final video = info['video'];
      if (video != null) {
        String? videoUrl;
        
        // A. Origin Key
        if (video['consumer']?['originVideoKey'] != null) {
          videoUrl = "https://sns-video-bd.xhscdn.com/${video['consumer']['originVideoKey']}";
        }
        
        // B. Stream Selection (Simulated V3.6 logic)
        if (videoUrl == null && video['media']?['stream'] != null) {
             final stream = video['media']['stream'];
             // Simple version: grab h265 master or h264 master
             // In Dart, we might just grab the first available masterUrl for simplicity initially
             // or implement full sorting later.
             var candidates = [];
             if (stream['h265'] != null) candidates.addAll(stream['h265']);
             if (stream['h264'] != null) candidates.addAll(stream['h264']);
             
             if (candidates.isNotEmpty) {
               // Sort by size desc
               candidates.sort((a, b) => (b['size'] ?? 0) - (a['size'] ?? 0));
               videoUrl = candidates.first['masterUrl'];
             }
        }

        if (videoUrl != null) {
          // Clean URL
          if (!videoUrl.contains('ci.xiaohongshu.com')) {
             videoUrl = videoUrl.replaceAll(RegExp(r'sns-video-\w+\.xhscdn\.com'), 'sns-video-bd.xhscdn.com');
          }
          resources.add(MediaItem(
            url: videoUrl,
            type: MediaType.video,
            traceId: id + "_video",
          ));
        }
      }

      return XHSNote(
        title: title,
        noteId: id,
        resources: resources,
        tags: tags,
      );
    } catch (e) {
      print("Parse Error: $e");
      return null;
    }
  }
}

enum MediaType { image, video }

class MediaItem {
  final String url;
  final MediaType type;
  final String traceId;

  MediaItem({required this.url, required this.type, required this.traceId});
}
