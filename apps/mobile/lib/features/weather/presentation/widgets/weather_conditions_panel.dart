// WeatherConditionsPanel — VSP Mobile App
//
// Story 7.1 Wave 3: Weather Conditions Panel Widget
// Per slice plan §3.1 — displays wind, temperature, humidity, precipitation,
// safety fields, source badge, timestamp, stale warning, forecast/measured badge.
//
// Accessibility:
// - All icons have semantic labels
// - Color not sole indicator (text labels always present)
// - Minimum 44pt touch targets

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/weather_snapshot.dart';
import '../../../../domain/models/wind_data.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Weather conditions panel widget.
///
/// Displays:
/// - Wind: direction arrow (accessible + text), speed, gusts
/// - Temperature + feels like
/// - Humidity %
/// - Precipitation probability
/// - Safety fields: UV index, pressure, visibility
/// - Source badge (provider name)
/// - Timestamp (relative: "Updated 5 min ago")
/// - Stale warning banner (red/gray with explicit text + icon, not color-only)
/// - Forecast/measured type badge
class WeatherConditionsPanel extends StatelessWidget {
  /// The weather snapshot to display.
  final WeatherSnapshot snapshot;

  /// Callback when retry is tapped (for stale/error state).
  final VoidCallback? onRetry;

  const WeatherConditionsPanel({
    super.key,
    required this.snapshot,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _buildSemanticsLabel(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stale warning banner (if stale)
            if (snapshot.freshness != DataFreshness.fresh) ...[
              _StaleWarningBanner(snapshot: snapshot, onRetry: onRetry),
              const SizedBox(height: 12),
            ],

            // Wind first — it is the only thing on this panel a golfer
            // changes a club for.
            //
            // The row above it used to be the source badge, the timestamp and
            // the forecast/measured chip: three pieces of provenance, ahead of
            // the reading they qualify. Provenance matters and it is not the
            // decision, so it now sits under the number it is about, the same
            // way the traced-shapes caveat sits under the shapes and the
            // course name sits under the score.
            _WindRow(wind: snapshot.wind),
            const SizedBox(height: 12),

            // Where this reading came from, and when.
            _buildHeaderRow(context),
            const SizedBox(height: 12),

            // Temperature and humidity row
            _buildTemperatureHumidityRow(context),
            const SizedBox(height: 12),

            // Conditions + precipitation row
            _buildConditionsRow(context),
            const SizedBox(height: 12),

            // Safety fields: UV, pressure, visibility
            _buildSafetyFieldsRow(context),
          ],
        ),
      ),
    );
  }

  String _buildSemanticsLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[
      l10n.weatherConditionsLabel,
      localizedWeatherCondition(l10n, snapshot.condition),
      l10n.weatherTemperatureLabel(
        '${snapshot.temperature?.value ?? '—'}',
        '${snapshot.temperature?.unit ?? ''}',
      ),
      l10n.weatherWindFromAt(
        snapshot.wind.direction.label,
        snapshot.wind.speedKmh.toStringAsFixed(1),
      ),
      l10n.weatherHumiditySemantics('${snapshot.humidity ?? '—'}'),
    ];
    if (snapshot.precipitationProbability != null) {
      parts.add(
        'Precipitation probability ${snapshot.precipitationProbability} percent',
      );
    }
    if (snapshot.freshness != DataFreshness.fresh) {
      parts.add('Warning: weather data may be outdated');
    }
    parts.add(snapshot.relativeTimeString);
    return parts.join('. ');
  }

  Widget _buildHeaderRow(BuildContext context) {
    final theme = Theme.of(context);
    // Wrap, not Row. Three chips of text whose width nobody controls — the
    // provider's own name, a translated type label, and a relative time that
    // is "vừa xong" one minute and "3 giờ trước" the next — inside a Row with
    // a Spacer overflows the moment any of them grows. It does so here at a
    // larger text scale, and it would do so on a phone the first time a
    // provider with a longer name is configured.
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SourceBadge(source: snapshot.source),
        _TypeBadge(type: snapshot.source.measurementType),
        Text(
          snapshot.relativeTimeString,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureHumidityRow(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.thermostat_outlined,
            label: AppLocalizations.of(context).weatherTemperature,
            value: snapshot.temperature != null
                ? '${snapshot.temperature!.value.toStringAsFixed(1)}°${snapshot.temperature!.unit}'
                : '--',
            semanticsLabel: 'Temperature',
          ),
        ),
        if (snapshot.feelsLike != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _MetricTile(
              icon: Icons.thermostat_outlined,
              label: AppLocalizations.of(context).weatherFeelsLike,
              value:
                  '${snapshot.feelsLike!.toStringAsFixed(1)}°${snapshot.temperature?.unit ?? 'C'}',
              semanticsLabel: 'Feels like temperature',
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            icon: Icons.water_drop_outlined,
            label: AppLocalizations.of(context).weatherHumidity,
            value: snapshot.humidity != null ? '${snapshot.humidity}%' : '--',
            semanticsLabel: 'Humidity',
          ),
        ),
      ],
    );
  }

  Widget _buildConditionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ConditionTile(condition: snapshot.condition)),
        if (snapshot.precipitationProbability != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _MetricTile(
              icon: Icons.umbrella_outlined,
              label: AppLocalizations.of(context).weatherPrecipitation,
              value: '${snapshot.precipitationProbability}%',
              semanticsLabel: 'Precipitation probability',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSafetyFieldsRow(BuildContext context) {
    final safetyFields = <Widget>[];

    if (snapshot.uvIndex != null) {
      safetyFields.add(
        _SafetyBadge(
          icon: Icons.wb_sunny_outlined,
          label: AppLocalizations.of(
            context,
          ).weatherUvIndex('${snapshot.uvIndex}'),
          semanticsLabel: AppLocalizations.of(
            context,
          ).weatherUvIndexSemantics('${snapshot.uvIndex}'),
        ),
      );
    }

    if (snapshot.pressure != null) {
      safetyFields.add(
        _SafetyBadge(
          icon: Icons.speed_outlined,
          label:
              '${snapshot.pressure!.value.toStringAsFixed(0)} ${snapshot.pressure!.unit}',
          semanticsLabel:
              'Pressure ${snapshot.pressure!.value} ${snapshot.pressure!.unit}',
        ),
      );
    }

    if (snapshot.visibility != null) {
      safetyFields.add(
        _SafetyBadge(
          icon: Icons.visibility_outlined,
          label:
              '${snapshot.visibility!.value.toStringAsFixed(1)} ${snapshot.visibility!.unit}',
          semanticsLabel:
              'Visibility ${snapshot.visibility!.value} ${snapshot.visibility!.unit}',
        ),
      );
    }

    if (safetyFields.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: safetyFields);
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

/// Wind row with direction arrow, speed, and gusts.
class _WindRow extends StatelessWidget {
  final WindData wind;

  const _WindRow({required this.wind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: AppLocalizations.of(context).weatherWindFromAt(
        wind.direction.label,
        wind.speedKmh.toStringAsFixed(1),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Wind direction arrow (rotates to wind direction)
            Transform.rotate(
              angle: wind.degrees * math.pi / 180,
              child: Icon(
                Icons.navigation,
                size: 32,
                color: theme.colorScheme.primary,
                semanticLabel: AppLocalizations.of(context)
                    .weatherWindDirection(localizedWindDirection(
                        AppLocalizations.of(context), wind.direction)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${wind.speedKmh.toStringAsFixed(1)} km/h',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    semanticsLabel: AppLocalizations.of(context)
                        .weatherWindSpeedSemantics(
                            wind.speedKmh.toStringAsFixed(1)),
                  ),
                  Text(
                    localizedWindDirection(
                        AppLocalizations.of(context), wind.direction),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    semanticsLabel: AppLocalizations.of(context)
                        .weatherWindDirection(localizedWindDirection(
                            AppLocalizations.of(context), wind.direction)),
                  ),
                ],
              ),
            ),
            if (wind.gustsKmh != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.air,
                      size: 14,
                      color: theme.colorScheme.onSecondaryContainer,
                      semanticLabel: AppLocalizations.of(context).weatherWindGusts,
                    ),
                    Text(
                      '${wind.gustsKmh!.toStringAsFixed(0)} km/h',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      semanticsLabel:
                          'Gusts ${wind.gustsKmh!.toStringAsFixed(0)} kilometers per hour',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Metric tile for temperature, humidity, precipitation.
class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String semanticsLabel;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Condition display tile.
class _ConditionTile extends StatelessWidget {
  final WeatherCondition condition;

  const _ConditionTile({required this.condition});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: AppLocalizations.of(context).weatherConditionLabel(
          localizedWeatherCondition(AppLocalizations.of(context), condition)),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _conditionIcon(condition),
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).weatherConditionTileLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    localizedWeatherCondition(
                        AppLocalizations.of(context), condition),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _conditionIcon(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.partly_cloudy:
        return Icons.cloud_queue;
      case WeatherCondition.cloudy:
      case WeatherCondition.overcast:
        return Icons.cloud;
      case WeatherCondition.light_rain:
      case WeatherCondition.rain:
        return Icons.water_drop;
      case WeatherCondition.heavy_rain:
        return Icons.thunderstorm;
      case WeatherCondition.thunderstorm:
        return Icons.flash_on;
      case WeatherCondition.fog:
        return Icons.foggy;
      case WeatherCondition.windy:
        return Icons.air;
    }
  }
}

/// Safety badge for UV, pressure, visibility.
class _SafetyBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticsLabel;

  const _SafetyBadge({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Source badge showing provider name.
class _SourceBadge extends StatelessWidget {
  final WeatherSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: AppLocalizations.of(context).weatherSourceLabel(source.displayLabel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          source.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Measurement type badge (Forecast / Measured).
class _TypeBadge extends StatelessWidget {
  final MeasurementType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForecast = type == MeasurementType.forecast;
    return Semantics(
      label: isForecast
          ? AppLocalizations.of(context).weatherForecastSemantics
          : AppLocalizations.of(context).weatherMeasuredSemantics,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isForecast
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isForecast
                ? theme.colorScheme.secondary
                : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          isForecast
              ? AppLocalizations.of(context).weatherForecastBadge
              : AppLocalizations.of(context).weatherMeasuredBadge,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isForecast
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Stale warning banner with explicit text and icon.
class _StaleWarningBanner extends StatelessWidget {
  final WeatherSnapshot snapshot;
  final VoidCallback? onRetry;

  const _StaleWarningBanner({required this.snapshot, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpired = snapshot.freshness == DataFreshness.expired;
    final backgroundColor = isExpired
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.tertiaryContainer;
    final textColor = isExpired
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onTertiaryContainer;
    final iconColor = isExpired
        ? theme.colorScheme.error
        : theme.colorScheme.tertiary;

    final l10n = AppLocalizations.of(context);
    final age = snapshot.relativeTimeString;

    return Semantics(
      label: isExpired
          ? l10n.weatherExpiredSemantics(age)
          : l10n.weatherStaleSemantics(age),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isExpired ? Icons.error_outline : Icons.warning_amber_outlined,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isExpired ? l10n.weatherExpired(age) : l10n.weatherStale(age),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              TextButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh, size: 16, color: textColor),
                label: Text(
                  AppLocalizations.of(context).commonRefresh,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ─── Localized names for API enums ───────────────────────────────────────────
//
// The API speaks English enum values and the domain enums carry English
// display strings for logs and tests. What a golfer reads comes from here:
// the sweep of 2026-08-20 photographed "Cloudy" and "North" sitting in the
// middle of a Vietnamese screen.

/// The sky condition, in the golfer's language.
String localizedWeatherCondition(AppLocalizations l10n, WeatherCondition c) {
  switch (c) {
    case WeatherCondition.sunny:
      return l10n.weatherCondSunny;
    case WeatherCondition.partly_cloudy:
      return l10n.weatherCondPartlyCloudy;
    case WeatherCondition.cloudy:
      return l10n.weatherCondCloudy;
    case WeatherCondition.overcast:
      return l10n.weatherCondOvercast;
    case WeatherCondition.light_rain:
      return l10n.weatherCondLightRain;
    case WeatherCondition.rain:
      return l10n.weatherCondRain;
    case WeatherCondition.heavy_rain:
      return l10n.weatherCondHeavyRain;
    case WeatherCondition.thunderstorm:
      return l10n.weatherCondThunderstorm;
    case WeatherCondition.fog:
      return l10n.weatherCondFog;
    case WeatherCondition.windy:
      return l10n.weatherCondWindy;
  }
}

/// The full compass name, in the golfer's language. The three-letter labels
/// (N, NNE, …) stay international.
String localizedWindDirection(AppLocalizations l10n, WindDirection d) {
  switch (d) {
    case WindDirection.n:
      return l10n.windDirN;
    case WindDirection.nne:
      return l10n.windDirNNE;
    case WindDirection.ne:
      return l10n.windDirNE;
    case WindDirection.ene:
      return l10n.windDirENE;
    case WindDirection.e:
      return l10n.windDirE;
    case WindDirection.ese:
      return l10n.windDirESE;
    case WindDirection.se:
      return l10n.windDirSE;
    case WindDirection.sse:
      return l10n.windDirSSE;
    case WindDirection.s:
      return l10n.windDirS;
    case WindDirection.ssw:
      return l10n.windDirSSW;
    case WindDirection.sw:
      return l10n.windDirSW;
    case WindDirection.wsw:
      return l10n.windDirWSW;
    case WindDirection.w:
      return l10n.windDirW;
    case WindDirection.wnw:
      return l10n.windDirWNW;
    case WindDirection.nw:
      return l10n.windDirNW;
    case WindDirection.nnw:
      return l10n.windDirNNW;
  }
}
