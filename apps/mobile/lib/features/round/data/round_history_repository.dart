// Round History Repository — VSP Mobile App
//
// Fetches the signed-in golfer's round history from the backend.
//
// Story 5.5 (reachability): GET /rounds?page&size returns a
// PageResponse<RoundResponse>. Each item is hydrated into the local
// [Round] model. Note the API does NOT include `packageVersion`, so it is
// defaulted to an empty string here (history rounds never need the
// round-start package guard).

import '../../../core/network/api_client.dart';
import '../../../domain/models/round.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// A single page of round-history results.
class RoundHistoryPage {
  final List<Round> rounds;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  const RoundHistoryPage({
    required this.rounds,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  /// True if there is a next page to load.
  bool get hasNext => !last;

  /// Parse from the API `PageResponse<RoundResponse>` envelope.
  factory RoundHistoryPage.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as List<dynamic>? ?? const [])
        .map((e) => roundFromApiJson(e as Map<String, dynamic>))
        .toList();
    return RoundHistoryPage(
      rounds: content,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? content.length,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? content.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }
}

/// Repository for retrieving the golfer's round history from the API.
class RoundHistoryRepository {
  final ApiClient _apiClient;

  RoundHistoryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch a page of rounds, most-recent first (as ordered by the backend).
  ///
  /// Throws [VspApiException] on network/parse/API errors.
  Future<RoundHistoryPage> fetchRounds({int page = 0, int size = 20}) async {
    final json = await _apiClient.get(
      '/rounds',
      queryParams: {'page': '$page', 'size': '$size'},
    );
    if (json is! Map<String, dynamic>) {
      throw const VspApiException(
        code: 'PARSE_ERROR',
        message: AppMessages.roundsResponseShape,
      );
    }
    return RoundHistoryPage.fromJson(json);
  }
}

/// Hydrate a [Round] from a `RoundResponse` API JSON object.
///
/// The API payload omits `packageVersion`, so it defaults to `''`. Status is
/// parsed tolerantly (accepts backend `IN_PROGRESS` form and enum `.name`).
Round roundFromApiJson(Map<String, dynamic> json) {
  final createdAt = _parseDate(json['createdAt']) ?? DateTime.now();
  final startedAt = _parseDate(json['startedAt']) ?? createdAt;
  return Round(
    id: json['id'] as String,
    courseId: (json['courseId'] as num?)?.toInt() ?? 0,
    // The second đường of a paired round, so resuming from the history list
    // knows where holes 10 to 18 are. Null from a server that does not send
    // it, which behaves as before rather than guessing.
    backNineCourseId: (json['backNineCourseId'] as num?)?.toInt(),
    courseName: (json['courseName'] as String?)?.trim().isNotEmpty == true
        ? json['courseName'] as String
        : 'Sân chưa xác định',
    status: _parseStatus(json['status']),
    startedAt: startedAt,
    endedAt: _parseDate(json['endedAt']),
    // API does not include packageVersion — default for history rounds.
    packageVersion: '',
    tournamentPolicyId: json['tournamentPolicyId'] as String?,
    tournamentId: json['tournamentId'] as String?,
    tournamentPolicyVersion: (json['tournamentPolicyVersion'] as num?)?.toInt(),
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

RoundStatus _parseStatus(dynamic value) {
  if (value is! String) {
    return RoundStatus.inProgress;
  }
  final normalized = value.replaceAll('_', '').toLowerCase();
  for (final status in RoundStatus.values) {
    if (status.name.toLowerCase() == normalized) {
      return status;
    }
  }
  return RoundStatus.inProgress;
}
