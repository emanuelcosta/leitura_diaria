import 'package:connectivity_plus/connectivity_plus.dart';

/// Network state for background sync. Only knows a network interface came
/// up, not that the internet (or Supabase) is reachable — callers must
/// tolerate a sync that still fails.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  /// Fires once each time the device goes from no network to some network,
  /// so work queued while offline (deletions in sync_tombstones, pushes that
  /// failed) is sent as soon as it can be.
  Stream<void> get onReconnected async* {
    var offline = _isOffline(await _connectivity.checkConnectivity());
    await for (final results in _connectivity.onConnectivityChanged) {
      final nowOffline = _isOffline(results);
      if (offline && !nowOffline) yield null;
      offline = nowOffline;
    }
  }

  static bool _isOffline(List<ConnectivityResult> results) =>
      results.every((r) => r == ConnectivityResult.none);
}
