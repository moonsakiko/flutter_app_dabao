import 'package:flutter/material.dart';

/// 时间范围选择器组件
/// 双滑块选择视频切割的起止时间
class TimeRangeSelector extends StatelessWidget {
  final int totalDurationMs;
  final int startMs;
  final int endMs;
  final Function(int start, int end) onChanged;

  const TimeRangeSelector({
    super.key,
    required this.totalDurationMs,
    required this.startMs,
    required this.endMs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // 时间显示
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 开始时间
            _TimeDisplay(
              label: "开始",
              timeMs: startMs,
              color: colorScheme.primary,
            ),
            // 持续时长
            Column(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(endMs - startMs),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  "时长",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // 结束时间
            _TimeDisplay(
              label: "结束",
              timeMs: endMs,
              color: colorScheme.secondary,
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // 双滑块
        RangeSlider(
          values: RangeValues(
            startMs.toDouble(),
            endMs.toDouble(),
          ),
          min: 0,
          max: totalDurationMs.toDouble(),
          divisions: totalDurationMs > 1000 ? (totalDurationMs ~/ 100) : null,
          labels: RangeLabels(
            _formatTime(startMs),
            _formatTime(endMs),
          ),
          onChanged: (RangeValues values) {
            int newStart = values.start.round();
            int newEnd = values.end.round();
            
            // 确保最小时长为 1 秒
            if (newEnd - newStart < 1000) {
              if (newStart == startMs) {
                newEnd = newStart + 1000;
              } else {
                newStart = newEnd - 1000;
              }
            }
            
            // 限制范围
            newStart = newStart.clamp(0, totalDurationMs - 1000);
            newEnd = newEnd.clamp(1000, totalDurationMs);
            
            onChanged(newStart, newEnd);
          },
        ),
        
        // 时间轴刻度
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "00:00",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _formatTime(totalDurationMs ~/ 2),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _formatTime(totalDurationMs),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _formatTime(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
  
  String _formatDuration(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    } else if (minutes > 0) {
      return "${minutes}m ${seconds}s";
    } else {
      return "${seconds}s";
    }
  }
}

/// 时间显示组件
class _TimeDisplay extends StatelessWidget {
  final String label;
  final int timeMs;
  final Color color;

  const _TimeDisplay({
    required this.label,
    required this.timeMs,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(timeMs),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}
