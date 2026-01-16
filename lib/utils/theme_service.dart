import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  // 监听器：主题名、字体缩放比例、是否加粗
  static final ValueNotifier<String> currentThemeName = ValueNotifier('classic');
  static final ValueNotifier<double> fontScale = ValueNotifier(1.0); // 默认1.0
  static final ValueNotifier<bool> isBold = ValueNotifier(false);    // 默认不加粗

  // --- ⚙️ 动态生成主题逻辑 ---

  static TextTheme _buildTextTheme(Color titleColor, Color bodyColor) {
    // 基础字号
    double baseBodySize = 16.0 * fontScale.value;
    double baseTitleSize = 17.0 * fontScale.value;
    double baseDateSize = 28.0 * fontScale.value;

    // 基础字重：如果开启加粗，则正文至少是 w600
    FontWeight bodyWeight = isBold.value ? FontWeight.w600 : FontWeight.w400;
    FontWeight titleWeight = isBold.value ? FontWeight.w800 : FontWeight.bold;

    return TextTheme(
      // 正文样式
      bodyMedium: TextStyle(
        color: bodyColor, 
        fontSize: baseBodySize, 
        height: 1.6, // 行高
        fontWeight: bodyWeight,
        fontFamily: 'MyFont',
      ),
      // 列表标题样式
      titleLarge: TextStyle(
        color: titleColor, 
        fontSize: baseTitleSize, 
        fontWeight: titleWeight,
        fontFamily: 'MyFont',
      ),
      // 大号日期样式 (复用 displayLarge)
      displayLarge: TextStyle(
        color: titleColor,
        fontSize: baseDateSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'MyFont',
      ),
    );
  }

  // ☀️ 经典模式
  static ThemeData get classic => ThemeData(
    useMaterial3: true,
    fontFamily: 'MyFont',
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF9F9F9),
    primaryColor: const Color(0xFF2C3E50),
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C3E50), brightness: Brightness.light),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF9F9F9), foregroundColor: Colors.black87),
    // 使用动态生成的文字主题
    textTheme: _buildTextTheme(Colors.black87, const Color(0xFF1A1A1A)),
  );

  // 🌙 黑夜模式
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    fontFamily: 'MyFont',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF90CAF9),
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C3E50), brightness: Brightness.dark),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212), foregroundColor: Colors.white),
    textTheme: _buildTextTheme(Colors.white, const Color(0xFFE0E0E0)),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white, selectionColor: Colors.blueGrey),
  );

  // 📜 羊皮纸模式
  static ThemeData get warm => ThemeData(
    useMaterial3: true,
    fontFamily: 'MyFont',
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2EAD3),
    primaryColor: const Color(0xFF5D4037),
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF795548), brightness: Brightness.light),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF2EAD3), foregroundColor: Color(0xFF3E2723)),
    textTheme: _buildTextTheme(const Color(0xFF3E2723), const Color(0xFF4E342E)),
  );

  // --- 🔄 逻辑方法 ---

  static ThemeData getThemeData() {
    switch (currentThemeName.value) {
      case 'dark': return dark;
      case 'warm': return warm;
      default: return classic;
    }
  }

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    currentThemeName.value = prefs.getString('theme_name') ?? 'classic';
    fontScale.value = prefs.getDouble('font_scale') ?? 1.0;
    isBold.value = prefs.getBool('is_bold') ?? false;
  }

  static Future<void> updateTheme(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_name', name);
    currentThemeName.value = name;
  }

  static Future<void> updateFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', scale);
    fontScale.value = scale;
  }

  static Future<void> updateBold(bool bold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_bold', bold);
    isBold.value = bold;
  }
}