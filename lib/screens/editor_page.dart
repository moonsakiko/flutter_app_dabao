import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_model.dart';

class EditorPage extends StatefulWidget {
  final DiaryEntry? entry;
  final String? initialContent;
  final Function(DiaryEntry) onSave;
  final Function(String) onDelete;

  const EditorPage({super.key, this.entry, this.initialContent, required this.onSave, required this.onDelete});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late DateTime _selectedDate;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry?.date ?? DateTime.now();
    _titleCtrl = TextEditingController(text: widget.entry?.title ?? "");
    _contentCtrl = TextEditingController(text: widget.initialContent ?? widget.entry?.content ?? "");
    _isEditing = widget.entry == null;
  }

  void _handleSave() {
    if (_contentCtrl.text.isEmpty) return;
    final entry = DiaryEntry(
      id: widget.entry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text,
      date: _selectedDate,
      content: _contentCtrl.text,
    );
    widget.onSave(entry);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.titleLarge?.color ?? Colors.black;
    final hintColor = theme.brightness == Brightness.dark ? Colors.white24 : Colors.black26;

    // 获取动态字体
    final titleStyle = theme.textTheme.titleLarge?.copyWith(fontSize: (theme.textTheme.titleLarge?.fontSize ?? 17) + 4); // 标题比列表再大一点
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.8); // 编辑时行高再大一点点

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: BackButton(color: textColor, onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.calendar_today, size: 16, color: textColor.withOpacity(0.7)),
            label: Text(DateFormat('yyyy.MM.dd').format(_selectedDate), style: TextStyle(color: textColor)),
            onPressed: _isEditing ? () async {
              final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: const Locale('zh', 'CN'));
              if (d != null) setState(() => _selectedDate = d);
            } : null,
          ),
          if (_isEditing)
             IconButton(icon: Icon(Icons.check, color: textColor), onPressed: _handleSave)
          else ...[
             IconButton(icon: Icon(Icons.edit, color: textColor.withOpacity(0.7)), onPressed: () => setState(() => _isEditing = true)),
             IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {
              widget.onDelete(widget.entry!.id);
              Navigator.pop(context);
            }),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              enabled: _isEditing,
              style: titleStyle, // 使用动态标题样式
              decoration: InputDecoration(
                hintText: "标题", 
                border: InputBorder.none, 
                hintStyle: TextStyle(color: hintColor)
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentCtrl,
              enabled: _isEditing,
              maxLines: null,
              style: bodyStyle, // 使用动态正文样式
              decoration: InputDecoration(
                hintText: "记录当下...", 
                border: InputBorder.none, 
                hintStyle: TextStyle(color: hintColor)
              ),
            ),
            const SizedBox(height: 300),
          ],
        ),
      ),
    );
  }
}