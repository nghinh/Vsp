// Hole Summary DTO — VSP Mobile App
//
// Minimal hole info for course detail hole list section.
// Mirrors HoleSummaryDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

/// Hole summary for course detail display.
class HoleSummary extends Equatable {
  final int holeNumber;
  final int par;
  final int? playingLengthMeters;

  const HoleSummary({
    required this.holeNumber,
    required this.par,
    this.playingLengthMeters,
  });

  factory HoleSummary.fromJson(Map<String, dynamic> json) {
    return HoleSummary(
      holeNumber: (json['holeNumber'] as num).toInt(),
      par: (json['par'] as num).toInt(),
      // API sends this as a decimal (e.g. 362.0) — accept any number.
      playingLengthMeters: (json['playingLengthMeters'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'holeNumber': holeNumber,
    'par': par,
    if (playingLengthMeters != null) 'playingLengthMeters': playingLengthMeters,
  };

  /// Formatted length string.
  String? get formattedLength {
    if (playingLengthMeters == null) return null;
    return '${playingLengthMeters}m';
  }

  @override
  List<Object?> get props => [holeNumber, par, playingLengthMeters];
}
