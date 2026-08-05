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

            // Header: source badge + timestamp + type badge
            _buildHeaderRow(context),
            const SizedBox(height: 16),

            // Wind row
            _WindRow(wind: snapshot.wind),
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
      snapshot.condition.displayLabel,
      l10n.weatherTemperatureLabel(
        '${snapshot.temperature?.value ?? '—'}',
        '${snapshot.temperature?.unit ?? ''}',
      ),
      l10n.weatherWindFromAt(
        snapshot.wind.direction.label,
        snapshot.wind.speedKmh.toStringAsFixed(1),
      ),
      'Humidity ${snapshot.humidity ?? 'unknown'} percent',
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
    return Row(
      children: [
        // Source badge
        _SourceBadge(source: snapshot.source),
        const SizedBox(width: 8),
        // Measurement type badge
        _TypeBadge(type: snapshot.source.measurementType),
        const Spacer(),
        // Timestamp
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
          label: AppLocalizations.of(context).weatherUvIndex('${snapshot.uvIndex}'),
          semanticsLabel: 'UV index ${snapshot.uvIndex}',
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
                semanticLabel: AppLocalizations.of(context).weatherWindDirection(wind.direction.displayName),
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
                    semanticsLabel:
                        'Wind speed ${wind.speedKmh.toStringAsFixed(1)} kilometers per hour',
                  ),
                  Text(
                    wind.direction.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    semanticsLabel: 'Wind from ${wind.direction.displayName}',
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
      label: AppLocalizations.of(context).weatherConditionLabel(condition.displayLabel),
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
                    'Condition',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    condition.displayLabel,
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
      label: isForecast ? 'Forecast data' : 'Current measurement',
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
          isForecast ? 'Forecast' : 'Current',
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

    return Semantics(
      label:
          'Warning: weather data is ${isExpired ? 'expired' : 'outdated'}. ${snapshot.relativeTimeString}',
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
                isExpired
                    ? 'Weather data expired. ${snapshot.relativeTimeString}.'
                    : 'Weather may be outdated. ${snapshot.relativeTimeString}.',
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
                  'Refresh',
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
