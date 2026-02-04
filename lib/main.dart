import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'utils/config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VideoCutterApp());
}

class VideoCutterApp extends StatelessWidget {
  const VideoCutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 关闭调试角标
      debugShowCheckedModeBanner: false,
      
      // APP 标题（显示在任务列表中）
      title: APP_NAME,
      
      // 主题配置 - Material Design 3
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(PRIMARY_COLOR_VALUE),
          brightness: Brightness.light,
        ),
        // 卡片样式
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        // 按钮样式
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      
      // 深色主题
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(PRIMARY_COLOR_VALUE),
          brightness: Brightness.dark,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      
      // 跟随系统深色模式
      themeMode: ThemeMode.system,
      
      // 首页
      home: const HomePage(),
    );
  }
}
