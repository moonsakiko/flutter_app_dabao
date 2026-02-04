import 'package:flutter/material.dart';

/// 处理进度遮罩组件
/// 在视频处理时显示全屏遮罩和进度
class ProgressOverlay extends StatelessWidget {
  final double progress;
  final String message;

  const ProgressOverlay({
    super.key,
    required this.progress,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度圆环
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 背景圆
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        color: colorScheme.surfaceVariant,
                      ),
                      // 进度圆
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                      ),
                      // 百分比文字
                      Center(
                        child: Text(
                          "${(progress * 100).toInt()}%",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 消息文字
                Text(
                  message,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 提示文字
                Text(
                  "请勿离开此页面",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
