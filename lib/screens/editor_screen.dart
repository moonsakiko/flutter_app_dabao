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
  // ... (Existing variables)
  String? _filePath;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  late TabController _tabController;
  
  // Preview Tree
  // We need a structured tree for Folding, not just a flat list for Preview
  // Reusing BookmarkNode which already has structure implicitly by level
  // But for ExpansionTile we need real hierarchy.
  List<BookmarkNode> _flatNodes = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _textCtrl.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1) _refreshPreview();
  }
  
  void _refreshPreview() {
     if (_textCtrl.text.isNotEmpty) {
       setState(() {
         _flatNodes = TextParser.textToBookmarks(_textCtrl.text);
       });
     }
  }

  // ... (Pick/Save logic identical, just update UI)
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) _loadFile(result.files.single.path!);
  }

  Future<void> _loadFile(String path) async {
    setState(() => _isLoading = true);
    _filePath = path; 
    try {
      final bookmarks = await PdfHandler.readBookmarks(path);
      final text = TextParser.bookmarksToText(bookmarks);
      setState(() {
        _textCtrl.text = text;
        _isLoading = false;
        _flatNodes = bookmarks;
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
  
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  
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
             Container(padding: const EdgeInsets.all(8), color: Colors.grey[200], child: Text(path, style: const TextStyle(fontSize: 12))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("好"))],
      ),
    );
  }

  // --- Toolbar Logic ---
  
  void _insertTab() {
    // ... same ...
     final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    if (selection.start < 0) return;
    final newText = text.replaceRange(selection.start, selection.end, AppConfig.indentChar);
    _textCtrl.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.start + 1));
  }

  void _removeTab() {
     // ... same ...
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    if (selection.start <= 0) return;
    if (text.substring(selection.start - 1, selection.start) == AppConfig.indentChar) {
       final newText = text.replaceRange(selection.start - 1, selection.start, '');
       _textCtrl.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.start - 1));
    }
  }
  
  void _clearAll() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("清空确认"),
      content: const Text("确定要清空编辑器内容吗？"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
        TextButton(onPressed: () { _textCtrl.clear(); Navigator.pop(ctx); }, child: const Text("清空", style: TextStyle(color: Colors.red))),
      ]
    ));
  }

  // --- Advanced Tools ---

  // Updated: If no selection, apply to ALL.
  void _applyToSelection(int Function(String title, int page) modifier) {
    final text = _textCtrl.text;
    if (text.isEmpty) return;
    
    final selection = _textCtrl.selection;
    int start = 0;
    int end = text.length;

    // Check if selection exists
    bool hasSelection = selection.start != -1 && selection.end != -1 && selection.start != selection.end;
    if (hasSelection) {
       start = selection.start;
       end = selection.end;
    }
    
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
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hasSelection ? "已对选中行应用" : "已对全文应用")));
  }
  
  void _showOffsetDialog() {
     // ... same ...
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("整体偏移"),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "偏移量 (+/- N)")),
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

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filePath == null ? AppConfig.appName : File(_filePath!).uri.pathSegments.last.replaceAll('.pdf', '')),
        actions: [
          if (_filePath != null) ...[
             IconButton(icon: const Icon(Icons.file_open), tooltip: "切换文件", onPressed: _pickFile),
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
            ? Center(child: ElevatedButton(onPressed: _pickFile, child: const Text("打开 PDF 文件")))
            : TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Prevent swipe to avoid conflict
                children: [
                  Column(
                    children: [
                      // Updated Toolbar
                      Container(
                        height: 50, color: Colors.grey[200],
                        child: ListView(
                           scrollDirection: Axis.horizontal,
                           padding: const EdgeInsets.symmetric(horizontal: 8),
                           children: [
                             IconButton(icon: const Icon(Icons.keyboard_tab), onPressed: _insertTab, tooltip: "缩进"),
                             IconButton(icon: const Icon(Icons.west), onPressed: _removeTab, tooltip: "反缩进"),
                             const VerticalDivider(),
                             IconButton(icon: const Icon(Icons.exposure), onPressed: _showOffsetDialog, tooltip: "整体偏移"),
                              // Base Page can be in dialog or here. Let's keep it clean, maybe just Offset is enough as per request?
                              // User asked to REMOVE +/- 1 and put Global Offset here.
                             const VerticalDivider(),
                             IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.red), onPressed: _clearAll, tooltip: "清空"),
                           ],
                        ),
                      ),
                      Expanded(
                        child: KeyboardAccessory(
                          onTab: _insertTab,
                          onUntab: _removeTab,
                          onOffset: _showOffsetDialog,
                          onClear: _clearAll,
                          onPreview: () { _focusNode.unfocus(); _tabController.animateTo(1); },
                          onHideKeyboard: () => _focusNode.unfocus(),
                          child: TextField(
                            controller: _textCtrl,
                            focusNode: _focusNode,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 16, height: 1.5),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.all(16), border: InputBorder.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildFoldablePreview(),
                ],
              ),
    );
  }
  
  Widget _buildFoldablePreview() {
     if (_flatNodes.isEmpty) return const Center(child: Text("无书签"));
     // Build Tree from flat list
     List<BookmarkNode> roots = _buildTree(_flatNodes);
     return ListView(children: roots.map((n) => _buildNode(n)).toList());
  }
  
  // Helper to build recursive UI
  Widget _buildNode(BookmarkNode node) {
     if (node.children.isEmpty) {
       return ListTile(
         controller: ScrollController(), // Fix weird error if needed? No.
         dense: true,
         title: Text(node.title),
         trailing: Text(node.pageNumber.toString()),
         contentPadding: EdgeInsets.only(left: 16.0 + (node.level * 16), right: 16),
       );
     } else {
       return ExpansionTile(
         title: Text(node.title),
         trailing: Text(node.pageNumber.toString()), // Trailing on tile forces arrow to left or hides it? 
         // ExpansionTile default trailing is arrow. Customizing it is tricky.
         // Let's put page number in subtitle or title
         // title: Row(children: [Expanded(child: Text(node.title)), Text(node.pageNumber.toString())]),
         tilePadding: EdgeInsets.only(left: 16.0 + (node.level * 16), right: 16),
         children: node.children.map((c) => _buildNode(c)).toList(),
       );
     }
  }
  
  // Helper to reconstruct tree for View
  List<BookmarkNode> _buildTree(List<BookmarkNode> flat) {
     // Deep copy to avoid modifying original flat if passed by ref
     // But simple struct is okay.
     // We need to add 'children' property to Node or wrapper.
     // Since BookmarkNode is configured in another file, let's just make a Wrapper here or modify BookmarkNode.
     // Let's assume BookmarkNode doesn't have children field (it was simple flat in text_parser).
     // Wait, text_parser.dart `BookmarkNode` definition:
     // class BookmarkNode { String title; int pageNumber; int level; } 
     // We need to add `children` to it or use a temporary wrapper.
     // Let's modify text_parser.dart to include children for convenience? 
     // Or just use a local map.
     
     // Let's use a local wrapper class for UI
     return _reconstruct(flat);
  }
  
  List<BookmarkNode> _reconstruct(List<BookmarkNode> flat) {
     // This is O(N) stack method similar to save logic
     List<BookmarkNode> roots = [];
     List<BookmarkNode> stack = []; // Parents
     
     for (var node in flat) {
        // We need to clone node to add children to it (dynamic expansion)
        // Since Dart classes are open, we can't add fields.
        // Let's assume we can attach children in a Map or List<dynamic>
        // Check `TextParser`... it is simple.
        // Strategy: Create a `ViewNode` class here.
        var viewNode = node; // Treating as ViewNode dynamically? No, strict types.
        // Okay, I will add `List<BookmarkNode> children = []` to `BookmarkNode` in next step.
        // For now, assuming it exists or I update it.
        
        // Let's Update text_parser.dart to have children!
        node.children.clear(); // Reset 
        
        if (node.level == 0) {
           roots.add(node);
           stack = [node]; // Reset stack to this root
        } else {
           // Find parent
           // If current level > stack.length, it's a leap, attach to last
           // If current level <= stack.length - 1 ...
           
           // Correct logic:
           // Stack[0] -> Level 0
           // Stack[k] -> Level k
           
           if (node.level > stack.length) {
              // Gap? Just attach to last
              if (stack.isNotEmpty) stack.last.children.add(node);
           } else {
              // Pop until stack size == level
              // e.g. Node Level 1. Stack size should be 1 (index 0).
              while (stack.length > node.level) {
                 stack.removeLast();
              }
              if (stack.isNotEmpty) stack.last.children.add(node);
           }
           stack.add(node); // Push self
        }
     }
     return roots;
  }
}
