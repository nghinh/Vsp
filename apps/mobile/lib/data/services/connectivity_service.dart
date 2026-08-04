// Connectivity Service — VSP Mobile App
//
// Monitors network connectivity type (Wi-Fi vs cellular) and enforces
// Wi-Fi-only download policy per Story 4.3 AC-1.
//
// Uses connectivity_plus package for network type detection.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connectivity monitoring service.
///
/// Tracks Wi-Fi vs cellular connectivity and persists Wi-Fi-only preference.
/// Used by CoursePackageDownloadService to determine whether to start/continue
/// a download.
class ConnectivityService {
  static const String _wifiOnlyKey = 'download_wifi_only';

  final Connectivity _connectivity;
  final SharedPreferences _prefs;

  /// Stream controller for connectivity change events.
  StreamController<List<ConnectivityResult>>? _controller;

  ConnectivityService({
    Connectivity? connectivity,
    required SharedPreferences prefs,
  }) : _connectivity = connectivity ?? Connectivity(),
       _prefs = prefs;

  /// Whether Wi-Fi-only downloads are enabled.
  bool get wifiOnlyEnabled => _prefs.getBool(_wifiOnlyKey) ?? false;

  /// Set Wi-Fi-only download preference.
  Future<void> setWifiOnly(bool value) async {
    await _prefs.setBool(_wifiOnlyKey, value);
  }

  /// Stream of connectivity results. Emits whenever the connection type changes.
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    _controller ??= StreamController<List<ConnectivityResult>>.broadcast(
      onListen: () {
        _connectivity.onConnectivityChanged.listen((result) {
          _controller?.add(result);
        });
      },
    );
    return _controller!.stream;
  }

  /// Returns true if Wi-Fi is currently connected.
  Future<bool> get isWifiConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Returns true if any network is connected (Wi-Fi or cellular).
  Future<bool> get isNetworkConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Whether a download should proceed given current connectivity and preference.
  ///
  /// Returns true if:
  /// - Wi-Fi is connected, OR
  /// - Wi-Fi-only mode is disabled and any network is connected.
  Future<bool> get shouldDownload async {
    final wifiConnected = await isWifiConnected;
    if (wifiConnected) return true;
    if (!wifiOnlyEnabled) {
      final connected = await isNetworkConnected;
      return connected;
    }
    return false;
  }

  /// Get current connectivity results.
  Future<List<ConnectivityResult>> checkConnectivity() {
    return _connectivity.checkConnectivity();
  }

  /// Dispose of resources.
  void dispose() {
    _controller?.close();
    _controller = null;
  }
}
