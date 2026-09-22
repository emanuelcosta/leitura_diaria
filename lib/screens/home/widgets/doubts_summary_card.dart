import 'package:flutter/material.dart';

import '../../doubts/doubts_screen.dart';

/// Prompts the user back to verses they marked "tenho dúvida" (pending to
/// research/understand). Only shown when there's at least one — an empty
/// state here would just be dashboard noise.
class DoubtsSummaryCard extends StatelessWidget {
  final int count;

  const DoubtsSummaryCard({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.deepPurple.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(Icons.help_outline, color: Colors.deepPurple[400]),
        title: Text(
          count == 1 ? '1 versículo pendente pra pesquisar' : '$count versículos pendentes pra pesquisar',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Versículos marcados como dúvida'),
        trailing: const Icon(Icons.chevron_right),
        // DoubtsScreen has no Scaffold of its own (it's normally a tab inside
        // NotesScreen) — wrap it here since this pushes it standalone.
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Dúvidas pendentes')),
              body: const DoubtsScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
