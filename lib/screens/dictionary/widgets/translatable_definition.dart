import 'package:flutter/material.dart';

import '../../../services/translation_service.dart';

/// One dictionary definition, with a "Traduzir" label below it that fetches
/// a best-effort translation on demand (see TranslationService — unofficial
/// Google Translate endpoint, no API key, can fail).
class TranslatableDefinition extends StatefulWidget {
  final String sourceLabel;
  final String text;
  final String targetLanguageCode;
  final String targetLanguageLabel;

  const TranslatableDefinition({
    super.key,
    required this.sourceLabel,
    required this.text,
    required this.targetLanguageCode,
    required this.targetLanguageLabel,
  });

  @override
  State<TranslatableDefinition> createState() => _TranslatableDefinitionState();
}

class _TranslatableDefinitionState extends State<TranslatableDefinition> {
  final _translationService = TranslationService();
  bool _loading = false;
  String? _translated;
  String? _error;

  Future<void> _translate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _translationService.translate(
        text: widget.text,
        targetLanguage: widget.targetLanguageCode,
      );
      if (!mounted) return;
      setState(() => _translated = result);
    } on TranslationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.sourceLabel,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 2),
          Text(widget.text),
          const SizedBox(height: 4),
          if (_translated != null) ...[
            Text(
              _translated!,
              style: TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.primary),
            ),
            Text(
              'Traduzido por Google Tradutor (não oficial) — pode conter erros.',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ] else if (_loading)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                const Text('Traduzindo...'),
              ],
            )
          else ...[
            InkWell(
              onTap: _translate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Traduzir para ${widget.targetLanguageLabel}',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ],
      ),
    );
  }
}
