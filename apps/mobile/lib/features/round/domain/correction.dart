// Correction Model — VSP Mobile App
//
// Represents a score correction for the correction dialog.
// Per Story 5.5 Slice 3: AC-3 correction with audit history.

/// Represents a single field correction for a score entry.
class Correction {
  final String field;
  final int holeNumber;
  final String oldValue;
  final String newValue;

  const Correction({
    required this.field,
    required this.holeNumber,
    required this.oldValue,
    required this.newValue,
  });

  Map<String, dynamic> toMap() => {
    'field': field,
    'holeNumber': holeNumber,
    'oldValue': oldValue,
    'newValue': newValue,
  };

  factory Correction.fromMap(Map<String, dynamic> map) {
    return Correction(
      field: map['field'] as String,
      holeNumber: (map['holeNumber'] as num).toInt(),
      oldValue: map['oldValue'] as String,
      newValue: map['newValue'] as String,
    );
  }
}

/// Request payload for submitting score corrections.
class CorrectionRequest {
  final String playerId;
  final List<Correction> corrections;

  const CorrectionRequest({required this.playerId, required this.corrections});

  Map<String, dynamic> toMap() => {
    'playerId': playerId,
    'corrections': corrections.map((c) => c.toMap()).toList(),
  };
}
