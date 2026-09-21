import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database/queries.dart';
import '../state/reading_plan_provider.dart';
import '../screens/reading/chapter_reading_screen.dart';
import 'book_mention_field.dart';
import 'reference_text.dart';

/// One chapter's read-toggle + note editor — used both in the Início tab
/// (today's plan reading) and in a single book's chapter list (Livros >
/// book), which is why it lives in lib/widgets/ rather than a feature
/// folder.
class ChapterCard extends StatefulWidget {
  final ChapterView view;

  const ChapterCard({super.key, required this.view});

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  bool _expanded = false;
  bool _savingNote = false;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.view.chapter.note ?? '');
  }

  @override
  void didUpdateWidget(covariant ChapterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.chapter.id != widget.view.chapter.id) {
      _noteController.text = widget.view.chapter.note ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool? checked) async {
    final provider = context.read<ReadingPlanProvider>();
    final isRead = checked ?? false;
    if (isRead) {
      setState(() => _expanded = true);
    }
    await provider.setChapterRead(
      widget.view.chapter.id,
      isRead: isRead,
      note: isRead ? (_noteController.text.trim().isEmpty ? null : _noteController.text.trim()) : null,
    );
  }

  /// Notes can be saved regardless of read state — jotting something down
  /// while still partway through a chapter shouldn't require finishing it
  /// first. The "Salvando..." state on the button reflects any save in
  /// progress (button tap or blur auto-save); the confirmation SnackBar is
  /// limited to explicit taps ([showFeedback]) so it doesn't pop up on
  /// every blur.
  Future<void> _saveNote({bool showFeedback = false}) async {
    if (_savingNote) return;
    final provider = context.read<ReadingPlanProvider>();
    final text = _noteController.text.trim();
    setState(() => _savingNote = true);
    try {
      await provider.setChapterNote(widget.view.chapter.id, text.isEmpty ? null : text);
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota salva.'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.view.chapter;
    final books = context.watch<ReadingPlanProvider>().meta.books;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Only this checkbox toggles read state — tapping the title
              // below opens the chapter text instead (a plain ListTile/
              // CheckboxListTile would toggle on either tap, which isn't
              // what's wanted here).
              Checkbox(value: chapter.isRead, onChanged: _toggle),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChapterReadingScreen(
                        bookId: chapter.bookId,
                        bookOrder: widget.view.bookOrder,
                        bookName: widget.view.bookName,
                        chapterNumber: chapter.chapterNumber,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.view.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (chapter.note != null && chapter.note!.isNotEmpty && !_expanded)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: ReferenceText(
                              text: chapter.note!,
                              books: books,
                              onReferenceTap: openBibleReference,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.edit_note),
                tooltip: 'Nota',
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BookMentionTextField(
                    controller: _noteController,
                    books: books,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      hintText: 'O que chamou sua atenção nesse capítulo?',
                      helperText: 'Dica: @Sigla cap vers linka outro texto (ex: @Jo 3 16)',
                      border: OutlineInputBorder(),
                    ),
                    onEditingComplete: () => _saveNote(),
                    onTapOutside: (_) => _saveNote(),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _savingNote ? null : () => _saveNote(showFeedback: true),
                    icon: _savingNote
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_savingNote ? 'Salvando...' : 'Salvar nota'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
