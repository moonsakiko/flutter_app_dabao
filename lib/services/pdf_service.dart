import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart'; // For compute
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Performance-Optimized PDF Service using Isolates
class PdfService {
  
  /// Run Auto-Bookmark logic in a background thread
  static Future<Map<String, dynamic>> runAutoBookmark({
    required List<String> filePaths,
    required String outputDir,
    required Map<String, dynamic> config,
  }) async {
    return await compute(_autoBookmarkHandler, {
      'files': filePaths,
      'outputDir': outputDir,
      'config': config,
    });
  }

  /// Add bookmarks from TXT in a background thread
  static Future<Map<String, dynamic>> addBookmarks({
    required List<String> filePaths,
    required String outputDir,
    required int offset,
  }) async {
    return await compute(_addBookmarksHandler, {
      'files': filePaths,
      'outputDir': outputDir,
      'offset': offset,
    });
  }

  /// Extract Bookmarks in a background thread
  static Future<Map<String, dynamic>> extractBookmarks({
    required List<String> filePaths,
    required String outputDir,
  }) async {
    return await compute(_extractBookmarksHandler, {
      'files': filePaths,
      'outputDir': outputDir,
    });
  }
}

// --- Top-Level Handlers for Isolates ---

Future<Map<String, dynamic>> _autoBookmarkHandler(Map<String, dynamic> args) async {
  try {
    final List<String> files = args['files'];
    final String outputDir = args['outputDir'];
    final Map<String, dynamic> config = args['config'];
    
    final StringBuffer logs = StringBuffer();
    logs.writeln("开始处理 ${files.length} 个文件...");

    // Pre-compile Regex
    RegExp? regexL1;
    if (config['level1']?['regex'] != null) {
      regexL1 = RegExp(config['level1']['regex']);
    }

    // Ensure output dir
    final dir = Directory(outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    for (var path in files) {
      final file = File(path);
      final filename = file.uri.pathSegments.last;
      logs.writeln("处理中: $filename");

      try {
        final List<int> bytes = file.readAsBytesSync();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final PdfTextExtractor extractor = PdfTextExtractor(document);

        // Clear existing?
        document.bookmarks.clear();
        int addedCount = 0;
        
        // Font size threshold
        double fontSizeThreshold = (config['level1']?['font_size'] ?? 0).toDouble();

        for (int i = 0; i < document.pages.count; i++) {
          // Extract lines with bounds
          final List<TextLine> lines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
          
          for (var line in lines) {
            final String text = line.text.trim();
            if (text.isEmpty) continue;

            if (regexL1 != null && regexL1.hasMatch(text)) {
               // Font size check (Height approximation)
               if (fontSizeThreshold > 0 && line.bounds.height < fontSizeThreshold) {
                 continue;
               }

               final PdfBookmark bookmark = document.bookmarks.add(text);
               bookmark.destination = PdfDestination(document.pages[i], Offset(line.bounds.left, line.bounds.top));
               addedCount++;
            }
          }
        }
        
        logs.writeln("  已添加 $addedCount 个书签");

        final savePath = "$outputDir/${filename.replaceAll('.pdf', '')}_bk.pdf";
        File(savePath).writeAsBytesSync(await document.save());
        document.dispose();
        
      } catch (e) {
        logs.writeln("  错误: $e");
      }
    }
    return {'success': true, 'logs': logs.toString()};
  } catch (e) {
    return {'success': false, 'logs': '系统错误: $e'};
  }
}

Future<Map<String, dynamic>> _addBookmarksHandler(Map<String, dynamic> args) async {
  try {
    final List<String> files = args['files'];
    final String outputDir = args['outputDir'];
    final int offset = args['offset'];
    
    final StringBuffer logs = StringBuffer();
    final dir = Directory(outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    for (var path in files) {
      final file = File(path);
      final filename = file.uri.pathSegments.last;
      
      // Look for TXT in same folder as PDF
      final txtPath = path.replaceAll('.pdf', '.txt');
      
      if (!File(txtPath).existsSync()) {
        logs.writeln("跳过 $filename (未找到同名 .txt 文件)");
        continue;
      }
      
      logs.writeln("正在为 $filename 添加书签...");
      
      try {
        final List<int> bytes = file.readAsBytesSync();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        document.bookmarks.clear();
        
        final lines = File(txtPath).readAsLinesSync();
        
        for (var line in lines) {
           if (line.trim().isEmpty) continue;
           
           // Format: "Title   PageNum"
           final match = RegExp(r'(.*)\s+(\d+)$').firstMatch(line);
           if (match != null) {
              String title = match.group(1)!.trim();
              int page = int.parse(match.group(2)!) + offset;
              
              if (page < 1) page = 1;
              if (page > document.pages.count) page = document.pages.count;

              final PdfBookmark bmp = document.bookmarks.add(title);
              bmp.destination = PdfDestination(document.pages[page - 1], const Offset(0, 0));
           }
        }
        
        final savePath = "$outputDir/${filename.replaceAll('.pdf', '')}_new.pdf";
        File(savePath).writeAsBytesSync(await document.save());
        document.dispose();
        logs.writeln("  成功保存到: ${filename.replaceAll('.pdf', '')}_new.pdf");
      
      } catch (e) {
        logs.writeln("  错误: $e");
      }
    }
    return {'success': true, 'logs': logs.toString()};
  } catch (e) {
    return {'success': false, 'logs': '系统错误: $e'};
  }
}

Future<Map<String, dynamic>> _extractBookmarksHandler(Map<String, dynamic> args) async {
  try {
    final List<String> files = args['files'];
    final String outputDir = args['outputDir'];
    
    final StringBuffer logs = StringBuffer();
    final dir = Directory(outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    for (var path in files) {
      final file = File(path);
      final filename = file.uri.pathSegments.last;
      logs.writeln("正在提取: $filename");
      
      try {
        final List<int> bytes = file.readAsBytesSync();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final StringBuffer txtContent = StringBuffer();
        
        void parseBookmarks(PdfBookmarkBase collection, int depth) {
           for (int i=0; i<collection.count; i++) {
              PdfBookmark b = collection[i];
              String indent = '\t' * depth;
              
              int pageIndex = -1;
              if (b.destination != null) {
                pageIndex = document.pages.indexOf(b.destination!.page);
              }
              
              txtContent.writeln("$indent${b.title}\t${pageIndex + 1}");
              
              if (b.count > 0) {
                 parseBookmarks(b, depth + 1);
              }
           }
        }
        
        parseBookmarks(document.bookmarks, 0);
        
        final txtName = filename.replaceAll('.pdf', '.txt');
        File("$outputDir/$txtName").writeAsStringSync(txtContent.toString());
        document.dispose();
        logs.writeln("  导出为: $txtName");
        
      } catch (e) {
        logs.writeln("  错误: $e");
      }
    }
    return {'success': true, 'logs': logs.toString()};
  } catch (e) {
    return {'success': false, 'logs': '系统错误: $e'};
  }
}
