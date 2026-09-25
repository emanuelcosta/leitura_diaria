import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/bible_text_repository.dart';
import '../../../logic/bible_reference_parser.dart';
import '../../../state/settings_provider.dart';

/// Preview of a reference tapped inside a note: shows the verse (or the
/// whole chapter, for a chapter-only reference like "Jo 3") without leaving
/// the current screen. "Ver texto completo" hands off to [onOpenFullText],
/// which opens the chapter with the verse selected and scrolled into view.
Future<void> showBibleReferenceSheet(
  BuildContext context,
  BibleReference reference, {
  required VoidCallback onOpenFullText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => BibleReferenceSheet(
      reference: reference,
      onOpenFullText: () {
        Navigator.of(sheetContext).pop();
        onOpenFullText();
      },
    ),
  );
}

class BibleReferenceSheet extends StatefulWidget {
  final BibleReference reference;
  final VoidCallback onOpenFullText;

  const BibleReferenceSheet({super.key, required this.reference, required this.onOpenFullText});

  @override
  State<BibleReferenceSheet> createState() => _BibleReferenceSheetState();
}

class _BibleReferenceSheetState extends State<BibleReferenceSheet> {
  final _bibleRepo = BibleTextRepository();
  late final Future<List<String>> _verses;

  @override
  void initState() {
    super.initState();
    _verses = _bibleRepo.getChapterVerses(
      translation: context.read<SettingsProvider>().translation,
      bookOrder: widget.reference.book.order,
      chapterNumber: widget.reference.chapterNumber,
    );
  }

  String get _title {
    final r = widget.reference;
    final verse = r.verseNumber;
    return verse == null ? '${r.book.name} ${r.chapterNumber}' : '${r.book.name} ${r.chapterNumber}:$verse';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyLarge?.copyWith(
      height: 1.5,
      fontSize: (textTheme.bodyLarge?.fontSize ?? 16) * settings.fontScale,
    );

    return SafeArea(
      child: ConstrainedBox(
        // Chapter-only references can be long (Salmo 119): cap the sheet and
        // let the text scroll instead of covering the whole screen.
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_title, style: textTheme.titleLarge),
              Text(
                settings.translation.abbreviation,
                style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: FutureBuilder<List<String>>(
                  future: _verses,
                  builder: (context, snapshot) {
                    final verses = snapshot.data;
                    if (verses == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return SingleChildScrollView(child: _buildText(verses, bodyStyle));
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onOpenFullText,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Ver texto completo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildText(List<String> verses, TextStyle? style) {
    final verseNumber = widget.reference.verseNumber;
    if (verseNumber == null) {
      // Chapter-only reference: the whole chapter, verse numbers inline.
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            for (var i = 0; i < verses.length; i++) ...[
              TextSpan(
                text: '${i + 1} ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              TextSpan(text: '${verses[i]} '),
            ],
          ],
        ),
      );
    }
    // The parser only validates the chapter against the book, not the verse
    // against the chapter, so "Jo 3.99" can get here.
    if (verseNumber < 1 || verseNumber > verses.length) {
      return Text(
        'Este capítulo tem ${verses.length} versículos — o versículo $verseNumber não existe.',
        style: style,
      );
    }
    return Text(verses[verseNumber - 1], style: style);
  }
}
