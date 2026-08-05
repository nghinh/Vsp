// Privacy Request DTOs — VSP Mobile App
//
// Data transfer objects for privacy request endpoints (/privacy/*).
// Matches the OpenAPI contract in packages/contracts/schemas/privacy.yaml.
//
// AC-3: Users can request data export, account deletion, round deletion
// with status tracking.

import 'package:equatable/equatable.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Type of privacy request.
enum PrivacyRequestType {
  dataExport('DATA_EXPORT'),
  accountDeletion('ACCOUNT_DELETION'),
  roundDeletion('ROUND_DELETION');

  final String value;
  const PrivacyRequestType(this.value);

  static PrivacyRequestType fromString(String value) {
    return PrivacyRequestType.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => PrivacyRequestType.dataExport,
    );
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case PrivacyRequestType.dataExport:
        return 'Data Export';
      case PrivacyRequestType.accountDeletion:
        return 'Account Deletion';
      case PrivacyRequestType.roundDeletion:
        return 'Round Deletion';
    }
  }

  /// Description shown to user.
  String get description {
    switch (this) {
      case PrivacyRequestType.dataExport:
        return 'Download all your personal data as a JSON file';
      case PrivacyRequestType.accountDeletion:
        return 'Permanently delete your account and all data';
      case PrivacyRequestType.roundDeletion:
        return 'Delete a specific round and its scores';
    }
  }

  /// Icon name for this request type.
  String get iconName {
    switch (this) {
      case PrivacyRequestType.dataExport:
        return 'download';
      case PrivacyRequestType.accountDeletion:
        return 'delete_forever';
      case PrivacyRequestType.roundDeletion:
        return 'golf_course';
    }
  }
}

/// Processing status of a privacy request.
enum PrivacyRequestStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  completed('COMPLETED'),
  rejected('REJECTED');

  final String value;
  const PrivacyRequestStatus(this.value);

  static PrivacyRequestStatus fromString(String value) {
    return PrivacyRequestStatus.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => PrivacyRequestStatus.pending,
    );
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case PrivacyRequestStatus.pending:
        return 'Pending';
      case PrivacyRequestStatus.processing:
        return 'Processing';
      case PrivacyRequestStatus.completed:
        return 'Completed';
      case PrivacyRequestStatus.rejected:
        return 'Rejected';
    }
  }
}

// ─── Privacy Request DTO ─────────────────────────────────────────────────────

/// Privacy request data transfer object — mirrors PrivacyRequestResponse in privacy.yaml.
class PrivacyRequestDTO extends Equatable {
  final int id;
  final int requesterGolferAccountId;
  final PrivacyRequestType requestType;
  final PrivacyRequestStatus status;
  final String? targetRoundId;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final int? processedBy;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PrivacyRequestDTO({
    required this.id,
    required this.requesterGolferAccountId,
    required this.requestType,
    required this.status,
    this.targetRoundId,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  /// Parse from GET /privacy/requests JSON response.
  factory PrivacyRequestDTO.fromJson(Map<String, dynamic> json) {
    return PrivacyRequestDTO(
      id: (json['id'] as num).toInt(),
      requesterGolferAccountId: (json['requesterGolferAccountId'] as num).toInt(),
      requestType: PrivacyRequestType.fromString(
        json['requestType'] as String? ?? 'DATA_EXPORT',
      ),
      status: PrivacyRequestStatus.fromString(
        json['status'] as String? ?? 'PENDING',
      ),
      targetRoundId: json['targetRoundId'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'] as String)
          : null,
      processedBy: (json['processedBy'] as num?)?.toInt(),
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Serialize to JSON (for offline storage if needed).
  Map<String, dynamic> toJson() => {
    'id': id,
    'requesterGolferAccountId': requesterGolferAccountId,
    'requestType': requestType.value,
    'status': status.value,
    'targetRoundId': targetRoundId,
    'requestedAt': requestedAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'processedBy': processedBy,
    'rejectionReason': rejectionReason,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  /// Whether this request can be cancelled (only PENDING requests).
  bool get canCancel => status == PrivacyRequestStatus.pending;

  /// Whether this request shows a rejection reason.
  bool get hasRejectionReason =>
      status == PrivacyRequestStatus.rejected &&
      rejectionReason != null &&
      rejectionReason!.isNotEmpty;

  /// Format the requested date for display.
  String get formattedRequestedDate {
    final now = DateTime.now();
    final diff = now.difference(requestedAt);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${requestedAt.day}/${requestedAt.month}/${requestedAt.year}';
    }
  }

  PrivacyRequestDTO copyWith({
    int? id,
    int? requesterGolferAccountId,
    PrivacyRequestType? requestType,
    PrivacyRequestStatus? status,
    String? targetRoundId,
    DateTime? requestedAt,
    DateTime? processedAt,
    int? processedBy,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrivacyRequestDTO(
      id: id ?? this.id,
      requesterGolferAccountId:
          requesterGolferAccountId ?? this.requesterGolferAccountId,
      requestType: requestType ?? this.requestType,
      status: status ?? this.status,
      targetRoundId: targetRoundId ?? this.targetRoundId,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    requesterGolferAccountId,
    requestType,
    status,
    targetRoundId,
    requestedAt,
    processedAt,
    processedBy,
    rejectionReason,
    createdAt,
    updatedAt,
  ];
}

// ─── Create Privacy Request ──────────────────────────────────────────────────

/// Request DTO for POST /privacy/requests.
class CreatePrivacyRequest extends Equatable {
  final PrivacyRequestType requestType;
  final String? targetRoundId;

  const CreatePrivacyRequest({required this.requestType, this.targetRoundId});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'requestType': requestType.value};
    if (targetRoundId != null) {
      map['targetRoundId'] = targetRoundId;
    }
    return map;
  }

  @override
  List<Object?> get props => [requestType, targetRoundId];
}

// ─── Round DTO (for round picker) ────────────────────────────────────────────

/// Minimal round data for the round picker in ROUND_DELETION requests.
/// Only includes fields needed for selection UI.
class RoundSummaryDTO extends Equatable {
  final String id;
  final String? courseName;
  final DateTime? playedAt;
  final int? score;

  const RoundSummaryDTO({
    required this.id,
    this.courseName,
    this.playedAt,
    this.score,
  });

  factory RoundSummaryDTO.fromJson(Map<String, dynamic> json) {
    return RoundSummaryDTO(
      id: json['id'] as String,
      courseName: json['courseName'] as String?,
      playedAt: json['playedAt'] != null
          ? DateTime.tryParse(json['playedAt'] as String)
          : null,
      score: (json['score'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseName': courseName,
    'playedAt': playedAt?.toIso8601String(),
    'score': score,
  };

  /// Format the played date for display.
  String get formattedDate {
    if (playedAt == null) return 'Unknown date';
    final now = DateTime.now();
    final diff = now.difference(playedAt!);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${playedAt!.day}/${playedAt!.month}/${playedAt!.year}';
    }
  }

  /// Short display label.
  String get displayLabel {
    final parts = <String>[];
    if (courseName != null && courseName!.isNotEmpty) {
      parts.add(courseName!);
    }
    parts.add(formattedDate);
    if (score != null) {
      parts.add('Score: $score');
    }
    return parts.join(' • ');
  }

  @override
  List<Object?> get props => [id, courseName, playedAt, score];
}
