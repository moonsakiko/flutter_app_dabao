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
        cardTheme: const CardTheme(elevation: 2, margin: EdgeInsets.symmetric(vertical: 8)),
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

  double _confidence = 0.5;
  String? _wmPath;
  String? _noWmPath;
  bool _isProcessing = false;
  
  // 页面控制
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    // Android 13+ 需要 photos 权限，旧版需要 storage
    if (await Permission.storage.request().isGranted || 
        await Permission.photos.request().isGranted) {
      // 权限已获取
    }
  }

  // --- 侧边栏导航逻辑 ---
  void _onDrawerItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // 关闭抽屉
  }

  // --- 核心业务逻辑 ---
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

  Future<void> _pickFilesBatch() async {
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
      if (foundOrig != null) {
        tasks.add({'wm': wm, 'clean': foundOrig});
      }
    }

    if (tasks.isEmpty) {
      _showDialog("配对失败", "未找到符合规则的图片对。\n\n请确保：\n1. 水印图文件名包含 -wm\n2. 原图文件名包含 -orig");
    } else {
      _runNativeRepair(tasks);
    }
  }

  Future<void> _runNativeRepair(List<Map<String, String>> tasks) async {
    setState(() => _isProcessing = true);
    try {
      // Kotlin 返回的是一个 Map
      final result = await platform.invokeMethod('processImages', {
        'tasks': tasks,
        'confidence': _confidence,
      });

      final int count = result['count'];
      final String lastPath = result['lastPath'] ?? "";

      if (count > 0) {
        _showSuccessDialog(count, lastPath);
      } else {
        _showDialog("提示", "处理完成，但没有图片被修复。");
      }

    } on PlatformException catch (e) {
      _showDialog("处理失败", "错误信息：\n${e.message}\n${e.details ?? ''}");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // --- 弹窗组件 ---
  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("确定"))],
      ),
    );
  }

  void _showSuccessDialog(int count, String previewPath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("修复成功!")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("成功处理了 $count 张图片。"),
            const SizedBox(height: 8),
            const Text("✅ 已保存到系统相册 (LofterFixed)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 16),
            if (previewPath.isNotEmpty) ...[
              const Text("最新修复预览:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              ClipRRect( // 尝试显示预览图，content:// 路径可能需要特殊处理，但这里先尝试
                borderRadius: BorderRadius.circular(8),
                child: Image.network(previewPath, height: 150, width: double.infinity, fit: BoxFit.cover, 
                  errorBuilder: (_,__,___) => Container(
                    height: 100, color: Colors.grey[200], 
                    child: const Center(child: Text("预览加载中...请去相册查看")),
                  ),
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("太棒了")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 侧边栏内容
    var drawerOptions = [
      const ListTile(leading: Icon(Icons.home), title: Text("修复工坊")),
      const ListTile(leading: Icon(Icons.book), title: Text("使用说明书")),
      const ListTile(leading: Icon(Icons.info), title: Text("关于软件")),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("LOFTER 修复机"),
        bottom: _selectedIndex == 0 ? TabBar(controller: _tabController, tabs: const [Tab(text: "单张精修"), Tab(text: "批量处理")]) : null,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text("LOFTER 修复机"),
              accountEmail: Text("v1.0.0 Release"),
              currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.build, size: 30, color: Colors.teal)),
              decoration: BoxDecoration(color: Colors.teal),
            ),
            for (int i = 0; i < drawerOptions.length; i++)
              ListTile(
                leading: (drawerOptions[i] as ListTile).leading,
                title: (drawerOptions[i] as ListTile).title,
                selected: _selectedIndex == i,
                onTap: () => _onDrawerItemTapped(i),
              ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildRepairPage();
      case 1: return _buildManualPage();
      case 2: return _buildAboutPage();
      default: return _buildRepairPage();
    }
  }

  Widget _buildRepairPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("🕵️ 侦探灵敏度: ${(_confidence * 100).toInt()}%"),
                  Tooltip(
                    message: "越低越容易发现水印，但也更容易误判",
                    child: Icon(Icons.help_outline, size: 18, color: Colors.grey[600]),
                  )
                ],
              ),
              Slider(value: _confidence, min: 0.1, max: 0.9, divisions: 8, label: _confidence.toString(), onChanged: (v) => setState(() => _confidence = v)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildSingleTab(), _buildBatchTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleTab() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imgBtn("有水印图", _wmPath, true),
                const Icon(Icons.add, color: Colors.grey),
                _imgBtn("无水印原图", _noWmPath, false),
              ],
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _processSingle,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              icon: _isProcessing 
                ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white, strokeWidth: 2)) 
                : const Icon(Icons.auto_fix_high),
              label: Text(_isProcessing ? "正在施法..." : "开始修复"),
            ),
            const SizedBox(height: 20),
            const Text("结果将自动保存至相册 'LofterFixed'", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_zip, size: 80, color: Colors.teal.withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text("批量处理模式", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("需手动选择多张图片，程序自动配对", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _pickFilesBatch,
            icon: const Icon(Icons.photo_library),
            label: const Text("去相册选择图片"),
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
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              image: path != null ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) : null,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: path == null 
              ? Icon(isWm ? Icons.broken_image : Icons.image, size: 40, color: Colors.grey) 
              : null,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- 说明书页面 ---
  Widget _buildManualPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text("📖 使用说明书", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Divider(),
        SizedBox(height: 10),
        _ManualItem(icon: Icons.filter_1, title: "单张精修模式", content: "适用于少量修复。手动点击左边框选中有水印的图，右边框选中无水印的原图，点击修复即可。"),
        _ManualItem(icon: Icons.filter_9_plus, title: "批量处理模式", content: "适用于大量图片。\n\n1. 请在相册中长按选择所有相关图片。\n2. 程序会根据文件名自动配对。\n\n⚠️ 命名规则：\n水印图需包含 '-wm' (如 abc-wm.jpg)\n原图需包含 '-orig' (如 abc-orig.jpg)"),
        _ManualItem(icon: Icons.tune, title: "灵敏度调节", content: "如果修复失败（没反应），请尝试调低灵敏度（例如 30%）。\n如果修复位置错误，请尝试调高灵敏度。"),
        _ManualItem(icon: Icons.save, title: "文件保存", content: "所有修复成功的图片都会自动保存到系统相册的 'LofterFixed' 相册中，您可以直接在相册APP中查看。"),
      ],
    );
  }

  Widget _buildAboutPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handyman, size: 80, color: Colors.teal),
          SizedBox(height: 20),
          Text("LOFTER 修复机", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("v1.0.0 by GitHub Actions", style: TextStyle(color: Colors.grey)),
          SizedBox(height: 40),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text("基于 Flutter + Kotlin + YOLOv8 构建的端侧去水印工具。\n\n无需联网，保护隐私。", textAlign: TextAlign.center),
          )
        ],
      ),
    );
  }
}

class _ManualItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  const _ManualItem({required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.teal), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Text(content, style: TextStyle(color: Colors.grey[700], height: 1.5)),
          ],
        ),
      ),
    );
  }
}