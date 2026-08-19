// Wi-Fi Only Toggle — VSP Mobile App
//
// Toggle switch for Wi-Fi-only download preference with current Wi-Fi status indicator.
// AC-1: Wi-Fi preference control.
//
// Design: ux-spec §5.2, §10

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';
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
      label: AppLocalizations.of(context).wifiOnlySemantics(
        _wifiOnly
            ? AppLocalizations.of(context).wifiOnlyEnabled
            : AppLocalizations.of(context).wifiOnlyDisabled,
        _isWifiConnected
            ? AppLocalizations.of(context).wifiStatusConnected
            : AppLocalizations.of(context).wifiStatusNotConnected,
      ),
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
                  ? VspColorSemantic.of(
                      brightness,
                      VspSemanticColorToken.online,
                    )
                  : VspColorSemantic.of(
                      brightness,
                      VspSemanticColorToken.offline,
                    ),
            ),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).wifiOnlyTitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  // What this means for the download, which depends on the
                  // switch as much as on the network.
                  //
                  // This line used to be chosen from `_isWifiConnected` alone,
                  // so a golfer who had turned the restriction *off* was still
                  // told, in destructive red, "Không có Wi-Fi — tạm dừng tải".
                  // Nothing was paused: they had just said they did not mind
                  // mobile data. The screen was telling them to go and find
                  // Wi-Fi on the one screen where they were trying to
                  // download, and the app's own words for the neutral case —
                  // "Chưa kết nối Wi-Fi" — were sitting unused in the
                  // translations.
                  //
                  // Found by the screen-by-screen sweep on a simulator, which
                  // reports no Wi-Fi and made the contradiction plain.
                  Text(
                    _wifiOnly
                        ? (_isWifiConnected
                            ? AppLocalizations.of(context).wifiConnected
                            : AppLocalizations.of(context).wifiNotConnected)
                        : (_isWifiConnected
                            ? AppLocalizations.of(context).wifiStatusConnected
                            : AppLocalizations.of(context)
                                .wifiStatusNotConnected),
                    style: theme.textTheme.bodySmall?.copyWith(
                      // Red only when it actually stops something.
                      color: (_wifiOnly && !_isWifiConnected)
                          ? (brightness == Brightness.dark
                              ? VspColorDark.destructive
                              : VspColorLight.destructive)
                          : colorScheme.onSurfaceVariant,
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
