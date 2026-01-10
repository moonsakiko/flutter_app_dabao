import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOFTER 去水印',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 核心通道：与 Kotlin 通信
  static const platform = MethodChannel('com.example.lofter_fixer/processor');

  // 状态变量
  double _confidence = 0.5;
  String? _wmPath;
  String? _noWmPath;
  bool _isProcessing = false;
  String _log = "准备就绪\n请确保模型已放入 android/assets 目录";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.storage, Permission.photos].request();
  }

  // --- 单张处理逻辑 ---
  Future<void> _pickImage(bool isWm) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isWm) _wmPath = image.path;
        else _noWmPath = image.path;
      });
    }
  }

  Future<void> _processSingle() async {
    if (_wmPath == null || _noWmPath == null) {
      Fluttertoast.showToast(msg: "请先选择两张图片");
      return;
    }
    _runNativeRepair([{'wm': _wmPath!, 'clean': _noWmPath!}]);
  }

  // --- 批量处理逻辑 ---
  Future<void> _pickFilesBatch() async {
    // 允许用户多选文件
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );

    if (result != null) {
      List<String> files = result.paths.whereType<String>().toList();
      _matchAndProcess(files);
    }
  }

  void _matchAndProcess(List<String> files) {
    // 简单的匹配逻辑：找 xxx-wm.jpg 和 xxx-orig.jpg (或用户自定义的后缀)
    // 这里为了适配你的脚本习惯，假设成对出现
    
    List<Map<String, String>> tasks = [];
    List<String> wmFiles = files.where((f) => f.toLowerCase().contains("-wm.")).toList();
    
    for (var wm in wmFiles) {
      // 尝试寻找对应的无水印图 (-orig)
      // 逻辑：把 -wm 替换成 -orig 看看在不在列表里
      String expectedOrig = wm.replaceAll(RegExp(r'-wm\.', caseSensitive: false), '-orig.');
      
      // 简单的文件名匹配查找
      String? foundOrig;
      try {
        foundOrig = files.firstWhere((f) => f == expectedOrig);
      } catch (e) {
        // 尝试模糊匹配 (忽略大小写)
        try {
          foundOrig = files.firstWhere((f) => f.toLowerCase() == expectedOrig.toLowerCase());
        } catch (_) {}
      }

      if (foundOrig != null) {
        tasks.add({'wm': wm, 'clean': foundOrig});
      }
    }

    if (tasks.isEmpty) {
      _addLog("❌ 未找到匹配的图片对。\n请确保文件名包含 -wm 和 -orig");
    } else {
      _addLog("✅ 匹配到 ${tasks.length} 组图片，开始处理...");
      _runNativeRepair(tasks);
    }
  }

  // --- 调用 Kotlin 原生方法 ---
  Future<void> _runNativeRepair(List<Map<String, String>> tasks) async {
    setState(() => _isProcessing = true);
    
    try {
      // 告诉 Kotlin 开始干活
      final int successCount = await platform.invokeMethod('processImages', {
        'tasks': tasks,
        'confidence': _confidence,
        'search_ratio': [0.0, 0.0, 1.0, 1.0], // 全图搜索
      });

      _addLog("🎉 处理完成！成功修复 $successCount 张。\n已保存到相册/Pictures/LofterFixed");
      Fluttertoast.showToast(msg: "处理完成");
    } on PlatformException catch (e) {
      _addLog("❌ 错误: ${e.message}");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addLog(String msg) {
    setState(() {
      _log = "$msg\n\n$_log";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LOFTER 修复机"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "单张精修"), Tab(text: "批量处理")],
        ),
      ),
      body: Column(
        children: [
          // 置信度调节
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("🕵️ 侦探置信度: ${(_confidence * 100).toInt()}%"),
                Slider(
                  value: _confidence,
                  min: 0.1,
                  max: 0.9,
                  divisions: 8,
                  label: _confidence.toString(),
                  onChanged: (v) => setState(() => _confidence = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSingleTab(),
                _buildBatchTab(),
              ],
            ),
          ),
          // 日志区域
          Container(
            height: 150,
            width: double.infinity,
            color: Colors.black12,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Text(_log, style: const TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSingleTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _imgBtn("有水印图", _wmPath, true),
              const Icon(Icons.add),
              _imgBtn("无水印图", _noWmPath, false),
            ],
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _processSingle,
            icon: _isProcessing ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white, strokeWidth: 2)) : const Icon(Icons.build),
            label: Text(_isProcessing ? "正在修复..." : "开始修复"),
          )
        ],
      ),
    );
  }

  Widget _buildBatchTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_copy, size: 64, color: Colors.teal),
          const SizedBox(height: 20),
          const Text("规则说明：\n水印图需包含 -wm\n无水印图需包含 -orig", textAlign: TextAlign.center),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: _isProcessing ? null : _pickFilesBatch,
            child: const Text("选择多张图片 (自动配对)"),
          ),
        ],
      ),
    );
  }

  Widget _imgBtn(String label, String? path, bool isWm) {
    return InkWell(
      onTap: () => _pickImage(isWm),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              image: path != null ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) : null,
              border: Border.all(color: Colors.grey),
            ),
            child: path == null ? const Icon(Icons.image, size: 40, color: Colors.grey) : null,
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}