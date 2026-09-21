import 'dart:convert';

import 'package:http/http.dart' as http;

/// Target languages offered in Settings for "Traduzir" buttons (dictionary
/// definitions today). Portuguese is the default since the app itself is
/// in Portuguese.
enum TranslationLanguage {
  pt('pt', 'Português'),
  en('en', 'English'),
  es('es', 'Español');

  final String code;
  final String label;
  const TranslationLanguage(this.code, this.label);
}

class TranslationException implements Exception {
  final String message;
  const TranslationException(this.message);

  @override
  String toString() => message;
}

/// Best-effort machine translation via Google Translate's public web
/// endpoint — the same one translate.google.com's own page calls, not the
/// paid Cloud Translation API. No API key needed, but it's unofficial:
/// undocumented, unrate-limited by contract (Google can throttle or block
/// it any time), and not something to depend on for anything critical. Used
/// only to translate dictionary definitions on demand; the app works fully
/// without it if the request fails.
class TranslationService {
  static const _endpoint = 'https://translate.googleapis.com/translate_a/single';

  Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'client': 'gtx',
      'sl': sourceLanguage,
      'tl': targetLanguage,
      'dt': 't',
      'q': text,
    });
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const TranslationException('Sem conexão ou o serviço de tradução não respondeu.');
    }
    if (response.statusCode != 200) {
      throw TranslationException('Tradução indisponível agora (HTTP ${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    final segments = (decoded[0] as List<dynamic>?) ?? const [];
    final buffer = StringBuffer();
    for (final segment in segments) {
      final chunk = (segment as List<dynamic>)[0];
      if (chunk is String) buffer.write(chunk);
    }
    return buffer.toString();
  }
}
