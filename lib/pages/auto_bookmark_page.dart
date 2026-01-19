import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/pdf_service.dart';

class AutoBookmarkPage extends StatefulWidget {
  const AutoBookmarkPage({super.key});

  @override
  State<AutoBookmarkPage> createState() => _AutoBookmarkPageState();
}

class _AutoBookmarkPageState extends State<AutoBookmarkPage> {
  List<String> _selectedFiles = [];
  bool _isRunning = false;
  String _logs = "";
  
  // Config
  final TextEditingController _regexCtrl = TextEditingController(text: r"^\s*第[一二三四五六七八九十百]+章\s*\S+");
  final TextEditingController _sizeCtrl = TextEditingController(text: "15");

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.paths.whereType<String>().toList();
        _logs = "已选择 ${_selectedFiles.length} 个文件";
      });
    }
  }

  Future<void> _runTask() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先选择 PDF 文件")));
      return;
    }
    
    setState(() {
      _isRunning = true;
      _logs = "任务开始...\n(后台处理中，请稍候)";
    });

    // 默认输出到文件所在目录
    String outputDir = File(_selectedFiles.first).parent.path;
    
    // Config
    final config = {
      "level1": {
        "regex": _regexCtrl.text,
        "font_size": int.tryParse(_sizeCtrl.text) ?? 15
      }
    };

    final result = await PdfService.runAutoBookmark(
      filePaths: _selectedFiles,
      outputDir: outputDir,
      config: config
    );

    setState(() {
      _isRunning = false;
      String currentLogs = result['logs'] ?? "";
      if (result['success'] == true) {
         currentLogs = "=== 任务完成 ===\n" + currentLogs;
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("处理完成")));
      } else {
         currentLogs = "=== 任务失败 ===\n" + currentLogs;
      }
      _logs = currentLogs;
    });
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("使用说明"),
        content: const SingleChildScrollView(
          child: Text(
            "1. 选择文件：支持多选 PDF。\n"
            "2. 正则表达式：用于匹配章节标题。\n"
            "   示例：^\\s*第[一二三四五六七八九十百]+章\\s*\\S+  (匹配 '第xx章 标题')\n"
            "3. 字体阈值：只匹配行高大于此值的文字，防止匹配到正文中的类似文字。\n"
            "4. 输出：生成的 PDF 会保存在原文件夹，文件名后缀为 _bk.pdf。"
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("明白了"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("自动生成书签"),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: _showHelp),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                 // File Selection
                 Card(
                   child: ListTile(
                     leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                     title: Text(_selectedFiles.isEmpty ? "点击选择 PDF 文件" : "已选 ${_selectedFiles.length} 个文件"),
                     subtitle: Text(_selectedFiles.isEmpty ? "支持多选" : "点击重新选择"),
                     onTap: _isRunning ? null : _pickFiles,
                     trailing: const Icon(Icons.upload_file),
                   ),
                 ),
                 
                 if (_selectedFiles.isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                     child: Text(
                       "首个文件: ${File(_selectedFiles.first).uri.pathSegments.last} ...",
                       style: const TextStyle(fontSize: 12, color: Colors.grey),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),

                 const SizedBox(height: 20),
                 const Text("规则配置", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 const SizedBox(height: 10),
                 
                 TextField(
                   controller: _regexCtrl,
                   decoration: const InputDecoration(
                     labelText: "一级标题正则 (Regex)",
                     border: OutlineInputBorder(),
                     helperText: "用于匹配章节标题的模式",
                   ),
                 ),
                 const SizedBox(height: 15),
                 TextField(
                   controller: _sizeCtrl,
                   keyboardType: TextInputType.number,
                   decoration: const InputDecoration(
                     labelText: "最小字体/行高",
                     border: OutlineInputBorder(),
                     helperText: "过滤小字号文本 (0 表示不限制)",
                   ),
                 ),
              ],
            ),
          ),
          
          if (_isRunning) 
            const LinearProgressIndicator(),

          Container(
             color: Colors.grey[900],
             height: 180,
             width: double.infinity,
             padding: const EdgeInsets.all(8),
             child: SingleChildScrollView(
               child: Text(_logs, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
             ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                 width: double.infinity,
                 height: 50,
                 child: ElevatedButton(
                   onPressed: (_isRunning || _selectedFiles.isEmpty) ? null : _runTask,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.blueAccent,
                     foregroundColor: Colors.white,
                   ),
                   child: const Text("开始生成", style: TextStyle(fontSize: 18)),
                 ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
