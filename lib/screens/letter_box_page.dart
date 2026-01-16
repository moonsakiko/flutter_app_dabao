import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_model.dart';
import '../utils/storage_helper.dart';

class LetterBoxPage extends StatefulWidget {
  final Function(List<FutureLetter>) onSave;
  const LetterBoxPage({super.key, required this.onSave});
  @override
  State<LetterBoxPage> createState() => _LetterBoxPageState();
}

class _LetterBoxPageState extends State<LetterBoxPage> {
  List<FutureLetter> letters = [];
  
  @override
  void initState() {
    super.initState();
    StorageHelper.loadLetters().then((l) => setState(() => letters = l));
  }

  void _addLetter() {
    TextEditingController c = TextEditingController();
    DateTime d = DateTime.now().add(const Duration(days: 30));
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("写给未来", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(children: [const Text("送达日期："), TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, initialDate: d, firstDate: DateTime.now(), lastDate: DateTime(2100), locale: const Locale('zh')); if(p!=null) setS(()=>d=p); }, child: Text(DateFormat('yyyy-MM-dd').format(d)))]),
        TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: "对未来的自己说...", border: OutlineInputBorder())),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: (){ 
          letters.add(FutureLetter(id: DateTime.now().toString(), createDate: DateTime.now(), deliveryDate: d, content: c.text));
          widget.onSave(letters); Navigator.pop(ctx); setState((){}); 
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white), child: const Text("寄出"))
      ])
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("时间胶囊"), backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      floatingActionButton: FloatingActionButton(onPressed: _addLetter, backgroundColor: Colors.black87, child: const Icon(Icons.send, color: Colors.white)),
      body: ListView.builder(itemCount: letters.length, itemBuilder: (c, i) {
        final l = letters[i];
        final arrived = DateTime.now().isAfter(l.deliveryDate);
        return ListTile(
          leading: Icon(arrived ? Icons.mark_email_read : Icons.hourglass_bottom, color: arrived ? Colors.black : Colors.grey),
          title: Text("寄往 ${DateFormat('yyyy-MM-dd').format(l.deliveryDate)}"),
          subtitle: Text(arrived ? "已送达" : "运输中..."),
          onTap: arrived ? () => showDialog(context: context, builder: (c) => AlertDialog(content: Text(l.content))) : null,
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: (){ setState(() => letters.removeAt(i)); widget.onSave(letters); }),
        );
      }),
    );
  }
}