// DataLicense — VSP Domain Package
//
// Represents a data license that governs redistribution rights for course packages.
// The redistributionMarkets field lists market codes where redistribution is allowed.
//
// Story 12.4 — Slice 1: Domain Models

import 'package:equatable/equatable.dart';

/// A data license with redistribution market permissions.
class DataLicense extends Equatable {
  /// Unique license identifier.
  final String id;

  /// Human-readable license name.
  final String name;

  /// SPDX license identifier.
  final String spdxId;

  /// List of market codes (ISO alpha-2) where redistribution is allowed.
  /// e.g. ["VN", "TH"] means this data can be redistributed in Vietnam and Thailand.
  final List<String> redistributionMarkets;

  /// When this license was issued.
  final DateTime? issuedAt;

  /// When this license expires. Null = never expires.
  final DateTime? expiresAt;

  /// Optional licensee name (who this license is granted to).
  final String? licensee;

  const DataLicense({
    required this.id,
    required this.name,
    required this.spdxId,
    required this.redistributionMarkets,
    this.issuedAt,
    this.expiresAt,
    this.licensee,
  });

  /// Returns true if this license is currently valid (not expired).
  bool get isValid {
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// Returns true if redistribution is allowed in the given market.
  bool allowsRedistribution(String marketCode) {
    return redistributionMarkets.contains(marketCode);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'spdx_id': spdxId,
        'redistribution_markets': redistributionMarkets,
        'issued_at': issuedAt?.toUtc().toIso8601String(),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'licensee': licensee,
      };

  factory DataLicense.fromMap(Map<String, dynamic> map) => DataLicense(
        id: map['id'] as String,
        name: map['name'] as String,
        spdxId: map['spdx_id'] as String,
        redistributionMarkets:
            (map['redistribution_markets'] as List<dynamic>).cast<String>(),
        issuedAt: map['issued_at'] != null
            ? DateTime.parse(map['issued_at'] as String)
            : null,
        expiresAt: map['expires_at'] != null
            ? DateTime.parse(map['expires_at'] as String)
            : null,
        licensee: map['licensee'] as String?,
      );

  DataLicense copyWith({
    String? id,
    String? name,
    String? spdxId,
    List<String>? redistributionMarkets,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? licensee,
  }) =>
      DataLicense(
        id: id ?? this.id,
        name: name ?? this.name,
        spdxId: spdxId ?? this.spdxId,
        redistributionMarkets: redistributionMarkets ?? this.redistributionMarkets,
        issuedAt: issuedAt ?? this.issuedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        licensee: licensee ?? this.licensee,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        spdxId,
        redistributionMarkets,
        issuedAt,
        expiresAt,
        licensee,
      ];
}
