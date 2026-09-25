import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/dictionary_entry.dart';
import '../../data/repositories/dictionary_repository.dart';
import '../../state/settings_provider.dart';
import '../../widgets/empty_state.dart';
import 'widgets/translatable_definition.dart';

/// English-only Bible dictionary (Easton's + Smith's, public domain — see
/// assets/dictionary/ATTRIBUTION.md). Each definition can be machine-
/// translated on demand via the "Traduzir" label (TranslatableDefinition).
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _repo = DictionaryRepository();
  final _queryController = TextEditingController();
  List<DictionaryEntry> _results = [];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final results = await _repo.search(query);
    if (!mounted) return;
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final translationLanguage = context.watch<SettingsProvider>().translationLanguage;
    return Scaffold(
      appBar: AppBar(title: const Text('Dicionário bíblico')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar termo (ex: aliança, Arão, covenant)',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _search,
                ),
                const SizedBox(height: 4),
                Text(
                  'Termos em português ou inglês; definições em inglês (Easton\'s/Smith\'s, '
                  'domínio público). Toque em "Traduzir" em cada definição pra ver em ${translationLanguage.label}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _queryController.text.trim().isEmpty
                ? const EmptyState(
                    icon: Icons.menu_book_outlined,
                    message: 'Digite um termo bíblico pra ver a definição.',
                  )
                : _results.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        message: 'Nenhum termo encontrado.',
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (context, i) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final entry = _results[i];
                          return ExpansionTile(
                            title: Text(entry.displayTerm, style: const TextStyle(fontWeight: FontWeight.w600)),
                            // Keep the English headword visible: definitions
                            // are in English and refer to it by that name.
                            subtitle: entry.termPt != null ? Text(entry.term) : null,
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final def in entry.definitions)
                                TranslatableDefinition(
                                  sourceLabel: def.source == 'EAS' ? "Easton's" : "Smith's",
                                  text: def.text,
                                  targetLanguageCode: translationLanguage.code,
                                  targetLanguageLabel: translationLanguage.label,
                                ),
                              if (entry.refs.isNotEmpty)
                                Text(
                                  'Referências: ${entry.refs.join(', ')}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
