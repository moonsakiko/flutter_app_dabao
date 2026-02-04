import 'package:flutter/material.dart';
import '../utils/ffmpeg_service.dart';
import '../utils/file_helper.dart';

/// 视频列表项组件
/// 用于拼接页面展示视频信息，支持删除操作
class VideoListItem extends StatelessWidget {
  final VideoInfo video;
  final int index;
  final VoidCallback onRemove;

  const VideoListItem({
    super.key,
    required this.video,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        // 拖拽手柄
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 序号
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "$index",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 拖拽图标
            Icon(
              Icons.drag_handle,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        // 视频信息
        title: Text(
          FileHelper.getFileName(video.path),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              video.formattedDuration,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.aspect_ratio,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              video.resolution,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // 删除按钮
        trailing: IconButton(
          onPressed: onRemove,
          icon: Icon(
            Icons.close,
            color: colorScheme.error,
          ),
          tooltip: "移除",
        ),
      ),
    );
  }
}
