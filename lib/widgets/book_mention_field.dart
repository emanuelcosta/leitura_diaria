import 'package:flutter/material.dart';

import '../data/models/book.dart';
import '../logic/bible_reference_parser.dart';

/// A text field with "@Sigla" autocomplete: the "@" itself is the signal
/// that a verse reference is being typed (see the `@Sigla cap vers` syntax
/// in ReferenceText), so as soon as the user types "@" followed by letters,
/// a short list of matching books drops down below the field — matched by
/// abbreviation ("1Pe") or by the start of the full name ("1Pedro"), same
/// rule as [suggestBooksForPartialSigla]. Tapping a suggestion completes the
/// sigla and appends a trailing space so the user can continue straight
/// into the chapter number. Extracted here since it's used in every note
/// field that supports the reference syntax (verse notes, doubt notes,
/// chapter notes).
class BookMentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final List<Book> books;
  final InputDecoration? decoration;
  final int? maxLines;
  final bool autofocus;
  final VoidCallback? onEditingComplete;
  final void Function(PointerDownEvent)? onTapOutside;

  const BookMentionTextField({
    super.key,
    required this.controller,
    required this.books,
    this.decoration,
    this.maxLines = 3,
    this.autofocus = false,
    this.onEditingComplete,
    this.onTapOutside,
  });

  @override
  State<BookMentionTextField> createState() => _BookMentionTextFieldState();
}

class _BookMentionTextFieldState extends State<BookMentionTextField> {
  List<Book> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final partial = _currentMentionPartial();
    final suggestions =
        partial == null ? const <Book>[] : suggestBooksForPartialSigla(partial, widget.books);
    if (!_sameBooks(suggestions, _suggestions)) {
      setState(() => _suggestions = suggestions);
    }
  }

  bool _sameBooks(List<Book> a, List<Book> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// The text right after the closest unfinished "@" before the cursor —
  /// null if the cursor isn't currently inside a "@word" (no "@" yet, or a
  /// space/newline already closed it).
  String? _currentMentionPartial() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.start;
    if (cursor < 0 || cursor > text.length) return null;
    final at = text.lastIndexOf('@', (cursor - 1).clamp(0, text.length));
    if (at == -1 || at >= cursor) return null;
    final between = text.substring(at + 1, cursor);
    if (between.contains(' ') || between.contains('\n')) return null;
    return between;
  }

  void _applySuggestion(Book book) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.start;
    final at = text.lastIndexOf('@', (cursor - 1).clamp(0, text.length));
    if (at == -1) return;
    final replacement = '@${book.abbreviation} ';
    final newText = text.replaceRange(at, cursor, replacement);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: at + replacement.length),
    );
    setState(() => _suggestions = const []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          autofocus: widget.autofocus,
          decoration: widget.decoration,
          onEditingComplete: widget.onEditingComplete,
          onTapOutside: widget.onTapOutside,
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            // AlertDialog sizes its title/content/actions to a shared width
            // via an internal IntrinsicWidth/IntrinsicHeight, and a
            // ListView's viewport can't answer either query ("RenderViewport
            // does not support returning intrinsic dimensions") — that threw
            // mid-layout and corrupted the render tree, which is what showed
            // up as a blank/black dialog. A SizedBox only short-circuits an
            // intrinsic query for an axis where its constraint is both tight
            // (min == max) *and* finite — double.maxFinite (not
            // double.infinity, which isn't finite) is the standard way to
            // give it that tight-but-flexible width while still capping the
            // height so the list scrolls instead of overflowing the dialog.
            child: SizedBox(
              width: double.maxFinite,
              height: 160,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final book in _suggestions)
                    ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 40,
                        child: Text(
                          book.abbreviation,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(book.name),
                      onTap: () => _applySuggestion(book),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
