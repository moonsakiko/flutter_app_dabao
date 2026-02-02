import 'package:flutter/material.dart';
import 'package:xhs_downloader_app/pages/browser_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 这里的 title 仅用于多任务列表，安装名由 build.yml 控制
      title: '小红书下载器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF2442), // 小红书红
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFFFF2442),
          foregroundColor: Colors.white,
        ),
      ),
      home: const BrowserPage(),
    );
  }
}
