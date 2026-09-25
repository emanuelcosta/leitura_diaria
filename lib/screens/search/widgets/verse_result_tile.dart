import 'package:flutter/material.dart';

import '../../../data/models/verse_search_result.dart';
import '../../../logic/text_normalize.dart';
import '../../../logic/verse_query.dart';

/// One verse in the results: reference on top, the full verse below with the
/// matched words bolded, so the user can tell at a glance why it matched
/// without opening it.
class VerseResultTile extends StatelessWidget {
  final VerseSearchResult result;
  final CompiledSearch query;
  final VoidCallback onTap;

  const VerseResultTile({super.key, required this.result, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = TextStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: theme.colorScheme.primaryContainer,
      color: theme.colorScheme.onPrimaryContainer,
    );
    final text = result.text;
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final (start, end) in query.highlightRanges(normalizeForSearch(text))) {
      if (start > cursor) spans.add(TextSpan(text: text.substring(cursor, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: highlight));
      cursor = end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.bookName} ${result.chapterNumber}:${result.verseNumber}',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text.rich(TextSpan(style: theme.textTheme.bodyMedium?.copyWith(height: 1.4), children: spans)),
          ],
        ),
      ),
    );
  }
}
