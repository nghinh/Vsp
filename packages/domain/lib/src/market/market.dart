// Market — VSP Domain Package
//
// Represents a supported geographic market for the platform.
// Each market has an ISO 3166-1 alpha-2 country code, display name, and active flag.
//
// Story 12.4 — Slice 1: Domain Models

import 'package:equatable/equatable.dart';

/// A supported geographic market.
class Market extends Equatable {
  /// ISO 3166-1 alpha-2 country code, e.g. "VN", "TH", "MY"
  final String code;

  /// Human-readable market name, e.g. "Vietnam"
  final String name;

  /// Whether this market is currently active and available.
  final bool isActive;

  const Market({
    required this.code,
    required this.name,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'is_active': isActive,
      };

  factory Market.fromMap(Map<String, dynamic> map) => Market(
        code: map['code'] as String,
        name: map['name'] as String,
        isActive: map['is_active'] as bool? ?? true,
      );

  Market copyWith({
    String? code,
    String? name,
    bool? isActive,
  }) =>
      Market(
        code: code ?? this.code,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
      );

  @override
  List<Object?> get props => [code, name, isActive];
}
