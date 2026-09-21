import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/database/queries.dart';
import '../../../state/reading_plan_provider.dart';

class NoteTile extends StatelessWidget {
  final ChapterView view;
  final VoidCallback onChanged;

  const NoteTile({super.key, required this.view, required this.onChanged});

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: view.chapter.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(view.label),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await context.read<ReadingPlanProvider>().setChapterNote(
            view.chapter.id,
            result.isEmpty ? null : result,
          );
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final readAt = view.chapter.readAt;
    return ListTile(
      title: Text(view.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(view.chapter.note ?? ''),
      trailing: readAt != null ? Text(DateFormat('dd/MM/yy').format(readAt)) : null,
      onTap: () => _edit(context),
    );
  }
}
