class Chapter {
  final String id;
  final String bookId;
  final int chapterNumber;
  final int planDay;
  final bool isRead;
  final DateTime? readAt;
  final String? note;

  const Chapter({
    required this.id,
    required this.bookId,
    required this.chapterNumber,
    required this.planDay,
    required this.isRead,
    this.readAt,
    this.note,
  });

  factory Chapter.fromMap(Map<String, Object?> map) => Chapter(
        id: map['id'] as String,
        bookId: map['book_id'] as String,
        chapterNumber: map['chapter_number'] as int,
        planDay: map['plan_day'] as int,
        isRead: (map['is_read'] as int) == 1,
        readAt: map['read_at'] == null ? null : DateTime.parse(map['read_at'] as String),
        note: map['note'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_number': chapterNumber,
        'plan_day': planDay,
        'is_read': isRead ? 1 : 0,
        'read_at': readAt?.toIso8601String(),
        'note': note,
      };

  Chapter copyWith({
    bool? isRead,
    DateTime? readAt,
    String? note,
    bool clearReadAt = false,
    bool clearNote = false,
  }) {
    return Chapter(
      id: id,
      bookId: bookId,
      chapterNumber: chapterNumber,
      planDay: planDay,
      isRead: isRead ?? this.isRead,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

/// A single day's reading assignment: the chapter ids newly introduced that day.
class PlanDay {
  final int day;
  final List<String> chapterIds;

  const PlanDay({required this.day, required this.chapterIds});

  factory PlanDay.fromJson(Map<String, dynamic> json) => PlanDay(
        day: json['day'] as int,
        chapterIds: (json['chapters'] as List).cast<String>(),
      );
}
