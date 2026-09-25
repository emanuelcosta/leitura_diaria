import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/logic/remote_timestamp.dart';

void main() {
  test('local time is sent as UTC with an explicit "Z" (never offset-less)', () {
    final local = DateTime(2026, 9, 25, 16, 14);
    final sent = toRemoteTimestamp(local);
    expect(sent, endsWith('Z'));
    // Same instant once read back, whatever the machine's time zone.
    expect(DateTime.parse(sent).isAtSameMomentAs(local), isTrue);
  });

  test('a UTC time is sent unchanged', () {
    final utc = DateTime.utc(2026, 9, 25, 19, 14);
    expect(toRemoteTimestamp(utc), '2026-09-25T19:14:00.000Z');
  });

  test('round trip through the pull side (.toLocal()) keeps the local wall time', () {
    final local = DateTime(2026, 9, 25, 23, 30); // late evening: date must not roll over
    final back = DateTime.parse(toRemoteTimestamp(local)).toLocal();
    expect(back, local);
    expect(back.day, 25);
  });
}
