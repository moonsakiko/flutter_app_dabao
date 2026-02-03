import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xhs_downloader_app/models/xhs_note.dart';
import 'package:xhs_downloader_app/services/download_service.dart';
import 'package:dio/dio.dart' as import_dio; // Alias to avoid conflict if any

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
        _showSnack("未能提取到数据，请确保页面已加载完毕！");
        return;
      }
      
      String jsonStr = result.toString();
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        jsonStr = jsonStr.substring(1, jsonStr.length - 1);
        jsonStr = jsonStr.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
      }

      final Map<String, dynamic> state = jsonDecode(jsonStr);
      
      // --- Strategy A: Detail Page ---
      final note = XHSNote.fromJson(state);
      if (note != null && note.resources.isNotEmpty) {
         _showConfirmDialog(
           title: "发现 1 篇笔记",
           content: "标题: ${note.title}\n包含 ${note.resources.length} 个资源",
           onConfirm: () => _startDownload(note),
         );
         return;
      }

      // --- Strategy B: Batch/Collection Page ---
      // Try to find note lists in user dict or feed
      List<String> noteIds = [];
      
      // 1. Check User Profile / Collection
      if (state['user'] != null && state['user']['notes'] != null) {
         // User Profile tab
         final notes = state['user']['notes'];
         if (notes is List) {
            noteIds = notes.map((e) => e['noteId'].toString()).toList();
         } else if (notes is Map) {
            // Sometimes it's a map with 'value' list
            // Just scan nicely
         }
      }
      
      // 2. Generic "notes" or "feed" scan (Fallback)
      // Extract all top-level keys that look like note lists
      // This is a heuristic scan for "noteId"
      final rawStateStr = jsonEncode(state);
      final RegExp idRegex = RegExp(r'"noteId":"([a-f0-9]{24})"', caseSensitive: false);
      final ids = idRegex.allMatches(rawStateStr).map((m) => m.group(1)!).toSet().toList();
      
      if (ids.isNotEmpty) {
        noteIds = ids;
      }

      if (noteIds.isNotEmpty) {
        // Filter out nulls/duplicates
        noteIds = noteIds.toSet().toList();
        
        _showConfirmDialog(
           title: "发现合辑/列表",
           content: "检测到 ${noteIds.length} 篇笔记\n是否批量下载？(将后台解析)",
           onConfirm: () => _startBatchDownload(noteIds),
        );
      } else {
        _showSnack("未在此页面发现笔记或资源");
      }

    } catch (e) {
      _showSnack("解析错误: $e");
    }
  }

  void _showConfirmDialog({required String title, required String content, required VoidCallback onConfirm}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text("开始"),
          ),
        ],
      ),
    );
  }

  // Single Download
  Future<void> _startDownload(XHSNote note) async {
    _showSnack("开始下载: ${note.title}");
    final urls = note.resources.map((e) => e.url).toList();
    final stats = await DownloadService.downloadAll(urls);
    _showSnack("完成! 成功:${stats['success']} 失败:${stats['fail']}");
  }

  // Batch Download Logic
  Future<void> _startBatchDownload(List<String> noteIds) async {
     _showSnack("正在后台解析 ${noteIds.length} 篇笔记...");
     
     // 1. Sync Cookies from WebView to Dio
     final cookieMgr = WebViewCookieManager();
     final cookies = await cookieMgr.getCookies(Uri.parse('https://www.xiaohongshu.com'));
     final cookieStr = cookies.map((c) => "${c.name}=${c.value}").join('; ');
     
     // 2. Background Processing
     int success = 0;
     for (var i = 0; i < noteIds.length; i++) {
        final id = noteIds[i];
        
        // Update UI every few items? 
        // Showing simple snackbar progress for now
        if (i % 3 == 0) _showSnack("正在处理第 ${i+1}/${noteIds.length} 篇...");

        try {
           final note = await _fetchNoteDetail(id, cookieStr);
           if (note != null) {
              final urls = note.resources.map((e) => e.url).toList();
              final stats = await DownloadService.downloadAll(urls);
              if (stats['success']! > 0) success++;
           }
        } catch (e) {
           print("Batch Error [$id]: $e");
        }
        
        // Anti-ban delay
        await Future.delayed(const Duration(milliseconds: 1500));
     }
     
     _showSnack("批量任务结束! 成功处理笔记: $success 篇");
  }

  // Fetch HTML and parse manually
  Future<XHSNote?> _fetchNoteDetail(String noteId, String cookie) async {
     try {
       final dio = import_dio.Dio(); // Need to handle import alias if necessary, or just use Dio()
       final uri = "https://www.xiaohongshu.com/explore/$noteId";
       
       final response = await dio.get(
          uri,
          options: import_dio.Options(
             headers: {
                "Cookie": cookie,
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
             }
          )
       );
       
       final html = response.data.toString();
       // Regex Extract <script>window.__INITIAL_STATE__=
       final match = RegExp(r'window\.__INITIAL_STATE__=(.*?)</script>').firstMatch(html);
       if (match != null) {
          String jsonStr = match.group(1)!;
          // Sometimes it has undefined, replace it
          jsonStr = jsonStr.replaceAll("undefined", "null");
          final state = jsonDecode(jsonStr);
          return XHSNote.fromJson(state);
       }
     } catch (e) {
       print("Fetch Detail Error: $e");
     }
     return null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
