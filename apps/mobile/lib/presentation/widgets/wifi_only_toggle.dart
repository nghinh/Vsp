// Wi-Fi Only Toggle — VSP Mobile App
//
// Toggle switch for Wi-Fi-only download preference with current Wi-Fi status indicator.
// AC-1: Wi-Fi preference control.
//
// Design: ux-spec §5.2, §10

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../data/services/connectivity_service.dart';

/// Toggle for Wi-Fi-only download preference with live Wi-Fi status.
class WifiOnlyToggle extends StatefulWidget {
  final ConnectivityService connectivityService;

  const WifiOnlyToggle({super.key, required this.connectivityService});

  @override
  State<WifiOnlyToggle> createState() => _WifiOnlyToggleState();
}

class _WifiOnlyToggleState extends State<WifiOnlyToggle> {
  late bool _wifiOnly;
  bool _isWifiConnected = false;
  StreamSubscription<List<dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    _wifiOnly = widget.connectivityService.wifiOnlyEnabled;
    _checkWifi();
    _subscription = widget.connectivityService.onConnectivityChanged.listen((
      result,
    ) {
      final wifi = result.contains('wifi');
      if (mounted) setState(() => _isWifiConnected = wifi);
    });
  }

  Future<void> _checkWifi() async {
    final wifi = await widget.connectivityService.isWifiConnected;
    if (mounted) setState(() => _isWifiConnected = wifi);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.colorScheme.brightness;

    return Semantics(
      label:
          'Wi-Fi only download ${_wifiOnly ? "enabled" : "disabled"}. '
          'Wi-Fi ${_isWifiConnected ? "connected" : "not connected"}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: VspSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _isWifiConnected ? Icons.wifi : Icons.wifi_off,
              size: VspIconSize.md,
              color: _isWifiConnected
                  ? VspColorSemantic.of(brightness, VspSemanticColorToken.online)
                  : VspColorSemantic.of(brightness, VspSemanticColorToken.offline),
            ),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Download on Wi-Fi only',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    _isWifiConnected
                        ? 'Wi-Fi connected'
                        : 'No Wi-Fi — downloads paused',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isWifiConnected
                          ? colorScheme.onSurfaceVariant
                          : brightness == Brightness.dark
                          ? VspColorDark.destructive
                          : VspColorLight.destructive,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _wifiOnly,
              onChanged: (value) async {
                await widget.connectivityService.setWifiOnly(value);
                setState(() => _wifiOnly = value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

