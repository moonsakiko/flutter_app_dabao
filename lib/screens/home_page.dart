import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../models/diary_model.dart';
import '../utils/storage_helper.dart';
import '../utils/theme_service.dart';
import '../widgets/timeline_item.dart';
import 'editor_page.dart';
import 'letter_box_page.dart';
import 'search_page.dart';

class DiaryHomePage extends StatefulWidget {
  const DiaryHomePage({super.key});
  @override
  State<DiaryHomePage> createState() => _DiaryHomePageState();
}

class _DiaryHomePageState extends State<DiaryHomePage> {
  // ... (保留之前的变量和 initState 逻辑不变) ...
  List<DiaryEntry> entries = [];
  List<FutureLetter> letters = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }
  
  // ... (保留 _refreshData, _checkIncomingLetters, _goToEditPage, 导入导出逻辑不变) ...
  // 为节省篇幅，这里省略了中间未修改的逻辑代码，请直接复制之前的逻辑方法
  Future<void> _refreshData() async {
    final e = await StorageHelper.loadEntries();
    final l = await StorageHelper.loadLetters();
    setState(() { entries = e; letters = l; });
    _checkIncomingLetters();
  }
  void _checkIncomingLetters() {
    final now = DateTime.now();
    for (var letter in letters) {
      if (now.isAfter(letter.deliveryDate) && !letter.isRead) {
        Future.delayed(const Duration(seconds: 1), () => _showLetterDialog(letter));
      }
    }
  }
  void _showLetterDialog(FutureLetter letter) {
    showDialog(context: context, builder: (c) => AlertDialog(content: Text(letter.content), actions: [TextButton(onPressed: (){setState(()=>letter.isRead=true);StorageHelper.saveLetters(letters);Navigator.pop(c);_goToEditPage(initialContent: "收到信:\n${letter.content}\n回复:");}, child: const Text("回复"))]));
  }
  void _goToEditPage({DiaryEntry? existingEntry, String? initialContent}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (c) => EditorPage(entry: existingEntry, initialContent: initialContent, onSave: (e) async { entries.removeWhere((x)=>x.id==e.id); entries.add(e); entries.sort((a,b)=>b.date.compareTo(a.date)); await StorageHelper.saveEntries(entries); _refreshData(); }, onDelete: (id) async { entries.removeWhere((x)=>x.id==id); await StorageHelper.saveEntries(entries); _refreshData(); })));
  }
  Future<void> _exportData() async {
     // ... (代码同前) ...
     StringBuffer buffer = StringBuffer();
     buffer.writeln("# 时光日记备份\n");
     for (var e in entries) {
       buffer.writeln("## ${DateFormat('yyyy-MM-dd').format(e.date)} ${e.title}");
       buffer.writeln(e.content);
       buffer.writeln("\n---\n");
     }
     final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
     buffer.writeln("\n<!-- DATA_BACKUP_START");
     buffer.writeln(jsonString);
     buffer.writeln("DATA_BACKUP_END -->");
     await Share.share(buffer.toString(), subject: "时光日记备份");
  }
  Future<void> _importData() async {
     // ... (代码同前) ...
     FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      try {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        if (content.contains("DATA_BACKUP_START")) {
          final jsonStr = content.split("DATA_BACKUP_START")[1].split("DATA_BACKUP_END")[0].trim();
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          List<DiaryEntry> newEntries = jsonList.map((e) => DiaryEntry.fromJson(e)).toList();
          await StorageHelper.saveEntries(newEntries);
          _refreshData();
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 导入成功")));
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ 导入失败，格式错误")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (保留 build 方法，和之前完全一样) ...
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerTextColor = isDark ? Colors.white : Colors.black87;
    final headerIconColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      endDrawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToEditPage(),
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.search, color: headerIconColor),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => SearchPage(allEntries: entries, onEntryTap: (e) {
                  _goToEditPage(existingEntry: e);
                })));
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                DateFormat('MM月 dd日').format(DateTime.now()),
                style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w300),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/header.jpg', fit: BoxFit.cover),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, theme.scaffoldBackgroundColor.withOpacity(0.95)]))),
                ],
              ),
            ),
            actions: [
              IconButton(icon: Icon(Icons.menu, color: headerIconColor), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 20, bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => GestureDetector(
                  onTap: () => _goToEditPage(existingEntry: entries[index]),
                  child: TimelineItem(entry: entries[index]),
                ),
                childCount: entries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 👇👇👇 重点修改这里：侧边栏 UI 👇👇👇
  Widget _buildDrawer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      width: 300,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20), 
              child: Text("设置与拓展", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color))
            ),
            
            const Divider(),
            
            // 1. 皮肤选择
            const Padding(padding: EdgeInsets.only(left:20, top:10), child: Align(alignment: Alignment.centerLeft, child: Text("🎨 主题风格", style: TextStyle(color: Colors.grey, fontSize: 12)))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSkinBtn("经典", const Color(0xFFF9F9F9), "classic"),
                  _buildSkinBtn("羊皮", const Color(0xFFF2EAD3), "warm"),
                  _buildSkinBtn("黑夜", const Color(0xFF222222), "dark", isDarkBtn: true),
                ],
              ),
            ),

            const Divider(),

            // 2. 字体显示设置 (新增)
            const Padding(padding: EdgeInsets.only(left:20, top:10), child: Align(alignment: Alignment.centerLeft, child: Text("Aa 显示设置", style: TextStyle(color: Colors.grey, fontSize: 12)))),
            
            // 加粗开关
            SwitchListTile(
              title: const Text("字体加粗", style: TextStyle(fontSize: 16)),
              subtitle: const Text("让文字更清晰有力", style: TextStyle(fontSize: 12, color: Colors.grey)),
              value: ThemeService.isBold.value,
              activeColor: theme.primaryColor,
              onChanged: (val) {
                setState(() {}); // 刷新当前抽屉UI
                ThemeService.updateBold(val);
              },
            ),
            
            // 字号滑块
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("字体大小"),
                      Text((ThemeService.fontScale.value * 100).toInt().toString() + "%", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  Slider(
                    value: ThemeService.fontScale.value,
                    min: 0.8, // 最小 80%
                    max: 1.3, // 最大 130%
                    divisions: 5, // 5档调节
                    activeColor: theme.primaryColor,
                    onChanged: (val) {
                      setState(() {}); 
                      ThemeService.updateFontScale(val);
                    },
                  ),
                ],
              ),
            ),

            const Divider(),
            
            // 3. 其他功能
            ListTile(leading: const Icon(Icons.mail_outline), title: const Text("写信给未来"), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => LetterBoxPage(onSave: (l) async { letters = l; await StorageHelper.saveLetters(letters); }))); }),
            ListTile(leading: const Icon(Icons.output), title: const Text("备份数据"), onTap: _exportData),
            ListTile(leading: const Icon(Icons.file_download_outlined), title: const Text("恢复日记"), onTap: _importData),
          ],
        ),
      ),
    );
  }

  Widget _buildSkinBtn(String name, Color color, String themeKey, {bool isDarkBtn = false}) {
    return GestureDetector(
      onTap: () => ThemeService.updateTheme(themeKey),
      child: Column(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black.withOpacity(0.1))]
            ),
            child: isDarkBtn ? const Icon(Icons.nightlight_round, size: 18, color: Colors.white) : null,
          ),
          const SizedBox(height: 5),
          Text(name, style: const TextStyle(fontSize: 12))
        ],
      ),
    );
  }
}