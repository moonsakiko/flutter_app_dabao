import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xhs_downloader_app/models/xhs_note.dart';
import 'package:xhs_downloader_app/services/download_service.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36") // 1. 伪装成电脑
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
          // 2. 拦截 "打开App" 的跳转 (xhsdiscover://)
          onNavigationRequest: (request) {
            if (!request.url.startsWith('http')) {
              debugPrint('拦截跳转: ${request.url}'); 
              return NavigationDecision.prevent; // 阻止跳转
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.xiaohongshu.com/explore'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小红书一张图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              _controller.loadRequest(Uri.parse('https://www.xiaohongshu.com/explore'));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(
              color: Color(0xFFFF2442),
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF2442),
        onPressed: _parseAndDownload,
        child: const Icon(Icons.download, color: Colors.white),
      ),
    );
  }

  // --- Core Extraction Logic ---
  Future<void> _parseAndDownload() async {
    try {
      // 1. Inject JS to get __INITIAL_STATE__
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          try {
            return JSON.stringify(window.__INITIAL_STATE__);
          } catch(e) {
            return null;
          }
        })();
      ''');

      if (result.toString() == 'null' || result.toString() == '{}') {
        _showSnack("未能提取到数据，请确保在笔记详情页！");
        return;
      }
      
      String jsonStr = result.toString();
      // Remove surrounding quotes if they exist
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        jsonStr = jsonStr.substring(1, jsonStr.length - 1);
        // Unescape standard json escapes
        jsonStr = jsonStr.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
      }

      // 2. Parse Logic
      final Map<String, dynamic> state = jsonDecode(jsonStr);
      final note = XHSNote.fromJson(state);
      
      if (note == null || note.resources.isEmpty) {
        _showSnack("当前页面不是有效的笔记详情页");
        return;
      }

      // 3. Confirm Dialog
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("发现 ${note.resources.length} 个资源"),
          content: Text("标题: ${note.title}\n即将下载到相册 (RedBookDownload)"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), 
              child: const Text("取消")
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("开始下载"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        _startDownload(note);
      }

    } catch (e) {
      _showSnack("解析失败: $e");
    }
  }

  Future<void> _startDownload(XHSNote note) async {
    _showSnack("开始后台下载...");
    
    final urls = note.resources.map((e) => e.url).toList();
    final stats = await DownloadService.downloadAll(urls, onProgress: (cur, total) {
       // Optional: update UI
    });
    
    _showSnack("下载完成! 成功: ${stats['success']}, 失败: ${stats['fail']}");
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
