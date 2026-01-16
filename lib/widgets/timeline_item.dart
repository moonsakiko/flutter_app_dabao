import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_model.dart';

class TimelineItem extends StatelessWidget {
  final DiaryEntry entry;
  const TimelineItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 获取动态生成的主题样式
    final TextStyle? bodyStyle = theme.textTheme.bodyMedium;
    final TextStyle? titleStyle = theme.textTheme.titleLarge;
    final TextStyle? dateStyle = theme.textTheme.displayLarge; // 大号日期

    final Color mainTextColor = titleStyle?.color ?? Colors.black87;
    final Color dateColor = isDark ? Colors.white70 : const Color(0xFF444444);
    final Color lineColor = isDark ? Colors.white24 : Colors.black12;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：日期
          SizedBox(
            width: 85, // 稍微加宽一点，防止大字体换行
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 10),
                Text(
                  DateFormat('yyyy.MM').format(entry.date), 
                  style: TextStyle(fontSize: 13, color: dateColor, fontWeight: FontWeight.w600)
                ),
                Text(
                  DateFormat('dd').format(entry.date), 
                  // 使用 displayLarge (在 ThemeService 里定义的动态大小)
                  style: dateStyle?.copyWith(color: mainTextColor) 
                ),
              ],
            ),
          ),
          
          // 中间：线
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(width: 1, height: double.infinity, color: lineColor, margin: const EdgeInsets.only(top: 15)),
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor, 
                    border: Border.all(color: mainTextColor, width: 2), 
                    shape: BoxShape.circle
                  ),
                ),
              ],
            ),
          ),
          
          // 右侧：内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 40, right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.title.isNotEmpty)
                    Text(entry.title, style: titleStyle)
                  else
                    // 没标题时，显示日期作为标题，复用 titleStyle
                    Text(DateFormat('yyyy年MM月dd日').format(entry.date), style: titleStyle?.copyWith(fontSize: (titleStyle.fontSize ?? 17) - 1)),
                  
                  const SizedBox(height: 4),
                  Text(DateFormat('HH:mm').format(entry.date), style: TextStyle(fontSize: 12, color: dateColor)),
                  
                  const SizedBox(height: 10),
                  // 正文：完全使用动态样式
                  Text(
                    entry.content,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle, 
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}