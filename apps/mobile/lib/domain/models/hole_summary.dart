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
      holeNumber: json['holeNumber'] as int,
      par: json['par'] as int,
      playingLengthMeters: json['playingLengthMeters'] as int?,
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
