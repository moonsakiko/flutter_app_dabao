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
      title: 'LOFTER 修复机',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        cardTheme: const CardTheme(elevation: 2, margin: EdgeInsets.all(8)),
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
  static const platform = MethodChannel('com.example.lofter_fixer/processor');

  double _confidence = 0.4;
  String? _wmPath;
  String? _noWmPath;
  String? _resultPath;
  bool _isProcessing = false;
  // 👇 更新了提示语
  String _log = "✅ 准备就绪\n📂 图片将保存至系统相册：\n图片(Pictures)/LofterFixed";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // 申请权限：Android 10+ 实际上不需要 storage 权限也能通过 MediaStore 保存，
    // 但为了读取图片，还是申请一下比较稳。
    await [
      Permission.storage,
      Permission.photos,
      Permission.manageExternalStorage // 尽量申请，虽然 MediaStore 方案不强依赖它
    ].request();
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("📖 使用说明"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("1. 保存位置", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("修复后的图片会自动保存到您的【系统相册】中，相册名为 LofterFixed。"),
              Text("也可以在【文件管理 -> Pictures -> LofterFixed】找到。"),
              SizedBox(height: 10),
              Text("2. 核心原理", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("AI 自动定位水印，从原图截取修复。"),
              SizedBox(height: 10),
              Text("3. 关于失败", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("如果提示“置信度过低”，请调低滑块；如果一直转圈，请重启APP。"),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }

  Future<void> _pickImage(bool isWm) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isWm) _wmPath = image.path;
        else _noWmPath = image.path;
        _resultPath = null;
      });
    }
  }

  Future<void> _processSingle() async {
    if (_wmPath == null || _noWmPath == null) {
      Fluttertoast.showToast(msg: "请先选择两张图片");
      return;
    }
    _runNativeRepair([{'wm': _wmPath!, 'clean': _noWmPath!}], isSingle: true);
  }

  Future<void> _pickFilesBatch() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image);
    if (result != null) {
      List<String> files = result.paths.whereType<String>().toList();
      _matchAndProcess(files);
    }
  }

  void _matchAndProcess(List<String> files) {
    List<Map<String, String>> tasks = [];
    List<String> wmFiles = files.where((f) => f.toLowerCase().contains("-wm.")).toList();
    
    for (var wm in wmFiles) {
      String expectedOrig = wm.replaceAll(RegExp(r'-wm\.', caseSensitive: false), '-orig.');
      String? foundOrig;
      try {
        foundOrig = files.firstWhere((f) => f == expectedOrig);
      } catch (e) {
        try {
          foundOrig = files.firstWhere((f) => f.toLowerCase() == expectedOrig.toLowerCase());
        } catch (_) {}
      }
      if (foundOrig != null) tasks.add({'wm': wm, 'clean': foundOrig});
    }

    if (tasks.isEmpty) {
      _addLog("❌ 未找到匹配图片。请确保文件名包含 -wm 和 -orig");
    } else {
      _addLog("✅ 匹配到 ${tasks.length} 组任务");
      _runNativeRepair(tasks, isSingle: false);
    }
  }

  Future<void> _runNativeRepair(List<Map<String, String>> tasks, {required bool isSingle}) async {
    setState(() => _isProcessing = true);
    try {
      final result = await platform.invokeMethod('processImages', {
        'tasks': tasks,
        'confidence': _confidence,
      });

      int successCount = result is int ? result : 0;
      
      String msg = successCount > 0 
          ? "🎉 成功修复 $successCount 张！\n📂 已保存至系统相册 (LofterFixed)" 
          : "⚠️ 未能修复，请调整置信度";
      
      _addLog(msg);
      Fluttertoast.showToast(msg: successCount > 0 ? "已保存到相册" : "修复失败");

      // 尝试在 UI 显示预览 (仅单张模式)
      if (isSingle && successCount > 0 && _wmPath != null) {
          // 由于 Android 11+ 限制，我们可能无法直接读取刚写入的文件路径用于显示
          // 所以这里我们仅提示，或者以后可以优化让 Kotlin 返回 Bitmap 给 Flutter 显示
          // 暂时清空预览路径，避免显示旧图
          setState(() => _resultPath = null); 
      }

    } on PlatformException catch (e) {
      _addLog("❌ 错误: ${e.message}");
      _showErrorDialog(e.message ?? "未知错误", e.details?.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String title, String? content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("⚠️ $title"),
        content: SingleChildScrollView(child: Text(content ?? "无详细日志")),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("关闭"))],
      ),
    );
  }

  void _addLog(String msg) {
    setState(() => _log = "$msg\n----------------\n$_log");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LOFTER 修复机"),
        actions: [IconButton(onPressed: _showHelp, icon: const Icon(Icons.help_outline))],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: "单张精修"), Tab(text: "批量处理")]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("🕵️ 侦探置信度: "),
                Expanded(
                  child: Slider(
                    value: _confidence, min: 0.1, max: 0.9, divisions: 8,
                    label: "${(_confidence * 100).toInt()}%",
                    onChanged: (v) => setState(() => _confidence = v),
                  ),
                ),
                Text("${(_confidence * 100).toInt()}%"),
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
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.black.withOpacity(0.05),
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Text(_log, style: const TextStyle(fontSize: 12, fontFamily: "monospace")),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSingleTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _imgBtn("有水印图", _wmPath, true),
              const Icon(Icons.add_circle_outline, color: Colors.grey),
              _imgBtn("无水印图", _noWmPath, false),
            ],
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _processSingle,
            icon: _isProcessing ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth:2, color:Colors.white)) : const Icon(Icons.auto_fix_high),
            label: Text(_isProcessing ? "正在修复..." : "开始修复"),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_zip, size: 80, color: Colors.teal),
          const SizedBox(height: 20),
          const Text("请选择图片对 (-wm.jpg 和 -orig.jpg)", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: _isProcessing ? null : _pickFilesBatch,
            child: const Text("📂 批量选择并修复"),
          ),
        ],
      ),
    );
  }

  Widget _imgBtn(String label, String? path, bool isWm) {
    return GestureDetector(
      onTap: () => _pickImage(isWm),
      child: Column(
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: Colors.grey[200], borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              image: path != null ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) : null,
            ),
            child: path == null ? const Icon(Icons.image_search, size: 40, color: Colors.grey) : null,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}