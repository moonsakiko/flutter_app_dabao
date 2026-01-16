class DiaryEntry {
  String id;
  String title;
  DateTime date;
  String content;

  DiaryEntry({
    required this.id,
    this.title = "",
    required this.date,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'content': content,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] ?? "",
      title: json['title'] ?? "",
      date: DateTime.parse(json['date']),
      content: json['content'] ?? "",
    );
  }
}

class FutureLetter {
  String id;
  DateTime createDate;
  DateTime deliveryDate;
  String content;
  bool isRead;

  FutureLetter({
    required this.id,
    required this.createDate,
    required this.deliveryDate,
    required this.content,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createDate': createDate.toIso8601String(),
        'deliveryDate': deliveryDate.toIso8601String(),
        'content': content,
        'isRead': isRead,
      };

  factory FutureLetter.fromJson(Map<String, dynamic> json) {
    return FutureLetter(
      id: json['id'],
      createDate: DateTime.parse(json['createDate']),
      deliveryDate: DateTime.parse(json['deliveryDate']),
      content: json['content'],
      isRead: json['isRead'] ?? false,
    );
  }
}