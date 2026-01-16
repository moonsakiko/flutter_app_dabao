import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_page.dart';
import 'utils/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.loadSettings(); // 读取所有设置
  runApp(const DiaryApp());
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listenable.merge 可以把多个监听器合并成一个，任何一个变了都会刷新
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.currentThemeName, 
        ThemeService.fontScale, 
        ThemeService.isBold
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '时光日记',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN')],
          
          // 每次变化时，ThemeService.getThemeData() 都会重新计算字体大小
          theme: ThemeService.getThemeData(), 
          home: const DiaryHomePage(),
        );
      }
    );
  }
}