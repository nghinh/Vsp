// Round recap — VSP Mobile App
//
// The message that goes to the flight's Zalo, written by the server from the
// round's own rows. The card shows the paragraph and shares it with one tap;
// the numbers underneath it are already on this screen.
//
// Quiet by design when it cannot help: a round that has not synced yet, a
// server without a model, or a plain network failure all collapse the card
// to nothing rather than putting an error between a golfer and their card.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:share_plus/share_plus.dart';

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class RoundRecapApi {
  RoundRecapApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// The recap sentence for this round, or null when the server has no model
  /// configured — the facts it would repeat are already on the screen.
  Future<String?> forRound(String roundId) async {
    final json = await _apiClient.get('/rounds/$roundId/recap');
    return (json as Map<String, dynamic>)['recap'] as String?;
  }
}

class RoundRecapCard extends StatefulWidget {
  const RoundRecapCard({
    super.key,
    required this.roundId,
    required this.subject,
    this.api,
  });

  final String roundId;

  /// The share sheet's subject line — the course name.
  final String subject;

  final RoundRecapApi? api;

  @override
  State<RoundRecapCard> createState() => _RoundRecapCardState();
}

class _RoundRecapCardState extends State<RoundRecapCard> {
  late final RoundRecapApi _api = widget.api ?? RoundRecapApi();

  String? _recap;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final recap = await _api.forRound(widget.roundId);
      if (!mounted) return;
      setState(() {
        _recap = recap;
        _loading = false;
      });
    } catch (_) {
      // Not synced yet, or the server is unreachable — the summary stands on
      // its own without this card.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recap = _recap;
    if (_loading || recap == null || recap.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      key: const Key('round_recap_card'),
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: VspSpacing.xs),
                Text(l10n.recapTitle, style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(recap, style: theme.textTheme.bodyMedium),
            const SizedBox(height: VspSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('round_recap_share'),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: recap, subject: widget.subject),
                ),
                icon: const Icon(Icons.share, size: 18),
                label: Text(l10n.recapShare),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
