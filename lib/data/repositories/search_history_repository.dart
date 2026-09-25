import 'package:shared_preferences/shared_preferences.dart';

/// Recent searches from the Buscar tab, newest first, kept on this device
/// only (not synced — it's a convenience, not user data worth a table).
class SearchHistoryRepository {
  static const _key = 'recent_verse_searches';
  static const maxEntries = 8;

  Future<List<String>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  /// Moves [query] to the top (no duplicates, case-insensitive) and trims
  /// the list to [maxEntries]. Returns the updated list.
  Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    final current = await getRecent();
    if (trimmed.isEmpty) return current;
    final updated = [
      trimmed,
      ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ].take(maxEntries).toList();
    await _save(updated);
    return updated;
  }

  Future<List<String>> remove(String query) async {
    final updated = (await getRecent()).where((q) => q != query).toList();
    await _save(updated);
    return updated;
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> queries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, queries);
  }
}
