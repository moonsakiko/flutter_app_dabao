import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/pdf_service.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  String? _filePath;
  final TextEditingController _ctrl = TextEditingController();
  bool _isLoading = false;
  
  // Text Styles
  final TextStyle _editorStyle = const TextStyle(
    fontFamily: 'monospace', 
    fontSize: 14, 
    height: 1.5,
    color: Colors.black87,
  );

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final path = result.files.single.path!;
      setState(() {
        _filePath = path;
        _isLoading = true;
      });
      
      try {
        final text = await PdfService.extractBookmarksText(path);
        setState(() {
           _ctrl.text = text;
           _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("读取失败: $e")));
      }
    }
  }

  Future<void> _save() async {
    if (_filePath == null) return;
    setState(() => _isLoading = true);
    
    try {
      await PdfService.saveBookmarksFromText(
        filePath: _filePath!, 
        bookmarkContent: _ctrl.text
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存为 _new.pdf")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("保存失败: $e")));
    }
    
    setState(() => _isLoading = false);
  }

  // --- Toolbar Actions ---

  void _applyOffset(int offset) {
    if (_ctrl.text.isEmpty) return;

    final lines = _ctrl.text.split('\n');
    final buffer = StringBuffer();
    
    for (var line in lines) {
      if (line.trim().isEmpty) {
        buffer.writeln(line);
        continue;
      }
      
      // Regex find last number
      final match = RegExp(r'^(.*)\s+(\d+)$').firstMatch(line);
      if (match != null) {
        String pre = match.group(1)!;
        int page = int.parse(match.group(2)!);
        page += offset;
        if (page < 1) page = 1;
        buffer.writeln("$pre\t$page");
      } else {
        buffer.writeln(line);
      }
    }
    
    setState(() {
      _ctrl.text = buffer.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已偏移 $offset 页")));
  }

  Future<void> _showOffsetDialog() async {
    final offsetCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("批量修改页码"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("输入正数增加，负数减少"),
            TextField(
              controller: offsetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "偏移量 (例如 +10)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(onPressed: () {
             final val = int.tryParse(offsetCtrl.text) ?? 0;
             if (val != 0) _applyOffset(val);
             Navigator.pop(ctx);
          }, child: const Text("确定")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filePath == null ? "书签编辑器" : File(_filePath!).uri.pathSegments.last),
        actions: [
          if (_filePath != null) ...[
            IconButton(
              icon: const Icon(Icons.save), 
              tooltip: "保存 (另存为 _new.pdf)",
              onPressed: _isLoading ? null : _save
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          if (_filePath != null)
            Container(
              color: Colors.grey[200],
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  TextButton.icon(
                    onPressed: () => _showOffsetDialog(),
                    icon: const Icon(Icons.exposure),
                    label: const Text("页码偏移"),
                  ),
                  const VerticalDivider(indent: 8, endIndent: 8),
                  TextButton.icon(
                    onPressed: () {
                      // Insert Tab at cursor? Simple implementation: append to end or specialized edit
                      // For simplicity in Flutter TextField default is just typing.
                      // Providing a "Help" about format.
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("格式: 标题 <TAB> 页码")));
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text("格式说明"),
                  ),
                ],
              ),
            ),
            
          Expanded(
            child: _filePath == null
               ? Center(
                   child: ElevatedButton.icon(
                     onPressed: _pickFile,
                     icon: const Icon(Icons.folder_open, size: 30),
                     label: const Text("打开 PDF 文件", style: TextStyle(fontSize: 18)),
                   ),
                 )
               : _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null, // Expands
                        keyboardType: TextInputType.multiline,
                        style: _editorStyle,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "书签内容...\n示例:\n第一章\t5\n\t1.1 节\t6",
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
