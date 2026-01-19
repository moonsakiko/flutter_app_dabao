import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  
  /// Extract bookmarks as a raw string "Title \t PageIndex"
  static Future<String> extractBookmarksText(String filePath) async {
    return await compute(_extractTextHandler, filePath);
  }

  /// Save bookmarks from raw string to a NEW file
  static Future<void> saveBookmarksFromText({
    required String filePath,
    required String bookmarkContent,
  }) async {
    await compute(_saveTextHandler, {
      'filePath': filePath,
      'content': bookmarkContent,
    });
  }
}

Future<String> _extractTextHandler(String filePath) async {
  final file = File(filePath);
  final bytes = file.readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  final StringBuffer buffer = StringBuffer();

  void parse(PdfBookmarkBase collection, int depth) {
    for (int i = 0; i < collection.count; i++) {
       PdfBookmark b = collection[i];
       String indent = '\t' * depth;
       
       int pageIndex = 1;
       if (b.destination != null) {
         pageIndex = document.pages.indexOf(b.destination!.page) + 1;
       }
       // Format: Title <TAB> Page
       // Ensure title doesn't have tabs/newlines that break format?
       // PdgCntEditor usually: "Title(TAB)Page"
       String title = b.title.replaceAll('\n', '').replaceAll('\r', '');
       buffer.writeln("$indent$title\t$pageIndex");
       
       if (b.count > 0) parse(b, depth + 1);
    }
  }

  parse(document.bookmarks, 0);
  document.dispose();
  return buffer.toString();
}

Future<void> _saveTextHandler(Map<String, dynamic> args) async {
  final String filePath = args['filePath'];
  final String content = args['content'];
  
  final file = File(filePath);
  final bytes = file.readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  
  document.bookmarks.clear();
  
  // Parse content
  // Expected format: [Indentation]Title[TAB]PageNumber
  // Stack to track parents. 
  // Level 0 -> Parent is document.bookmarks
  // Level 1 -> Parent is last Level 0 bookmark
  
  List<PdfBookmarkBase> parentStack = [document.bookmarks];
  List<int> levelStack = [-1]; // Root level is -1 (conceptual)
  
  final lines = content.split('\n');
  
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    
    // Calculate indentation (Tab = 1 level)
    int level = 0;
    while (level < line.length && line[level] == '\t') {
      level++;
    }
    
    String trimmed = line.trim();
    // Split by last Tab or standard regex
    // Regex: Match everything until last digits
    final match = RegExp(r'^(.*?)\s+(\d+)$').firstMatch(trimmed);
    
    String title = trimmed;
    int page = 1;
    
    if (match != null) {
      title = match.group(1)!.trim();
      page = int.parse(match.group(2)!);
    } 
    
    // Validate Page
    if (page < 1) page = 1;
    if (page > document.pages.count) page = document.pages.count;
    
    // Find correct parent
    // If current level > last level, the last added item is the parent.
    // If current level <= last level, pop until we find parent.
    
    // Logic:
    // We need to maintain a stack of "Latest Bookmark at Level X".
    // Actually, `parentStack` can store parents. 
    // parentStack[0] = root.
    // parentStack[1] = level 0 parent (which is a bookmark).
    
    // If item is level 0: parent is stack[0].
    // If item is level 1: parent is stack[1].
    
    // Adjust stack to size = level + 1
    if (level >= parentStack.length) {
       // We should have pushed the parent previously.
       // If jump in level (e.g. 0 -> 2), it's invalid but we handle gracefully by attaching to nearest.
       // Standard behavior: Child of last item.
       // But Pdg format usually implies strict hierarchy steps.
       // If level jump, we just look at stack.last.
    } else {
       // Pop back
       while (parentStack.length > level + 1) {
         parentStack.removeLast();
       }
    }
    
    // Safety check
    PdfBookmarkBase parent = parentStack.last;
    
    PdfBookmark newBm = parent.add(title);
    newBm.destination = PdfDestination(document.pages[page - 1], const Offset(0, 0));
    
    // Prepare for next child
    // Since we just added at `level`, this item COULD be a parent for `level + 1`
    // We push it to stack? No, we only push it if the NEXT item increases level.
    // But we don't know the next item yet.
    // Strategy: Always set stack[level + 1] = newBm.
    // Or rather: parentStack should be the chain of active parents.
    
    if (parentStack.length > level + 1) {
       parentStack[level + 1] = newBm;
    } else {
       parentStack.add(newBm);
    }
  }
  
  final String newPath = filePath.replaceAll('.pdf', '_new.pdf');
  File(newPath).writeAsBytesSync(await document.save());
  document.dispose();
}
