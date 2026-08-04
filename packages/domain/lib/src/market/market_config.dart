// MarketConfig — VSP Domain Package
//
// Per-market configuration that partially overrides VietnamDefaults.
// All fields are nullable — a null field means "use the Vietnam default".
//
// Story 12.4 — Slice 1: Domain Models

import 'package:equatable/equatable.dart';

/// Distance measurement unit.
enum DistanceUnit { metric, imperial }

/// Market-specific configuration — partial override of VietnamDefaults.
class MarketConfig extends Equatable {
  /// The market code this config belongs to (e.g. "TH").
  final String marketCode;

  /// Locale string, e.g. "th-TH". Null = Vietnam default "vi-VN".
  final String? locale;

  /// Language code, e.g. "th". Null = Vietnam default "vi".
  final String? language;

  /// Distance unit. Null = Vietnam default METRIC.
  final DistanceUnit? units;

  /// Timezone identifier, e.g. "Asia/Bangkok". Null = Vietnam default "Asia/Ho_Chi_Minh".
  final String? timezone;

  /// Currency code, e.g. "THB". Null = Vietnam default "VND".
  final String? currency;

  /// URL to market-specific rules document. Null = no market-specific rules.
  final String? rulesUrl;

  /// List of enabled provider IDs for this market.
  /// Null = all Vietnam providers are enabled.
  final List<String>? enabledProviderIds;

  /// List of required license IDs for this market.
  /// Null = Vietnam default licenses required.
  final List<String>? requiredLicenseIds;

  /// Data retention policy in days. Null = Vietnam default 365.
  final int? retentionPolicyDays;

  const MarketConfig({
    required this.marketCode,
    this.locale,
    this.language,
    this.units,
    this.timezone,
    this.currency,
    this.rulesUrl,
    this.enabledProviderIds,
    this.requiredLicenseIds,
    this.retentionPolicyDays,
  });

  Map<String, dynamic> toMap() => {
        'market_code': marketCode,
        'locale': locale,
        'language': language,
        'units': units?.name,
        'timezone': timezone,
        'currency': currency,
        'rules_url': rulesUrl,
        'enabled_provider_ids': enabledProviderIds,
        'required_license_ids': requiredLicenseIds,
        'retention_policy_days': retentionPolicyDays,
      };

  factory MarketConfig.fromMap(Map<String, dynamic> map) => MarketConfig(
        marketCode: map['market_code'] as String,
        locale: map['locale'] as String?,
        language: map['language'] as String?,
        units: map['units'] != null
            ? DistanceUnit.values.firstWhere((e) => e.name == map['units'])
            : null,
        timezone: map['timezone'] as String?,
        currency: map['currency'] as String?,
        rulesUrl: map['rules_url'] as String?,
        enabledProviderIds: (map['enabled_provider_ids'] as List<dynamic>?)?.cast<String>(),
        requiredLicenseIds: (map['required_license_ids'] as List<dynamic>?)?.cast<String>(),
        retentionPolicyDays: map['retention_policy_days'] as int?,
      );

  MarketConfig copyWith({
    String? marketCode,
    String? locale,
    String? language,
    DistanceUnit? units,
    String? timezone,
    String? currency,
    String? rulesUrl,
    List<String>? enabledProviderIds,
    List<String>? requiredLicenseIds,
    int? retentionPolicyDays,
  }) =>
      MarketConfig(
        marketCode: marketCode ?? this.marketCode,
        locale: locale ?? this.locale,
        language: language ?? this.language,
        units: units ?? this.units,
        timezone: timezone ?? this.timezone,
        currency: currency ?? this.currency,
        rulesUrl: rulesUrl ?? this.rulesUrl,
        enabledProviderIds: enabledProviderIds ?? this.enabledProviderIds,
        requiredLicenseIds: requiredLicenseIds ?? this.requiredLicenseIds,
        retentionPolicyDays: retentionPolicyDays ?? this.retentionPolicyDays,
      );

  @override
  List<Object?> get props => [
        marketCode,
        locale,
        language,
        units,
        timezone,
        currency,
        rulesUrl,
        enabledProviderIds,
        requiredLicenseIds,
        retentionPolicyDays,
      ];
}
