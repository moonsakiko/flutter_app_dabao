import '../config/app_config.dart';

class BookmarkNode {
  String title;
  int pageNumber;
  int level; // 0-based depth
  List<BookmarkNode> children = []; // For tree view
  
  BookmarkNode({required this.title, required this.pageNumber, required this.level});
}

class TextParser {
  
  static String bookmarksToText(List<BookmarkNode> nodes) {
    // Flatten logic if recursive structure passed?
    // Usually readBookmarks returns flattened. 
    // If nodes are trees, we need to flatten first. 
    // But `PdfHandler` returns flattened.
    final buffer = StringBuffer();
    for (var node in nodes) {
      String indent = AppConfig.indentChar * node.level;
      String cleanTitle = node.title.replaceAll('\n', '').replaceAll('\r', '');
      buffer.writeln("$indent$cleanTitle${AppConfig.indentChar}${node.pageNumber}");
      // If tree, recurse? No, PdfHandler.readBookmarks returns flat list usually.
    }
    return buffer.toString();
  }

  static List<BookmarkNode> textToBookmarks(String text) {
    List<BookmarkNode> nodes = [];
    final lines = text.split('\n');
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      int level = 0;
      while (line.startsWith(AppConfig.indentChar, level)) {
        level++;
      }
      
      String content = line.trim();
      final match = RegExp(r'^(.*)\s+(\d+)$').firstMatch(content);
      
      String title = content;
      int page = 1;
      
      if (match != null) {
        title = match.group(1)!.trim();
        page = int.parse(match.group(2)!);
      }
      
      nodes.add(BookmarkNode(title: title, pageNumber: page, level: level));
    }
    return nodes;
  }
}
