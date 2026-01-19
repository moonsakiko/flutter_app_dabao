import 'package:flutter/material.dart';

class KeyboardAccessory extends StatelessWidget {
  final VoidCallback onTab;
  final VoidCallback onUntab;
  final VoidCallback onBasePage;
  final VoidCallback onOffset;
  final VoidCallback onClear;
  final VoidCallback onPaste; // New: Paste
  final VoidCallback onHideKeyboard;

  const KeyboardAccessory({
    super.key,
    required this.onTab,
    required this.onUntab,
    required this.onBasePage,
    required this.onOffset,
    required this.onClear,
    required this.onPaste, // Replaces Preview
    required this.onHideKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: Colors.grey[200],
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   _buildBtn(Icons.keyboard_tab, "缩进", onTab),
                   _buildBtn(Icons.west, "反缩进", onUntab),
                   const VerticalDivider(width: 20, indent: 10, endIndent: 10),
                   // Icon: Architecture (Neutral, like caliper/divider user showed)
                   _buildBtn(Icons.architecture, "设置初始页码", onBasePage), 
                   _buildBtn(Icons.exposure, "整体偏移", onOffset),
                   const VerticalDivider(width: 20, indent: 10, endIndent: 10),
                   // Swap Hide and Paste Position?
                   // User said: "Lastly swap (Paste) and Keyboard Hide".
                   // Original order was: ... [Preview/Paste] [Hide]
                   // Swapped: [Hide] [Paste]
                   _buildBtn(Icons.keyboard_hide, "收起", onHideKeyboard),
                   _buildBtn(Icons.content_paste, "粘贴", onPaste), // Paste icon
                ],
              ),
            ),
          ),
          // Clear fixed to right
          const VerticalDivider(width: 1, indent: 10, endIndent: 10),
          _buildBtn(Icons.delete_sweep, "清空", onClear, color: Colors.red),
          const SizedBox(width: 8),
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
