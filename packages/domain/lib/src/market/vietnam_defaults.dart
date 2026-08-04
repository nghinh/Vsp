// VietnamDefaults — VSP Domain Package
//
// Static class holding Vietnam baseline defaults for all market configuration fields.
// Market configs are partial overrides — only non-null fields in MarketConfig override these defaults.
//
// Story 12.4 — Slice 1: Domain Models

import 'market_config.dart';

/// Vietnam baseline market defaults.
///
/// All market configs start with these values and selectively override
/// only the fields that differ for their market.
class VietnamDefaults {
  VietnamDefaults._();

  /// Default locale for Vietnam.
  static const String locale = 'vi-VN';

  /// Default language code for Vietnam.
  static const String language = 'vi';

  /// Default distance unit for Vietnam.
  static const DistanceUnit units = DistanceUnit.metric;

  /// Default timezone for Vietnam.
  static const String timezone = 'Asia/Ho_Chi_Minh';

  /// Default currency for Vietnam.
  static const String currency = 'VND';

  /// Default data retention policy in days.
  static const int retentionPolicyDays = 365;

  /// Default enabled provider IDs for Vietnam.
  /// Empty list means all providers are enabled.
  static List<String> get enabledProviderIds => [];

  /// Default required license IDs for Vietnam.
  /// Empty list means no specific licenses are required.
  static List<String> get requiredLicenseIds => [];
}
