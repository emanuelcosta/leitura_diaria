import 'package:flutter/material.dart';

import '../data/models/book.dart';
import '../logic/bible_reference_parser.dart';

/// Renders [text] with any `@Sigla capítulo.versículo` reference (see
/// findBibleReferences) turned into a tappable inline link — used everywhere
/// a note can be shown (verse notes, doubt notes, chapter notes), so a
/// reference typed once works the same in all of them. [onReferenceTap]
/// (typically pushing ChapterReadingScreen) is supplied by the caller
/// instead of hardcoded here — this widget lives in lib/widgets/ (generic,
/// screen-agnostic) and must not import a specific lib/screens/ file, which
/// would also create an import cycle back from that screen's own note
/// display.
class ReferenceText extends StatelessWidget {
  final String text;
  final List<Book> books;
  final void Function(BuildContext context, BibleReference reference) onReferenceTap;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const ReferenceText({
    super.key,
    required this.text,
    required this.books,
    required this.onReferenceTap,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final references = findBibleReferences(text, books);
    if (references.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final linkStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final ref in references) {
      if (ref.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, ref.start)));
      }
      // WidgetSpan + GestureDetector instead of TextSpan.recognizer: a
      // TapGestureRecognizer created inline in build() would need manual
      // disposal to avoid leaking, which a plain StatelessWidget can't do
      // cleanly — GestureDetector manages its own lifecycle as a widget.
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => onReferenceTap(context, ref),
          child: Text(ref.matchedText, style: linkStyle),
        ),
      ));
      cursor = ref.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
