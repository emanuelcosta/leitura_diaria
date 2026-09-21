enum Testament { at, nt }

Testament testamentFromCode(String code) => code == 'NT' ? Testament.nt : Testament.at;

String testamentToCode(Testament t) => t == Testament.nt ? 'NT' : 'AT';

/// Traditional grouping of Bible books by literary/historical category,
/// derived from a book's position in canonical order (`Book.order`).
enum BookCategory {
  pentateuco('Pentateuco'),
  historico('Histórico'),
  poetico('Poético'),
  profeticoMaior('Profético Maior'),
  profeticoMenor('Profético Menor'),
  evangelhos('Evangelhos'),
  historiaApostolica('História Apostólica'),
  cartasPaulinas('Cartas Paulinas'),
  cartasGerais('Cartas Gerais'),
  apocalipse('Apocalipse');

  final String label;
  const BookCategory(this.label);
}

/// Canonical book order (1-66) is contiguous per category, so the category
/// can be derived from `order` alone without any extra data.
BookCategory categoryForOrder(int order) {
  if (order <= 5) return BookCategory.pentateuco;
  if (order <= 17) return BookCategory.historico;
  if (order <= 22) return BookCategory.poetico;
  if (order <= 27) return BookCategory.profeticoMaior;
  if (order <= 39) return BookCategory.profeticoMenor;
  if (order <= 43) return BookCategory.evangelhos;
  if (order <= 44) return BookCategory.historiaApostolica;
  if (order <= 57) return BookCategory.cartasPaulinas;
  if (order <= 65) return BookCategory.cartasGerais;
  return BookCategory.apocalipse;
}

/// Standard Portuguese Bible abbreviations (same ones used in the `abbrev`
/// field of assets/bible/*.json), indexed by canonical order (1-66) — kept
/// as a small static lookup here instead of a DB column/reading_plan.json
/// field since it's only used for search matching, not displayed anywhere.
const _abbreviations = [
  'Gn', 'Êx', 'Lv', 'Nm', 'Dt', 'Js', 'Jz', 'Rt', '1Sm', '2Sm',
  '1Rs', '2Rs', '1Cr', '2Cr', 'Ed', 'Ne', 'Et', 'Jó', 'Sl', 'Pv',
  'Ec', 'Ct', 'Is', 'Jr', 'Lm', 'Ez', 'Dn', 'Os', 'Jl', 'Am',
  'Ob', 'Jn', 'Mq', 'Na', 'Hc', 'Sf', 'Ag', 'Zc', 'Ml', 'Mt',
  'Mc', 'Lc', 'Jo', 'At', 'Rm', '1Co', '2Co', 'Gl', 'Ef', 'Fp',
  'Cl', '1Ts', '2Ts', '1Tm', '2Tm', 'Tt', 'Fm', 'Hb', 'Tg', '1Pe',
  '2Pe', '1Jo', '2Jo', '3Jo', 'Jd', 'Ap',
];

String abbreviationForOrder(int order) => _abbreviations[order - 1];

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

  BookCategory get category => categoryForOrder(order);
  String get abbreviation => abbreviationForOrder(order);

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
