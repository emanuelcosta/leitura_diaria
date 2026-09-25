/// Formats a timestamp for a Supabase `timestamptz` column.
///
/// `DateTime.now().toIso8601String()` has no offset ("2026-09-25T16:14:16"),
/// and Postgres reads an offset-less value as UTC — so every device outside
/// UTC stored its *local* wall time as if it were UTC (3 h in the past for
/// Brazil). That broke every newest-wins comparison across devices: the
/// reading bookmark on another device looked 3 h older than it was and got
/// overwritten instead of adopted. Converting to UTC first yields a "Z"
/// suffix, which Postgres stores as the correct instant.
String toRemoteTimestamp(DateTime time) => time.toUtc().toIso8601String();
