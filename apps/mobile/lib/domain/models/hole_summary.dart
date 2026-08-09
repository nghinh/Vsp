// Hole Summary DTO — VSP Mobile App
//
// Minimal hole info for course detail hole list section.
// Mirrors HoleSummaryDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

import 'hole_data_provenance.dart';

/// Hole summary for course detail display.
class HoleSummary extends Equatable {
  final int holeNumber;
  final int par;
  final int? playingLengthMeters;

  /// Where this hole's tee and green coordinates came from.
  ///
  /// [playingLengthMeters] is measured between those two points, so it is
  /// exactly as trustworthy as they are and must never be shown without this.
  /// Defaults to [HoleDataProvenance.unknown] — a hole that says nothing about
  /// its origin is not a surveyed one.
  final HoleDataProvenance provenance;

  const HoleSummary({
    required this.holeNumber,
    required this.par,
    this.playingLengthMeters,
    this.provenance = HoleDataProvenance.unknown,
  });

  factory HoleSummary.fromJson(Map<String, dynamic> json) {
    return HoleSummary(
      holeNumber: (json['holeNumber'] as num).toInt(),
      par: (json['par'] as num).toInt(),
      // API sends this as a decimal (e.g. 362.0) — accept any number.
      playingLengthMeters: (json['playingLengthMeters'] as num?)?.toInt(),
      provenance: HoleDataProvenance.fromJson(
        json['dataQuality'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'holeNumber': holeNumber,
    'par': par,
    if (playingLengthMeters != null) 'playingLengthMeters': playingLengthMeters,
    'dataQuality': provenance.toJson(),
  };

  /// True when the length below was measured between coordinates somebody
  /// verified. False means it must be presented as unverified.
  bool get isSurveyed => provenance.isSurveyed;

  /// Formatted length string.
  String? get formattedLength {
    if (playingLengthMeters == null) return null;
    return '${playingLengthMeters}m';
  }

  @override
  List<Object?> get props => [holeNumber, par, playingLengthMeters, provenance];
}
