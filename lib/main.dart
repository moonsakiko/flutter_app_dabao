import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 修复报错的关键
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

// ---------------------------------------------------------------------------
// 1. 数据模型 Data Models
// ---------------------------------------------------------------------------

class DiaryEntry {
  String id;
  String title; // 新增标题
  DateTime date;
  String content;

  DiaryEntry({
    required this.id,
    this.title = "",
    required this.date,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'content': content,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? "",
      date: DateTime.parse(json['date']),
      content: json['content'] ?? "",
    );
  }
}

class FutureLetter {
  String id;
  DateTime createDate;
  DateTime deliveryDate; // 送达日期
  String content;
  bool isRead;

  FutureLetter({
    required this.id,
    required this.createDate,
    required this.deliveryDate,
    required this.content,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createDate': createDate.toIso8601String(),
        'deliveryDate': deliveryDate.toIso8601String(),
        'content': content,
        'isRead': isRead,
      };

  factory FutureLetter.fromJson(Map<String, dynamic> json) {
    return FutureLetter(
      id: json['id'],
      createDate: DateTime.parse(json['createDate']),
      deliveryDate: DateTime.parse(json['deliveryDate']),
      content: json['content'],
      isRead: json['isRead'] ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 主程序入口 Main Entry
// ---------------------------------------------------------------------------

void main() {
  runApp(const DiaryApp());
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '时光日记',
      
      // ✨ 关键修复：配置本地化代理，解决 DatePicker 报错 ✨
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 支持中文
        Locale('en', 'US'),
      ],

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'MyFont', // 全局应用自定义字体
        scaffoldBackgroundColor: const Color(0xFFF9F9F9), // 纸张白
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50), // 深蓝灰主色调
          surface: const Color(0xFFF9F9F9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const DiaryHomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 首页 Home Page (时间轴 + 侧边栏)
// ---------------------------------------------------------------------------

class DiaryHomePage extends StatefulWidget {
  const DiaryHomePage({super.key});

  @override
  State<DiaryHomePage> createState() => _DiaryHomePageState();
}

class _DiaryHomePageState extends State<DiaryHomePage> {
  List<DiaryEntry> entries = [];
  List<FutureLetter> letters = [];
  String searchQuery = "";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- 数据存储逻辑 ---

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 加载日记
    final String? data = prefs.getString('diary_data');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      entries = jsonList.map((e) => DiaryEntry.fromJson(e)).toList();
      entries.sort((a, b) => b.date.compareTo(a.date)); // 倒序
    }

    // 2. 加载信件
    final String? letterData = prefs.getString('letter_data');
    if (letterData != null) {
      final List<dynamic> lList = jsonDecode(letterData);
      letters = lList.map((e) => FutureLetter.fromJson(e)).toList();
    }

    setState(() {});
    
    // 3. 检查有没有到期的信
    _checkIncomingLetters();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString('diary_data', data);
    
    final String lData = jsonEncode(letters.map((e) => e.toJson()).toList());
    await prefs.setString('letter_data', lData);
  }

  // --- 业务逻辑 ---

  void _checkIncomingLetters() {
    final now = DateTime.now();
    for (var letter in letters) {
      // 如果到了日期 且 没读过
      if (now.isAfter(letter.deliveryDate) && !letter.isRead) {
        // 延迟一点弹出，避免和 build 冲突
        Future.delayed(const Duration(seconds: 1), () {
          _showLetterDialog(letter);
        });
      }
    }
  }

  void _showLetterDialog(FutureLetter letter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("📬 来自过去的信"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("这封信写于 ${DateFormat('yyyy-MM-dd').format(letter.createDate)}"),
            const Divider(),
            const SizedBox(height: 10),
            Text(letter.content, style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                letter.isRead = true;
                _saveData();
              });
              Navigator.pop(context);
              // 可以跳转去写日记回复
              _goToEditPage(
                  initialContent: "收到了一封来自 ${DateFormat('yyyy年MM月dd日').format(letter.createDate)} 的信。\n\n那时我说：${letter.content}\n\n现在我想对自己说：");
            },
            child: const Text("收下并回复"),
          )
        ],
      ),
    );
  }

  // 导航到编辑页
  void _goToEditPage({DiaryEntry? existingEntry, String? initialContent}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorPage(
          entry: existingEntry,
          initialContent: initialContent,
          onSave: (entry) {
            setState(() {
              // 如果是修改旧的，先移除旧的
              entries.removeWhere((e) => e.id == entry.id);
              // 插入新的（根据日期排序）
              entries.add(entry);
              entries.sort((a, b) => b.date.compareTo(a.date));
            });
            _saveData();
          },
          onDelete: (id) {
            setState(() {
              entries.removeWhere((e) => e.id == id);
            });
            _saveData();
          },
        ),
      ),
    );
  }

  // 导出功能
  Future<void> _exportData() async {
    final String jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
    // 构造一个好看的 Markdown 预览
    StringBuffer buffer = StringBuffer();
    buffer.writeln("# 我的时光日记导出\n");
    for (var e in entries) {
      buffer.writeln("## ${DateFormat('yyyy-MM-dd').format(e.date)} ${e.title}");
      buffer.writeln(e.content);
      buffer.writeln("\n---\n");
    }
    // 附带 JSON 原数据以便导入（藏在最后）
    buffer.writeln("\n<!-- DATA_BACKUP_START");
    buffer.writeln(jsonString);
    buffer.writeln("DATA_BACKUP_END -->");

    await Share.share(buffer.toString(), subject: "时光日记备份_${DateFormat('yyyyMMdd').format(DateTime.now())}");
  }

  // 导入功能
  Future<void> _importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      try {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        // 尝试解析隐藏的 JSON
        final startTag = "<!-- DATA_BACKUP_START";
        final endTag = "DATA_BACKUP_END -->";
        if (content.contains(startTag)) {
          final jsonStr = content.split(startTag)[1].split(endTag)[0].trim();
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          setState(() {
            entries = jsonList.map((e) => DiaryEntry.fromJson(e)).toList();
            entries.sort((a, b) => b.date.compareTo(a.date));
          });
          _saveData();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 导入成功！")));
        } else {
          throw Exception("未找到备份数据标记");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ 导入失败: 文件格式不对")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 过滤搜索结果
    final displayEntries = searchQuery.isEmpty
        ? entries
        : entries.where((e) => e.content.contains(searchQuery) || e.title.contains(searchQuery)).toList();

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDrawer(), // 右侧侧边栏
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToEditPage(),
        backgroundColor: Colors.black87,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          // 顶部背景
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            // backgroundColor: Colors.white,
            backgroundColor: const Color(0xFFF9F9F9),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                DateFormat('MM月 dd日').format(DateTime.now()),
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w300),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/header.jpg', // 你的背景图
                    fit: BoxFit.cover,
                  ),
                  // 渐变蒙层，让字看得清
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white.withOpacity(0.8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),

          // 列表内容
          SliverPadding(
            padding: const EdgeInsets.only(top: 20, bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return GestureDetector(
                    onTap: () => _goToEditPage(existingEntry: displayEntries[index]),
                    child: TimelineItem(entry: displayEntries[index]),
                  );
                },
                childCount: displayEntries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 侧边栏 (折叠功能区) ---
  Widget _buildDrawer() {
    // 统计数据
    int totalDays = entries.map((e) => DateFormat('yyyyMMdd').format(e.date)).toSet().length;
    int totalWords = entries.fold(0, (sum, item) => sum + item.content.length);

    return Drawer(
      width: 300,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("功能拓展", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            
            // 1. 搜索
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "搜索记忆...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  setState(() {
                    searchQuery = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // 2. 统计卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [Text("$totalDays", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text("记录天数", style: TextStyle(fontSize: 12))]),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  Column(children: [Text("$totalWords", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text("累计字数", style: TextStyle(fontSize: 12))]),
                ],
              ),
            ),

            const Divider(height: 40),

            // 3. 写信给未来
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text("写信给未来"),
              onTap: () {
                Navigator.pop(context); // 关侧边栏
                Navigator.push(context, MaterialPageRoute(builder: (c) => FutureLetterPage(
                  letters: letters, 
                  onUpdate: (newLetters) {
                    letters = newLetters;
                    _saveData();
                  }
                )));
              },
            ),
            
            // 4. 导入导出
            ListTile(
              leading: const Icon(Icons.output),
              title: const Text("备份与导出 (Markdown)"),
              onTap: _exportData,
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text("恢复日记"),
              onTap: _importData,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. 沉浸式编辑/阅读页 Editor Page
// ---------------------------------------------------------------------------

class EditorPage extends StatefulWidget {
  final DiaryEntry? entry;
  final Function(DiaryEntry) onSave;
  final Function(String) onDelete;
  final String? initialContent;

  const EditorPage({super.key, this.entry, required this.onSave, required this.onDelete, this.initialContent});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late DateTime _selectedDate;
  bool _isEditing = false; // 是否处于编辑模式（如果是新建则默认true，查看则默认false）

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry?.date ?? DateTime.now();
    _titleController = TextEditingController(text: widget.entry?.title ?? "");
    _contentController = TextEditingController(text: widget.initialContent ?? widget.entry?.content ?? "");
    
    // 如果没有传入 entry，说明是新建，直接进入编辑模式
    _isEditing = widget.entry == null;
  }

  Future<void> _pickDate() async {
    // 修复了 MaterialLocalizations 后，这里就能正常工作了
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'), // 强制中文
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
             colorScheme: const ColorScheme.light(primary: Colors.black87), // 日历颜色
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleSave() {
    if (_contentController.text.trim().isEmpty) return;

    final newEntry = DiaryEntry(
      id: widget.entry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      date: _selectedDate,
      content: _contentController.text,
    );
    widget.onSave(newEntry);
    Navigator.pop(context);
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("确认删除？"),
        content: const Text("这段记忆将无法找回。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(onPressed: () {
            widget.onDelete(widget.entry!.id);
            Navigator.pop(ctx); // 关弹窗
            Navigator.pop(context); // 关页面
          }, child: const Text("删除", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 沉浸式体验：全白背景，大留白
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 日期选择
          TextButton.icon(
            onPressed: _isEditing ? _pickDate : null, // 只有编辑时能点
            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
            label: Text(
              DateFormat('yyyy.MM.dd').format(_selectedDate),
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          
          if (_isEditing)
             IconButton(icon: const Icon(Icons.check), onPressed: _handleSave)
          else ...[
             IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true)),
             IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _handleDelete),
          ],
          const SizedBox(width: 10),
        ],
      ),
      body: GestureDetector(
        onTap: () {
           // 点击空白处不收起键盘，保持沉浸
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // 标题输入框 (可选)
                TextField(
                  controller: _titleController,
                  enabled: _isEditing,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "标题 (可选)",
                    hintStyle: TextStyle(color: Colors.black12),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 20),
                // 正文输入框
                TextField(
                  controller: _contentController,
                  enabled: _isEditing,
                  maxLines: null, // 无限高度
                  style: const TextStyle(
                    fontSize: 17, 
                    height: 1.8, // 行距大一点，读起来舒服
                    color: Colors.black87
                  ),
                  decoration: const InputDecoration(
                    hintText: "在此刻，记录当下...",
                    hintStyle: TextStyle(color: Colors.black12),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 300), // 底部超大留白，防止键盘遮挡
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. 写信给未来页面
// ---------------------------------------------------------------------------

class FutureLetterPage extends StatefulWidget {
  final List<FutureLetter> letters;
  final Function(List<FutureLetter>) onUpdate;

  const FutureLetterPage({super.key, required this.letters, required this.onUpdate});

  @override
  State<FutureLetterPage> createState() => _FutureLetterPageState();
}

class _FutureLetterPageState extends State<FutureLetterPage> {
  void _writeLetter() {
    TextEditingController contentCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30)); // 默认一个月后

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("写给未来", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("送达日期："),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context, 
                          initialDate: selectedDate, 
                          firstDate: DateTime.now(), 
                          lastDate: DateTime(2100),
                          locale: const Locale('zh', 'CN')
                        );
                        if (d != null) setSheetState(() => selectedDate = d);
                      },
                      child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    )
                  ],
                ),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: "你想对那时的自己说什么？", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (contentCtrl.text.isNotEmpty) {
                        final newLetter = FutureLetter(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          createDate: DateTime.now(),
                          deliveryDate: selectedDate,
                          content: contentCtrl.text,
                        );
                        widget.letters.add(newLetter);
                        widget.onUpdate(widget.letters);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                    child: const Text("寄出"),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("时间胶囊")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _writeLetter,
        label: const Text("新建信件", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.send, color: Colors.white),
        backgroundColor: Colors.black87,
      ),
      body: widget.letters.isEmpty 
        ? const Center(child: Text("还没有寄往未来的信", style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            itemCount: widget.letters.length,
            itemBuilder: (context, index) {
              final letter = widget.letters[index];
              final isArrived = DateTime.now().isAfter(letter.deliveryDate);
              return ListTile(
                leading: Icon(isArrived ? Icons.mark_email_read : Icons.hourglass_bottom, color: isArrived ? Colors.black87 : Colors.grey),
                title: Text("寄往 ${DateFormat('yyyy-MM-dd').format(letter.deliveryDate)}"),
                subtitle: Text(isArrived ? "已送达" : "运输中...", style: TextStyle(color: isArrived ? Colors.green : Colors.grey)),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: (){
                   setState(() {
                     widget.letters.removeAt(index);
                     widget.onUpdate(widget.letters);
                   });
                }),
                onTap: isArrived ? () {
                  // 查看信件逻辑
                  showDialog(context: context, builder: (c) => AlertDialog(content: Text(letter.content)));
                } : null,
              );
            },
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. UI组件 Components
// ---------------------------------------------------------------------------

class TimelineItem extends StatelessWidget {
  final DiaryEntry entry;
  const TimelineItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧日期
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 10),
                Text(DateFormat('yyyy.MM').format(entry.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(DateFormat('dd').format(entry.date), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          // 中间线条
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(width: 1, height: double.infinity, color: Colors.grey.withOpacity(0.3), margin: const EdgeInsets.only(top: 15)),
                Container(
                  margin: const EdgeInsets.only(top: 22),
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black54, width: 1.5), shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          // 右侧内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 40, right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // 如果有标题显示标题，否则显示日期
                  if (entry.title.isNotEmpty)
                    Text(entry.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))
                  else
                    Text(DateFormat('yyyy年MM月dd日').format(entry.date), style: const TextStyle(fontSize: 16, color: Colors.black87)),
                  
                  const SizedBox(height: 4),
                  Text(DateFormat('HH:mm').format(entry.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Text(
                    entry.content,
                    maxLines: 4, // 列表页只显示4行
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.6),
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