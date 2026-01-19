import 'dart:convert';
import 'package:flutter/services.dart';

class PythonService {
  static const MethodChannel _channel = MethodChannel('com.pdftool.pro/python');

  /// Runs a python script via the bridge.
  /// [script]: 'auto_shuqian' | 'add_bookmarks' | 'inspector' | 'extract'
  /// [args]: Map of arguments
  static Future<Map<String, dynamic>> runScript(String script, Map<String, dynamic> args) async {
    try {
      final String jsonArgs = jsonEncode(args);
      final String resultStr = await _channel.invokeMethod('runScript', {
        'script': script,
        'args': jsonArgs,
      });
      return jsonDecode(resultStr);
    } on PlatformException catch (e) {
      return {
        "success": false,
        "message": "Native Error: ${e.message}",
        "logs": ""
      };
    }
  }
}
