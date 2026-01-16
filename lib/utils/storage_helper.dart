import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_model.dart';

class StorageHelper {
  static Future<List<DiaryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('diary_data');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      List<DiaryEntry> list = jsonList.map((e) => DiaryEntry.fromJson(e)).toList();
      // 倒序排列：最新的在上面
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }
    return [];
  }

  static Future<void> saveEntries(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString('diary_data', data);
  }

  static Future<List<FutureLetter>> loadLetters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('letter_data');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => FutureLetter.fromJson(e)).toList();
    }
    return [];
  }

  static Future<void> saveLetters(List<FutureLetter> letters) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(letters.map((e) => e.toJson()).toList());
    await prefs.setString('letter_data', data);
  }
}