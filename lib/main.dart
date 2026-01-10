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
      // 这个 title 仅用于调试，实际打包名由 AndroidManifest 决定
      title: 'LOFTER 修复机', 
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
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

  double _confidence = 0.4; // 默认调低一点，更灵敏
  String? _wmPath;
  String? _noWmPath;
  bool _isProcessing = false;
  String _log = "✅ 准备就绪\n📂 结果将保存至：下载目录/LofterFixed";
  
  // 存储修复成功的图片路径，用于预览
  final List<String> _successFiles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Android 11+ 可能需要 MANAGE_EXTERNAL_STORAGE，这里先请求基础的
    await [Permission.storage, Permission.photos].request();
    // 针对 Android 11+ 的特殊处理通常在 Native 层或由用户手动授权，简单起见先略过
  }

  // --- 帮助说明 ---
  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("使用说明书 📖"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("1. 单张模式", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("分别选择【有水印图】和【无水印原图】，点击修复即可。"),
              SizedBox(height: 10),
              Text("2. 批量模式", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("一次性选择所有文件。系统会根据文件名自动配对：\n• 水印图需含：-wm (如 a-wm.jpg)\n• 原图需含：-orig (如 a-orig.jpg)"),
              SizedBox(height: 10),
              Text("3. 找不到图片？", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("修复后的图片保存在手机的【Download/LofterFixed】文件夹下。"),
              SizedBox(height: 10),
              Text("4. 修复失败？", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("• 尝试降低【侦探置信度】\n• 确保两张图构图完全一致"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("懂了"))
        ],
      ),
    );
  }

  Future<void> _pickImage(bool isWm) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isWm) _wmPath = image.path; else _noWmPath = image.path;
      });
    }
  }

  Future<void> _processSingle() async {
    if (_wmPath == null || _noWmPath == null) {
      Fluttertoast.showToast(msg: "请先选择两张图片");
      return;
    }
    // 清空上次的预览
    setState(() => _successFiles.clear());
    _runNativeRepair([{'wm': _wmPath!, 'clean': _noWmPath!}]);
  }

  Future<void> _pickFilesBatch() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image);
    if (result != null) {
      List<String> files = result.paths.whereType<String>().toList();
      _matchAndProcess(files);
    }
  }

  void _matchAndProcess(List<String> files) {
    setState(() => _successFiles.clear());
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
      _addLog("🧩 匹配到 ${tasks.length} 组任务，引擎启动...");
      _runNativeRepair(tasks);
    }
  }

  Future<void> _runNativeRepair(List<Map<String, String>> tasks) async {
    setState(() => _isProcessing = true);
    try {
      // ⚠️ 修改点：Kotlin 现在返回的是成功文件的路径列表 List<String>
      final List<dynamic> results = await platform.invokeMethod('processImages', {
        'tasks': tasks,
        'confidence': _confidence,
      });

      List<String> successPaths = results.cast<String>();

      if (successPaths.isNotEmpty) {
        setState(() {
          _successFiles.addAll(successPaths);
        });
        _addLog("🎉 成功修复 ${successPaths.length} 张！\n📂 已保存到 Download/LofterFixed");
        Fluttertoast.showToast(msg: "修复成功，已保存至下载目录");
      } else {
        // 如果列表为空，说明虽然没报错，但逻辑上没修成功（日志已由Kotlin返回）
      }
    } on PlatformException catch (e) {
      _addLog("❌ 系统级错误: ${e.message}");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addLog(String msg) {
    setState(() => _log = "$msg\n----------\n$_log");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LOFTER 修复机"),
        actions: [
          IconButton(onPressed: _showHelp, icon: const Icon(Icons.help_outline))
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "单张精修"), Tab(text: "批量处理")],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              children: [
                const Text("🕵️ 灵敏度: "),
                Expanded(
                  child: Slider(
                    value: _confidence,
                    min: 0.1, max: 0.9, divisions: 8,
                    label: _confidence.toString(),
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
          // --- 预览区域 ---
          if (_successFiles.isNotEmpty)
            Container(
              height: 120,
              color: Colors.teal.withOpacity(0.1),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("✨ 本次修复成果 (点击查看):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _successFiles.length,
                      itemBuilder: (ctx, i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () {
                              // 简单的全屏查看
                              showDialog(context: context, builder: (_) => Dialog(child: Image.file(File(_successFiles[i]))));
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(_successFiles[i]), width: 100, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          // --- 日志区域 ---
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Text(_log, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: "monospace")),
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
              const Icon(Icons.add_circle_outline, size: 30),
              _imgBtn("无水印图", _noWmPath, false),
            ],
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _processSingle,
            icon: _isProcessing ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_fix_high),
            label: Text(_isProcessing ? "正在修复..." : "开始修复"),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
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
          const Icon(Icons.folder_zip_outlined, size: 80, color: Colors.teal),
          const SizedBox(height: 20),
          const Text("请选择包含配对文件的文件夹\n(自动识别 -wm 和 -orig)", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: _isProcessing ? null : _pickFilesBatch,
            child: const Text("选择多张图片"),
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
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade400),
              image: path != null ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) : null,
            ),
            child: path == null ? Icon(Icons.image_search, size: 40, color: Colors.grey[400]) : null,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}