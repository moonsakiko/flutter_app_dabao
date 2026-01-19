import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../config/app_config.dart';
import '../utils/text_parser.dart';
import '../utils/pdf_handler.dart';
import '../widgets/keyboard_accessory.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
  String? _filePath;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  late TabController _tabController;
  List<BookmarkNode> _previewNodes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1) _refreshPreview();
  }
  
  void _refreshPreview() {
     if (_textCtrl.text.isNotEmpty) {
       setState(() {
         _previewNodes = TextParser.textToBookmarks(_textCtrl.text);
       });
     }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final path = result.files.single.path!;
      _loadFile(path);
    }
  }

  Future<void> _loadFile(String path) async {
    setState(() {
      _filePath = path;
      _isLoading = true;
    });
    
    try {
      final bookmarks = await PdfHandler.readBookmarks(path);
      final text = TextParser.bookmarksToText(bookmarks);
      setState(() {
        _textCtrl.text = text;
        _isLoading = false;
        _previewNodes = bookmarks;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("读取失败: $e");
    }
  }

  Future<void> _save() async {
    if (_filePath == null) return;
    setState(() => _isLoading = true);
    
    try {
      final nodes = TextParser.textToBookmarks(_textCtrl.text);
      String savePath = await PdfHandler.writeBookmarks(_filePath!, nodes);
      _showSuccess(savePath);
    } catch (e) {
      _showError("保存失败: $e");
    }
    
    setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
  
  void _showSuccess(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("保存成功"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("文件已保存至："),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Text(path, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            const Text("提示：优先保存在原文件同级，若无权限则保存在下载目录。", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("好"))],
      ),
    );
  }

  // --- Logic for Accessory Bar ---

  void _insertTab() {
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    if (selection.start < 0) return;
    final newText = text.replaceRange(selection.start, selection.end, AppConfig.indentChar);
    _textCtrl.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.start + 1));
  }

  void _removeTab() {
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    if (selection.start <= 0) return;
    if (text.substring(selection.start - 1, selection.start) == AppConfig.indentChar) {
       final newText = text.replaceRange(selection.start - 1, selection.start, '');
       _textCtrl.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.start - 1));
    }
  }

  void _adjustPage(int delta) {
    _applyToSelection((title, page) => page + delta);
  }

  // --- Advanced Tools ---

  // Helper to modify selected lines or all lines
  void _applyToSelection(int Function(String title, int page) modifier) {
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    
    // If no selection (collapsed), apply to current line
    // If selection range, apply to all full/partial lines in range
    // If text empty, do nothing
    if (text.isEmpty) return;
    
    int start = selection.start < 0 ? 0 : selection.start;
    int end = selection.end < 0 ? 0 : selection.end;
    
    // Expand to full lines
    String before = text.substring(0, start);
    int lineStart = before.lastIndexOf('\n') + 1;
    
    int lineEnd = text.indexOf('\n', end);
    if (lineEnd == -1) lineEnd = text.length;
    
    String rangeText = text.substring(lineStart, lineEnd);
    List<String> lines = rangeText.split('\n');
    List<String> newLines = [];
    
    for (var line in lines) {
      final match = RegExp(r'^(.*)\s+(\d+)$').firstMatch(line);
      if (match != null) {
        String pre = match.group(1)!;
        int oldPage = int.parse(match.group(2)!);
        int newPage = modifier(pre, oldPage);
        if (newPage < 1) newPage = 1;
        newLines.add("$pre\t$newPage");
      } else {
        newLines.add(line);
      }
    }
    
    String replacement = newLines.join('\n');
    String newText = text.replaceRange(lineStart, lineEnd, replacement);
    
    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + replacement.length),
    );
  }

  void _showToolsDialog() {
    showModalBottomSheet(
      context: context, 
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.exposure), 
            title: const Text("整体偏移 (Global Offset)"),
            subtitle: const Text("所有选中行 (或全部) 页码 +/- N"),
            onTap: () { Navigator.pop(ctx); _showOffsetDialog(); }
          ),
          ListTile(
            leading: const Icon(Icons.start), 
            title: const Text("设置初始页码 (Set Base Page)"),
            subtitle: const Text("将当前行的页码设为 X，自动计算偏移量"),
            onTap: () { Navigator.pop(ctx); _showBasePageDialog(); }
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.help_outline), title: const Text("使用帮助"), onTap: () { Navigator.pop(ctx); _showHelpDialog(); }),
        ],
      )
    );
  }

  void _showOffsetDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("整体偏移"),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "偏移量 (例如 +10, -5)")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(onPressed: () {
            int val = int.tryParse(ctrl.text) ?? 0;
            if (val != 0) _applyToSelection((t, p) => p + val);
            Navigator.pop(ctx);
          }, child: const Text("执行")),
        ],
      )
    );
  }

  void _showBasePageDialog() {
    // Determine current logical page from cursor line
    int currentPage = 0;
    // ... (logic similar to adjustPage to find current line page)
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    int start = selection.start < 0 ? 0 : selection.start;
    String before = text.substring(0, start);
    int lineStart = before.lastIndexOf('\n') + 1;
    int lineEnd = text.indexOf('\n', start);
    if (lineEnd == -1) lineEnd = text.length;
    String line = text.substring(lineStart, lineEnd);
    final match = RegExp(r'^(.*)\s+(\d+)$').firstMatch(line);
    if (match != null) currentPage = int.parse(match.group(2)!);

    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("设置初始页码"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("当前行页码: $currentPage"),
            TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "应改为 (逻辑页码)")),
            const SizedBox(height: 8),
            const Text("提示：将计算差值并应用到选区/全文", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(onPressed: () {
            int target = int.tryParse(ctrl.text) ?? 0;
            if (target > 0) {
               int delta = target - currentPage;
               _applyToSelection((t, p) => p + delta);
            }
            Navigator.pop(ctx);
          }, child: const Text("执行")),
        ],
      )
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("功能说明"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("【基本操作】", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("• 缩进 ->| : 增加层级 (子章节)"),
              Text("• 反缩进 |<- : 减少层级 (父章节)"),
              Text("• 页码 +/- 1 : 微调当前行页码"),
              SizedBox(height: 10),
              Text("【高级功能 (右上角菜单)】", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("• 整体偏移 : 批量增加或减少页码。"),
              Text("• 初始页码 : 用于对齐目录。例如目录页码写的是 1，但 PDF 实际上是第 5 页，输入 5 -> 1，软件会自动让所有后续页码 -4。"),
              SizedBox(height: 10),
              Text("【保存】", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("• 默认尝试保存在原文件旁边 (_new.pdf)。"),
              Text("• 如果失败，会自动保存在 Download/PDF书签精灵 文件夹。"),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("明白了"))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filePath == null ? AppConfig.appName : File(_filePath!).uri.pathSegments.last.replaceAll('.pdf', '')),
        elevation: 0,
        actions: [
          if (_filePath != null) ...[
             IconButton(icon: const Icon(Icons.file_open), tooltip: "切换文件", onPressed: _pickFile),
             IconButton(icon: const Icon(Icons.build), tooltip: "工具箱", onPressed: _showToolsDialog),
             IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _save),
          ]
        ],
        bottom: _filePath != null ? TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "编辑"), Tab(text: "预览")],
        ) : null,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _filePath == null 
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _pickFile, child: const Text("打开 PDF 文件")),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                        child: KeyboardAccessory(
                          onTab: _insertTab,
                          onUntab: _removeTab,
                          onPageInc: () => _adjustPage(1),
                          onPageDec: () => _adjustPage(-1),
                          onPreview: () { _focusNode.unfocus(); _tabController.animateTo(1); },
                          onHideKeyboard: () => _focusNode.unfocus(),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          focusNode: _focusNode,
                          maxLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 16, height: 1.5),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(16),
                            border: InputBorder.none,
                            hintText: "书签标题 <Tab> 页码",
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildPreview(),
                ],
              ),
    );
  }

  Widget _buildPreview() {
    if (_previewNodes.isEmpty) return const Center(child: Text("无书签"));
    return ListView.builder(
      itemCount: _previewNodes.length,
      itemBuilder: (context, index) {
        final node = _previewNodes[index];
        return Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1)))),
          padding: EdgeInsets.only(left: 16.0 * node.level + 16, top: 12, bottom: 12, right: 16),
          child: Row(
            children: [
              Expanded(child: Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                child: Text(node.pageNumber.toString(), style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}
