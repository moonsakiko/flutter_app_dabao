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
    
    final TextStyle? bodyStyle = theme.textTheme.bodyMedium;
    final TextStyle? titleStyle = theme.textTheme.titleLarge;
    final TextStyle? dateStyle = theme.textTheme.displayLarge;

    final Color mainTextColor = titleStyle?.color ?? Colors.black87;
    final Color dateColor = isDark ? Colors.white70 : const Color(0xFF444444);
    final Color lineColor = isDark ? Colors.white24 : Colors.black12;

    // 左侧日期区域的宽度固定，方便定位竖线
    const double dateColumnWidth = 85.0;
    // 竖线区域宽度
    const double lineSectionWidth = 40.0;
    // 竖线位于中间
    const double linePosition = dateColumnWidth + (lineSectionWidth / 2);

    return Stack(
      children: [
        // -------------------------------------------------------
        // 1. 底层：竖线 (使用绝对定位，不再计算高度，直接撑满)
        // -------------------------------------------------------
        Positioned(
          left: linePosition, 
          top: 24, // 从圆圈中心开始往下画
          bottom: 0, // 一直画到底
          width: 1,  // 线宽
          child: Container(color: lineColor),
        ),

        // -------------------------------------------------------
        // 2. 上层：内容 (日期 + 圆点 + 文字)
        // -------------------------------------------------------
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [左侧] 日期
            SizedBox(
              width: dateColumnWidth,
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
                    style: dateStyle?.copyWith(color: mainTextColor) 
                  ),
                ],
              ),
            ),
            
            // [中间] 圆点 (占据固定空间，但不画线了)
            SizedBox(
              width: lineSectionWidth,
              child: Column(
                children: [
                  const SizedBox(height: 24), // 对齐圆点位置
                  Container(
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
            
            // [右侧] 文本内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 40, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.title.isNotEmpty)
                      Text(entry.title, style: titleStyle)
                    else
                      Text(DateFormat('yyyy年MM月dd日').format(entry.date), style: titleStyle?.copyWith(fontSize: (titleStyle.fontSize ?? 17) - 1)),
                    
                    const SizedBox(height: 4),
                    Text(DateFormat('HH:mm').format(entry.date), style: TextStyle(fontSize: 12, color: dateColor)),
                    
                    const SizedBox(height: 10),
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
      ],
    );
  }
}