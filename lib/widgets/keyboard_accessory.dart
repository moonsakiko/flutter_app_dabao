import 'package:flutter/material.dart';

class KeyboardAccessory extends StatelessWidget {
  final VoidCallback onTab;
  final VoidCallback onUntab;
  final VoidCallback onPageInc; // Maps to Global Offset +
  final VoidCallback onPageDec; // Maps to Global Offset -... Wait, user removed +/- 1.
  // Actually, user said: "Remove single +/- 1 buttons. Put Global +/- here."
  // So we changed the logic in EditorScreen to use new buttons.
  // Let's reflect the EditorScreen changes in this widget if needed, 
  // BUFFER: EditorScreen actually builds the toolbar locally now (see line 351 in previous EditorScreen content).
  // I should update this file anyway to prevent unused code confusion or keep it as legacy?
  // User didn't ask to delete it, but EditorScreen usages replaced it. 
  // Wait, EditorScreen used `KeyboardAccessory` in the body.
  // I should update THIS widget to match the new buttons requested: 
  // [Indent] [Unindent] [Offset] [Clear]
  
  final VoidCallback onOffset; // Global Offset dialog
  final VoidCallback onClear;
  final VoidCallback onPreview;
  final VoidCallback onHideKeyboard;

  const KeyboardAccessory({
    super.key,
    required this.onTab,
    required this.onUntab,
    required this.onOffset,
    required this.onClear,
    required this.onPreview,
    required this.onHideKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: Colors.grey[200],
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildBtn(Icons.keyboard_tab, "缩进", onTab),
          _buildBtn(Icons.west, "反缩进", onUntab),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          _buildBtn(Icons.exposure, "整体偏移", onOffset),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          _buildBtn(Icons.delete_sweep, "清空", onClear, color: Colors.red),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          _buildBtn(Icons.visibility, "预览", onPreview),
          _buildBtn(Icons.keyboard_hide, "收起", onHideKeyboard),
        ],
      ),
    );
  }

  Widget _buildBtn(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? Colors.blue[700]),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
