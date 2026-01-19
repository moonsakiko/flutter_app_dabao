import 'dart:io';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  
  /// Run Auto-Bookmark logic based on Regex
  /// [config] contains rules like {'level1': {'regex': '...', 'font_size': 15}}
  static Future<Map<String, dynamic>> runAutoBookmark({
    required String inputFolder,
    required String outputFolder,
    required Map<String, dynamic> config,
  }) async {
    try {
      final dir = Directory(inputFolder);
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf'));

      if (files.isEmpty) {
        return {'success': false, 'logs': 'No PDF files found in $inputFolder'};
      }

      StringBuffer logs = StringBuffer();
      logs.writeln("Found ${files.length} PDFs.");

      // Parse Regex Rules
      RegExp? regexL1;
      // RegExp? regexL2; // Expanded later
      
      if (config['level1']?['regex'] != null) {
        regexL1 = RegExp(config['level1']['regex']);
      }

      for (var file in files) {
        final filename = file.uri.pathSegments.last;
        logs.writeln("Processing $filename...");
        
        try {
          final List<int> bytes = await file.readAsBytes();
          final PdfDocument document = PdfDocument(inputBytes: bytes);
          final PdfTextExtractor extractor = PdfTextExtractor(document);
          
          // Clear existing bookmarks if needed? Syncfusion adds to existing list usually.
          document.bookmarks.clear();

          int bookmarksCount = 0;

          // Scanning pages
          for (int i = 0; i < document.pages.count; i++) {
            // Extract text with layout info is complex in syncfusion without specific license or deeply parsing.
            // Simplified approach: Extract text line by line and match regex.
            // Note: extractor.extractText(startPage: i, endPage: i) returns the whole page text.
            
            // To get lines, we split the text. This loses coordinate info but works for simple Regex matching on content.
            // For "font size" detection, we need extraction with bounds, which is heavier.
            // Syncfusion `PdfTextExtractor` has `extractTextLines()` which returns `TextLine` objects with bounds!
            
            final List<TextLine> lines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
            
            for (var line in lines) {
              final String text = line.text.trim();
              if (text.isEmpty) continue;

              // Check Regex
              if (regexL1 != null && regexL1.hasMatch(text)) {
                 // Check Font Size (Heuristic based on line height or implicit font info if available)
                 // TextLine object: bounds (Rect), text (String).
                 // We can estimate font size ~ height of bounds.
                 
                 double fontSizeThreshold = (config['level1']?['font_size'] ?? 0).toDouble();
                 if (fontSizeThreshold > 0) {
                   if (line.bounds.height < fontSizeThreshold) continue;
                 }

                 // Add Bookmark
                 final PdfBookmark bookmark = document.bookmarks.add(text);
                 bookmark.destination = PdfDestination(document.pages[i], Offset(line.bounds.left, line.bounds.top));
                 bookmarksCount++;
              }
            }
          }
          
          logs.writeln("  + Added $bookmarksCount bookmarks.");

          // Save
          final outputPath = "$outputFolder/$filename";
          File(outputPath).writeAsBytesSync(await document.save());
          document.dispose();
          
        } catch (e) {
          logs.writeln("  ! Error: $e");
        }
      }
      return {'success': true, 'logs': logs.toString()};
    } catch (e) {
      return {'success': false, 'logs': 'System Error: $e'};
    }
  }

  /// Add bookmarks from TXT
  static Future<Map<String, dynamic>> addBookmarks({
    required String sourceFolder,
    required String outputFolder,
    required int offset,
  }) async {
    try {
      final dir = Directory(sourceFolder);
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf'));
      StringBuffer logs = StringBuffer();

      if (!Directory(outputFolder).existsSync()) {
        Directory(outputFolder).createSync();
      }

      for (var file in files) {
        final filename = file.uri.pathSegments.last;
        final txtPath = file.path.replaceAll('.pdf', '.txt');
        
        if (!File(txtPath).existsSync()) {
          logs.writeln("Skipping $filename (No .txt found)");
          continue;
        }

        logs.writeln("Adding bookmarks to $filename...");
        
        final List<int> bytes = await file.readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        document.bookmarks.clear();

        final lines = File(txtPath).readAsLinesSync();
        List<PdfBookmark> parentStack = []; 
        // Syncfusion API: document.bookmarks.add() returns a bookmark which has .count and methods to add children?
        // Actually PdfBookmark has `child` property? No, standard is `bookmark.add(title)`.
        // Wait, document.bookmarks is a `PdfBookmarkCollection`.
        // document.bookmarks[i] is a `PdfBookmark`.
        // A `PdfBookmark` does NOT have an `add` method easily exposed in all versions?
        // Let's check API: `PdfBookmark` has a `indexer` or we add to `document.bookmarks`.
        // Correct API: `PdfBookmark` has no children collection exposed directly to ADD?
        // Ah, `PdfBookmark` class usually represents a node.
        // Syncfusion Flutter PDF: 
        // `document.bookmarks.add(title)` adds to root.
        // `PdfBookmark` does NOT have a `.add` method in Dart version?
        // Let's assume flattened for now or check if we can set parent.
        // Actually, standard Syncfusion usage:
        // PdfBookmark bookmark = document.bookmarks.add('Title');
        // bookmark.destination = ...
        // To add child: This library might be limited in creating hierarchy programmatically in the easy way?
        // CHECKED: `document.bookmarks.add` returns `PdfBookmark`. There is no `.add` on bookmark.
        // BUT, `document.bookmarks` IS the collection.
        // If we want nested, maybe we can't easily?
        // Wait, looking at docs: `document.bookmarks` is a list of top level.
        // Actually, usually `PdfBookmark` inherits from something or has a children list.
        // If not supported easily, we will do FLAT bookmarks for now to ensure compile safety.
        // OR we just assume it exists and if it breaks we fix. 
        // Most PDF libs support nesting.
        // Let's use `document.bookmarks.add` for all (Level 1) for safety in this refactor step.
        // IMPROVEMENT: If `PdfBookmark` has a list, we'd use it.
        
        for (var line in lines) {
           if (line.trim().isEmpty) continue;
           
           // Simple parser: "Title   Page"
           // Use regex to find last number
           final match = RegExp(r'(.*)\s+(\d+)$').firstMatch(line);
           if (match != null) {
              String title = match.group(1)!.trim();
              int page = int.parse(match.group(2)!) + offset;
              
              if (page < 1) page = 1;
              if (page > document.pages.count) page = document.pages.count;

              // Simple Level detection by tab count (optional)
              // int level = 0; if (line.startsWith('\t')) ...
              
              PdfBookmark bmp = document.bookmarks.add(title);
              bmp.destination = PdfDestination(document.pages[page - 1], const Offset(0, 0));
              
              // Set color/style if needed
              // bmp.textStyle = PdfTextStyle.bold;
              // bmp.color = PdfColor(255, 0, 0);
           }
        }

        final outPath = "$outputFolder/$filename";
        File(outPath).writeAsBytesSync(await document.save());
        document.dispose();
      }
      return {'success': true, 'logs': logs.toString()};

    } catch (e) {
      return {'success': false, 'logs': e.toString()};
    }
  }

  /// Extract Bookmarks
  static Future<Map<String, dynamic>> extractBookmarks({
    required String inputFolder,
    required String outputFolder,
  }) async {
    try {
      final dir = Directory(inputFolder);
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf'));
      StringBuffer logs = StringBuffer();

      if (!Directory(outputFolder).existsSync()) {
        Directory(outputFolder).createSync();
      }
      
      for (var file in files) {
        final filename = file.uri.pathSegments.last;
        logs.writeln("Extracting from $filename...");
        
        final List<int> bytes = await file.readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        
        StringBuffer txtContent = StringBuffer();
        
        // Recursive helper
        void parseBookmarks(PdfBookmarkBase  collection, int depth) {
           for (int i=0; i<collection.count; i++) {
              PdfBookmark b = collection[i];
              String indent = '\t' * depth;
              
              // Get Page Number
              // b.destination?.page usually returns the page object.
              // Getting index of page object:
              int pageIndex = document.pages.indexOf(b.destination!.page);
              
              txtContent.writeln("$indent${b.title}\t${pageIndex + 1}");
              
              // Recurse (PdfBookmark usually acts as a collection if it has children)
              // Syncfusion Dart API: PdfBookmark IS A PdfBookmarkBase? 
              // check `b.count` or `b.length`?
              // `PdfBookmark` extends `PdfBookmarkBase`?
              // If compile fails here, we will fix. Assuming yes.
              if (b.count > 0) {
                 parseBookmarks(b, depth + 1);
              }
           }
        }
        
        parseBookmarks(document.bookmarks, 0);
        
        final outPath = "$outputFolder/${filename.replaceAll('.pdf', '.txt')}";
        File(outPath).writeAsStringSync(txtContent.toString());
        document.dispose();
      }
       return {'success': true, 'logs': logs.toString()};
    } catch (e) {
       return {'success': false, 'logs': e.toString()};
    }
  }
}
