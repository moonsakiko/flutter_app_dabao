import 'package:flutter/material.dart';
import '../utils/ffmpeg_service.dart';
import '../utils/file_helper.dart';

/// 视频选择卡片组件
/// 用于选择视频文件并展示视频信息
class VideoPickerCard extends StatelessWidget {
  final VideoInfo? videoInfo;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const VideoPickerCard({
    super.key,
    this.videoInfo,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 未选择视频时显示空状态
    if (videoInfo == null) {
      return _buildEmptyState(context);
    }

    // 已选择视频时显示信息卡片
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 视频预览区域（带图标）
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Stack(
              children: [
                // 中央图标
                Center(
                  child: Icon(
                    Icons.movie_outlined,
                    size: 64,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.5),
                  ),
                ),
                // 右上角清除按钮
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                    tooltip: "移除视频",
                  ),
                ),
              ],
            ),
          ),
          
          // 视频信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件名
                Text(
                  FileHelper.getFileName(videoInfo!.path),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                
                // 详细信息网格
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.schedule,
                      label: videoInfo!.formattedDuration,
                    ),
                    _InfoChip(
                      icon: Icons.aspect_ratio,
                      label: videoInfo!.resolution,
                    ),
                    _InfoChip(
                      icon: Icons.code,
                      label: videoInfo!.codec.toUpperCase(),
                    ),
                    _InfoChip(
                      icon: Icons.storage,
                      label: FileHelper.formatFileSize(videoInfo!.fileSize),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPick,
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 36,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "点击选择视频",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "支持 MP4、MOV、AVI 等常见格式",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 信息标签组件
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
