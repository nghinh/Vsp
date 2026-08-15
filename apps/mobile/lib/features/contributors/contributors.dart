// Contributors — VSP Mobile App
//
// Every stroke index in this app arrived because somebody photographed a card
// in a clubhouse and typed it in. No open dataset carries them. The people who
// did that work are why stroke allocation, net scoring and the games engine
// exist at all — and until now nothing anywhere said their names.
//
// Two places: a line on the course they filled in, and a board of everyone.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class Contributor {
  const Contributor({
    required this.displayName,
    required this.approvedCorrections,
    required this.coursesCovered,
  });

  final String displayName;
  final int approvedCorrections;
  final int coursesCovered;

  factory Contributor.fromJson(Map<String, dynamic> json) => Contributor(
    displayName: json['displayName'] as String? ?? '',
    approvedCorrections: json['approvedCorrections'] as int? ?? 0,
    coursesCovered: json['coursesCovered'] as int? ?? 0,
  );
}

class ContributorApi {
  ContributorApi({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Contributor>> leaderboard() => _get('/contributors');

  Future<List<Contributor>> forCourse(int courseId) =>
      _get('/courses/$courseId/contributors');

  Future<List<Contributor>> _get(String path) async {
    final json = await _apiClient.get(path);
    return (json as List<dynamic>)
        .map((e) => Contributor.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// The credit line on a course: who filled this one in.
///
/// Absent rather than empty where nobody has — most courses came from the
/// import, and "đóng góp bởi: không ai" is worse than silence.
class CourseCreditLine extends StatefulWidget {
  const CourseCreditLine({super.key, required this.courseId, this.api});

  final int courseId;
  final ContributorApi? api;

  @override
  State<CourseCreditLine> createState() => _CourseCreditLineState();
}

class _CourseCreditLineState extends State<CourseCreditLine> {
  late final ContributorApi _api = widget.api ?? ContributorApi();
  List<Contributor> _contributors = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _api.forCourse(widget.courseId);
      if (!mounted) return;
      setState(() => _contributors = list);
    } catch (_) {
      // Offline: the course page does not need this to be useful.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_contributors.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = _contributors.map((c) => c.displayName).take(3).join(', ');

    return Padding(
      key: const Key('course_credit_line'),
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: VspSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.volunteer_activism_outlined,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: VspSpacing.xs),
          Expanded(
            child: Text(
              l10n.contributorCredit(names),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            key: const Key('course_credit_all'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContributorsScreen()),
            ),
            child: Text(l10n.contributorAll),
          ),
        ],
      ),
    );
  }
}

class ContributorsScreen extends StatefulWidget {
  const ContributorsScreen({super.key, this.api});

  final ContributorApi? api;

  @override
  State<ContributorsScreen> createState() => _ContributorsScreenState();
}

class _ContributorsScreenState extends State<ContributorsScreen> {
  late final ContributorApi _api = widget.api ?? ContributorApi();
  List<Contributor>? _board;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final board = await _api.leaderboard();
      if (!mounted) return;
      setState(() => _board = board);
    } catch (_) {
      if (!mounted) return;
      setState(() => _board = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final board = _board;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contributorTitle)),
      body: board == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(VspSpacing.md),
              children: [
                Text(l10n.contributorIntro, style: theme.textTheme.bodyMedium),
                const SizedBox(height: VspSpacing.md),
                if (board.isEmpty)
                  Text(l10n.contributorEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))
                else
                  for (var i = 0; i < board.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: i < 3
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontFamily: 'Fira Code', fontSize: 13)),
                      ),
                      title: Text(board[i].displayName),
                      subtitle: Text(l10n.contributorCounts(
                        board[i].approvedCorrections,
                        board[i].coursesCovered,
                      )),
                    ),
              ],
            ),
    );
  }
}
