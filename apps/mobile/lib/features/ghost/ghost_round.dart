// Ghost round — VSP Mobile App
//
// The opponent every golfer actually wants: themselves, on their best day on
// this course. The server names the round; this banner lays it beside the
// holes scored so far and says who is ahead.
//
// The comparison is hole-for-hole, not total-so-far against total-at-end: a
// golfer through seven holes races the ghost's first seven, so the answer is
// live from the second hole of the round.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class GhostRound {
  const GhostRound({
    required this.playedOn,
    required this.totalStrokes,
    required this.strokesByHole,
  });

  final DateTime playedOn;
  final int totalStrokes;

  /// Strokes per hole number, 1-based as the golfer played them.
  final Map<int, int> strokesByHole;

  factory GhostRound.fromJson(Map<String, dynamic> json) => GhostRound(
    playedOn:
        DateTime.tryParse(json['playedOn'] as String? ?? '') ?? DateTime(0),
    totalStrokes: json['totalStrokes'] as int? ?? 0,
    strokesByHole: {
      for (final h in json['holes'] as List<dynamic>? ?? [])
        (h as Map<String, dynamic>)['holeNumber'] as int:
            h['strokes'] as int? ?? 0,
    },
  );
}

class GhostApi {
  GhostApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// The best completed round on this pairing, or null when there is none —
  /// a first round on a course has no ghost.
  Future<GhostRound?> forCourse({
    required int courseId,
    int? backNineCourseId,
  }) async {
    final json = await _apiClient.get(
      '/courses/$courseId/ghost',
      queryParams: {
        if (backNineCourseId != null)
          'backNineCourseId': '$backNineCourseId',
      },
    );
    // 204 comes through as no body.
    if (json is! Map<String, dynamic> || json.isEmpty) return null;
    return GhostRound.fromJson(json);
  }
}

class GhostBanner extends StatefulWidget {
  const GhostBanner({
    super.key,
    required this.courseId,
    this.backNineCourseId,
    required this.grossByHole,
    this.api,
  });

  final int courseId;
  final int? backNineCourseId;

  /// This golfer's strokes so far, by hole number.
  final Map<int, int> grossByHole;

  final GhostApi? api;

  @override
  State<GhostBanner> createState() => _GhostBannerState();
}

class _GhostBannerState extends State<GhostBanner> {
  late final GhostApi _api = widget.api ?? GhostApi();

  GhostRound? _ghost;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ghost = await _api.forCourse(
        courseId: widget.courseId,
        backNineCourseId: widget.backNineCourseId,
      );
      if (!mounted) return;
      setState(() {
        _ghost = ghost;
        _loading = false;
      });
    } catch (_) {
      // Offline, or the round's course is not on the server — the scorecard
      // stands on its own.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ghost = _ghost;
    if (_loading || ghost == null) {
      return const SizedBox.shrink();
    }
    // Race the ghost over the holes actually scored, on both cards.
    var mine = 0;
    var theirs = 0;
    var holes = 0;
    widget.grossByHole.forEach((hole, gross) {
      final ghostStrokes = ghost.strokesByHole[hole];
      if (ghostStrokes != null && gross > 0) {
        mine += gross;
        theirs += ghostStrokes;
        holes++;
      }
    });
    if (holes == 0) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final diff = mine - theirs;
    final text = diff < 0
        ? l10n.ghostAhead(-diff, holes)
        : diff > 0
            ? l10n.ghostBehind(diff, holes)
            : l10n.ghostEven(holes);
    final color = diff < 0
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      key: const Key('ghost_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: VspSpacing.xs,
      ),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('👻', style: theme.textTheme.bodyMedium),
          const SizedBox(width: VspSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            l10n.ghostBest(ghost.totalStrokes),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
