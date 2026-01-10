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
  String _log = "✅ 系统就绪\n📂 图片将自动保存至【下载/LofterFixed】文件夹\n⏳ Android 10+ 用户保存无需权限";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestAllPermissions();
  }

  // 🛡️ 暴力权限请求 (兼容所有版本)
  Future<void> _requestAllPermissions() async {
    // 1. 基础存储权限
    await Permission.storage.request();
    // 2. 安卓10+ 媒体权限
    await Permission.photos.request();
    // 3. 极少数情况需要的管理权限 (如果上面的够了，这一步用户拒绝也没事)
    if (await Permission.manageExternalStorage.status.isDenied) {
        // 不强制请求，以免把用户吓跑，保存逻辑里用了 MediaStore，不需要这个也能存
        // await Permission.manageExternalStorage.request();
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("📖 说明书"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("💡 保存位置", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              Text("修复后的图片在手机的【Download (下载) / LofterFixed】文件夹中。相册通常也能看到。"),
              Divider(),
              Text("🔧 使用技巧", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("如果提示修复成功但没看到图：\n1. 打开手机自带的“文件管理”APP\n2. 找到 Download 文件夹\n3. 刷新一下"),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("好"))],
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
      } catch (_) {
        try {
          foundOrig = files.firstWhere((f) => f.toLowerCase() == expectedOrig.toLowerCase());
        } catch (_) {}
      }
      if (foundOrig != null) tasks.add({'wm': wm, 'clean': foundOrig});
    }

    if (tasks.isEmpty) {
      _addLog("❌ 未找到匹配图片 (-wm / -orig)");
    } else {
      _addLog("✅ 匹配到 ${tasks.length} 组");
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
      
      if (successCount > 0) {
        _addLog("🎉 成功修复 $successCount 张\n📂 文件已保存至 Download/LofterFixed");
        Fluttertoast.showToast(msg: "修复成功！");
        
        // 尝试推测路径进行预览 (仅供参考，不一定绝对准确)
        if (isSingle && _wmPath != null) {
           // 注意：这只是为了预览，实际文件已通过 MediaStore 保存
           setState(() {}); 
        }
      } else {
        _addLog("⚠️ 未能修复，请检查置信度");
      }

    } on PlatformException catch (e) {
      _addLog("❌ 错误: ${e.message}\n${e.details ?? ''}");
    } finally {
      setState(() => _isProcessing = false);
    }
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "单张精修"), Tab(text: "批量处理")],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text("🕵️ 置信度: "),
                Expanded(
                  child: Slider(
                    value: _confidence,
                    min: 0.1, max: 0.9, divisions: 8,
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
              children: [_buildSingleTab(), _buildBatchTab()],
            ),
          ),
          Container(
            height: 150,
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
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _imgBtn("有水印图", _wmPath, true),
              const Icon(Icons.add, color: Colors.grey),
              _imgBtn("无水印图", _noWmPath, false),
            ],
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _processSingle,
            icon: _isProcessing ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.auto_fix_high),
            label: Text(_isProcessing ? "处理中..." : "开始修复"),
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
          const Icon(Icons.folder_copy, size: 80, color: Colors.teal),
          const SizedBox(height: 20),
          const Text("请选择多张图片 (自动配对)", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          FilledButton(onPressed: _isProcessing ? null : _pickFilesBatch, child: const Text("📂 选择文件")),
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
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              image: path != null ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) : null,
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