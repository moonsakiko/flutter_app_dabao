import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    await [Permission.manageExternalStorage, Permission.storage].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF 书签编辑器"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Icon(Icons.edit_document, size: 80, color: Colors.blueAccent),
             const SizedBox(height: 20),
             const Text("专业版书签管理", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             const Text("支持文本编辑、层级缩进、批量偏移", style: TextStyle(color: Colors.grey)),
             const SizedBox(height: 40),
             ElevatedButton.icon(
               style: ElevatedButton.styleFrom(
                 padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                 textStyle: const TextStyle(fontSize: 18),
               ),
               onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditorPage())),
               icon: const Icon(Icons.folder_open),
               label: const Text("开始使用"),
             ),
          ],
        ),
      ),
    );
  }
}
