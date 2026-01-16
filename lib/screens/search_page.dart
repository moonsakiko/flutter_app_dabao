import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_model.dart';

class SearchPage extends StatefulWidget {
  final List<DiaryEntry> allEntries;
  final Function(DiaryEntry) onEntryTap;

  const SearchPage({super.key, required this.allEntries, required this.onEntryTap});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _keyword = "";
  List<DiaryEntry> _results = [];

  void _search(String val) {
    setState(() {
      _keyword = val;
      if (val.isEmpty) {
        _results = [];
      } else {
        _results = widget.allEntries.where((e) => 
          e.content.contains(val) || e.title.contains(val) || 
          DateFormat('yyyy-MM-dd').format(e.date).contains(val)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black87),
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "搜索日记关键词...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onChanged: _search,
        ),
      ),
      body: _keyword.isEmpty 
        ? const Center(child: Text("输入文字开始搜索", style: TextStyle(color: Colors.grey)))
        : _results.isEmpty 
          ? const Center(child: Text("未找到相关记忆", style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = _results[index];
                return ListTile(
                  title: Text(entry.title.isNotEmpty ? entry.title : DateFormat('yyyy-MM-dd').format(entry.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    entry.content.replaceAll("\n", " "), 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54)
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    widget.onEntryTap(entry); // 回调跳转
                  },
                );
              },
            ),
    );
  }
}