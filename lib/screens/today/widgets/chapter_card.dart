import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/database/queries.dart';
import '../../../state/reading_plan_provider.dart';

class ChapterCard extends StatefulWidget {
  final ChapterView view;

  const ChapterCard({super.key, required this.view});

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  bool _expanded = false;
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

  Future<void> _saveNote() async {
    final provider = context.read<ReadingPlanProvider>();
    final text = _noteController.text.trim();
    if (widget.view.chapter.isRead) {
      await provider.setChapterNote(widget.view.chapter.id, text.isEmpty ? null : text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.view.chapter;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: chapter.isRead,
            onChanged: _toggle,
            title: Text(widget.view.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: chapter.note != null && chapter.note!.isNotEmpty && !_expanded
                ? Text(chapter.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            secondary: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.edit_note),
              tooltip: 'Nota',
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  hintText: 'O que chamou sua atenção nesse capítulo?',
                  border: OutlineInputBorder(),
                ),
                onEditingComplete: _saveNote,
                onTapOutside: (_) => _saveNote(),
              ),
            ),
        ],
      ),
    );
  }
}
