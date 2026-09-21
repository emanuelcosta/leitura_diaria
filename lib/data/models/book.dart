enum Testament { at, nt }

Testament testamentFromCode(String code) => code == 'NT' ? Testament.nt : Testament.at;

String testamentToCode(Testament t) => t == Testament.nt ? 'NT' : 'AT';

class Book {
  final String id;
  final String name;
  final Testament testament;
  final int track;
  final int order;
  final int chapterCount;

  const Book({
    required this.id,
    required this.name,
    required this.testament,
    required this.track,
    required this.order,
    required this.chapterCount,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        name: json['name'] as String,
        testament: testamentFromCode(json['testament'] as String),
        track: json['track'] as int,
        order: json['order'] as int,
        chapterCount: json['chapters'] as int,
      );

  factory Book.fromMap(Map<String, Object?> map) => Book(
        id: map['id'] as String,
        name: map['name'] as String,
        testament: testamentFromCode(map['testament'] as String),
        track: map['track'] as int,
        order: map['book_order'] as int,
        chapterCount: map['chapter_count'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'testament': testamentToCode(testament),
        'track': track,
        'book_order': order,
        'chapter_count': chapterCount,
      };
}
