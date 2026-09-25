import 'package:flutter/material.dart';

import '../../../data/repositories/bible_text_repository.dart';
import '../../../logic/bible_reference_parser.dart';

/// Shown when the whole query is a reference ("joão 3 16", "Sl 23"): the
/// verse text right there, and one tap to open it in the chapter.
class ReferenceResultCard extends StatelessWidget {
  final BibleReference reference;
  final BibleTranslation translation;
  final VoidCallback onOpen;

  const ReferenceResultCard({
    super.key,
    required this.reference,
    required this.translation,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verse = reference.verseNumber;
    final title = verse == null
        ? '${reference.book.name} ${reference.chapterNumber}'
        : '${reference.book.name} ${reference.chapterNumber}:$verse';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: theme.colorScheme.onPrimaryContainer),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<String>>(
                // Keyed so a new reference/translation refetches instead of
                // briefly showing the previous verse.
                key: ValueKey('${reference.book.order}-${reference.chapterNumber}-${translation.name}'),
                future: BibleTextRepository().getChapterVerses(
                  translation: translation,
                  bookOrder: reference.book.order,
                  chapterNumber: reference.chapterNumber,
                ),
                builder: (context, snapshot) {
                  final verses = snapshot.data;
                  if (verses == null) return const LinearProgressIndicator();
                  final preview = verse == null
                      ? verses.first
                      : (verse <= verses.length ? verses[verse - 1] : null);
                  return Text(
                    preview ?? 'Este capítulo tem ${verses.length} versículos.',
                    maxLines: verse == null ? 3 : null,
                    overflow: verse == null ? TextOverflow.ellipsis : null,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                verse == null ? 'Toque para ler o capítulo' : 'Toque para ler no capítulo',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
