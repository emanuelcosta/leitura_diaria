import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';

import '../data/models/book.dart';
import '../logic/bible_reference_parser.dart';
import 'book_mention_field.dart';
import 'confirm_dialog.dart';
import 'reference_text.dart';

/// Opens one note (verse note, doubt or chapter note) in a bottom sheet:
/// the verse on top, the comment right below it — same order as in the
/// reading screen — with Editar / Excluir / Abrir no capítulo.
///
/// Presentational only: the caller wires [onSave]/[onDelete] to its
/// provider, so the same sheet serves every kind of note.
Future<void> showNoteSheet(
  BuildContext context, {
  required String title,
  required NoteKind kind,
  required List<Book> books,
  required void Function(BuildContext, BibleReference) onReferenceTap,
  required Future<void> Function(String text) onSave,
  String initialText = '',
  Future<String?>? verseText,
  DateTime? date,
  bool startEditing = false,
  bool closeOnSave = false,
  String? saveLabel,
  Future<void> Function()? onDelete,
  VoidCallback? onOpenChapter,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => NoteSheet(
      title: title,
      kind: kind,
      books: books,
      onReferenceTap: onReferenceTap,
      onSave: onSave,
      initialText: initialText,
      verseText: verseText,
      date: date,
      startEditing: startEditing,
      closeOnSave: closeOnSave,
      saveLabel: saveLabel,
      onDelete: onDelete,
      onOpenChapter: onOpenChapter,
    ),
  );
}

/// What the note is — drives the label, icon, color and wording.
enum NoteKind {
  verse('Nota', Icons.note_outlined, 'O que chamou sua atenção nesse versículo?', 'Excluir nota'),
  doubt('Dúvida', Icons.help_outline, 'O que você não entendeu? (opcional, ajuda a lembrar depois)',
      'Remover dúvida'),
  chapter('Nota do capítulo', Icons.sticky_note_2_outlined, 'O que ficou desse capítulo?', 'Excluir nota');

  final String label;
  final IconData icon;
  final String hint;
  final String deleteLabel;
  const NoteKind(this.label, this.icon, this.hint, this.deleteLabel);

  /// Doubts keep the reading screen's purple so they read as the same thing.
  Color accent(ColorScheme scheme) => this == NoteKind.doubt ? Colors.deepPurple : scheme.primary;
}

class NoteSheet extends StatefulWidget {
  final String title;
  final NoteKind kind;
  final List<Book> books;
  final void Function(BuildContext, BibleReference) onReferenceTap;
  final Future<void> Function(String text) onSave;
  final String initialText;
  final Future<String?>? verseText;
  final DateTime? date;
  final bool startEditing;

  /// Close right after saving (quick add/edit while reading) instead of
  /// going back to the read view.
  final bool closeOnSave;

  /// Defaults to "Salvar" (e.g. "Marcar dúvida" when creating a doubt).
  final String? saveLabel;
  final Future<void> Function()? onDelete;
  final VoidCallback? onOpenChapter;

  const NoteSheet({
    super.key,
    required this.title,
    required this.kind,
    required this.books,
    required this.onReferenceTap,
    required this.onSave,
    this.initialText = '',
    this.verseText,
    this.date,
    this.startEditing = false,
    this.closeOnSave = false,
    this.saveLabel,
    this.onDelete,
    this.onOpenChapter,
  });

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  late String _text = widget.initialText;
  late bool _editing = widget.startEditing;
  late final _controller = TextEditingController(text: widget.initialText);
  bool _saving = false;
  String? _verse; // kept for "Copiar" once the verse text has loaded

  @override
  void initState() {
    super.initState();
    widget.verseText?.then((v) {
      if (mounted) setState(() => _verse = v);
    });
  }

  /// Reference + verse + comment, ready to paste into a message.
  Future<void> _copy() async {
    final parts = [
      widget.title,
      if (_verse != null) '"$_verse"',
      if (_text.isNotEmpty) '${widget.kind.label}: $_text',
    ];
    await Clipboard.setData(ClipboardData(text: parts.join('\n\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final text = _controller.text.trim();
    await widget.onSave(text);
    if (!mounted) return;
    // An empty verse/chapter note is deleted by its provider — nothing left
    // to show. (An empty doubt is still a doubt, just without a comment.)
    final gone = text.isEmpty && widget.kind != NoteKind.doubt;
    if (widget.closeOnSave || gone) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _text = text;
      _editing = false;
      _saving = false;
    });
  }

  void _cancel() {
    // Opened straight into the editor (from the reading screen): cancelling
    // means "never mind", not "go to the read view".
    if (widget.startEditing) {
      Navigator.of(context).pop();
      return;
    }
    _controller.text = _text;
    setState(() => _editing = false);
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: widget.kind.deleteLabel,
      message: widget.kind == NoteKind.doubt
          ? 'O versículo sai da lista de dúvidas, junto com a anotação.'
          : 'A anotação será apagada deste e dos outros aparelhos sincronizados.',
      confirmLabel: widget.kind == NoteKind.doubt ? 'Remover' : 'Excluir',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await widget.onDelete!();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.kind.accent(theme.colorScheme);
    final date = widget.date;

    return Padding(
      // Keeps the editor and its buttons above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(widget.kind.icon, size: 18, color: accent),
                    const SizedBox(width: 6),
                    Text(widget.kind.label, style: theme.textTheme.labelLarge?.copyWith(color: accent)),
                    const Spacer(),
                    if (date != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(date),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(widget.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Flexible(
                  // SelectionArea: long-press to select and copy any part of
                  // the verse or the comment, not only the whole thing.
                  child: SelectionArea(
                    child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.verseText != null) _buildVerse(theme),
                        _editing ? _buildEditor() : _buildNote(theme, accent),
                      ],
                    ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _editing ? _buildEditActions() : _buildViewActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerse(ThemeData theme) {
    return FutureBuilder<String?>(
      future: widget.verseText,
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
        );
      },
    );
  }

  /// The comment, shown below the verse with an accent bar — the same
  /// "comment under the verse" look as the reading screen.
  Widget _buildNote(ThemeData theme, Color accent) {
    if (_text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sem anotação.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
      child: ReferenceText(
        text: _text,
        books: widget.books,
        onReferenceTap: widget.onReferenceTap,
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.5,
          fontStyle: widget.kind == NoteKind.doubt ? FontStyle.italic : null,
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return BookMentionTextField(
      controller: _controller,
      books: widget.books,
      minLines: 6,
      maxLines: null,
      autofocus: true,
      decoration: InputDecoration(
        hintText: widget.kind.hint,
        helperText: 'Dica: @Sigla cap vers linka outro texto (ex: @Jo 3 16)',
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildViewActions() {
    return Row(
      children: [
        if (widget.onOpenChapter != null)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenChapter!();
            },
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Abrir no capítulo'),
          ),
        const Spacer(),
        IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: _copy),
        if (widget.onDelete != null)
          IconButton(
            tooltip: widget.kind.deleteLabel,
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            onPressed: _delete,
          ),
        const SizedBox(width: 4),
        FilledButton.tonalIcon(
          onPressed: () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(_text.isEmpty ? 'Escrever' : 'Editar'),
        ),
      ],
    );
  }

  Widget _buildEditActions() {
    return Row(
      children: [
        // While creating/editing from the reading screen there's no read
        // view to delete from, so the destructive action lives here too.
        if (widget.startEditing && widget.onDelete != null)
          TextButton(
            onPressed: _saving ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(widget.kind.deleteLabel),
          ),
        const Spacer(),
        TextButton(onPressed: _saving ? null : _cancel, child: const Text('Cancelar')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.saveLabel ?? 'Salvar'),
        ),
      ],
    );
  }
}
