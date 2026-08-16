// Traced hole shapes — VSP Mobile App
//
// The polygons a vision model traced from satellite imagery: greens,
// bunkers, water, fairways. Most holes in this country have none of this on
// file, and until it exists the map is two dots on an empty screen.
//
// These arrive unreviewed and say so. The map draws them with the same
// styles a surveyed course uses — a bunker is a bunker — and the screen
// carries one line admitting nobody has checked them against the ground.

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

class TracedFeatures {
  const TracedFeatures({
    required this.layers,
    required this.anyUnverified,
    this.anyFromModel = false,
  });

  /// Ready to merge into HoleMapEntity.layers.
  final Map<MapLayerType, MapLayerEntity> layers;

  /// True while at least one shape here is nobody's but the model's.
  final bool anyUnverified;

  /// True when a vision model drew some of this, as opposed to a person.
  ///
  /// The two need different words on screen. "A model traced this and nobody
  /// has checked it" is a warning. A green a mapper drew by hand off the same
  /// imagery is not that, and warning about it teaches a golfer to ignore the
  /// line that matters.
  final bool anyFromModel;

  bool get isEmpty => layers.isEmpty;

  static const empty =
      TracedFeatures(layers: <MapLayerType, MapLayerEntity>{}, anyUnverified: false);
}

class HoleFeatureApi {
  HoleFeatureApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Asks the server to trace this hole, because nothing has drawn it yet.
  ///
  /// Returns true when the shapes are on their way — the server queues one
  /// model call, and the map picks them up on a later poll. False when it
  /// refused: already traced, already queued, or this account has asked for
  /// its share today.
  Future<bool> requestTrace({
    required String courseId,
    required int holeNumber,
  }) async {
    try {
      final json = await _apiClient.post(
        '/courses/$courseId/holes/$holeNumber/features/request',
      );
      final status = (json as Map<String, dynamic>)['status'];
      return status == 'QUEUED' || status == 'ANALYSING';
    } catch (_) {
      // Offline, over the daily limit, or the hole has no coordinates to
      // frame an image around. The map stays as it was.
      return false;
    }
  }

  Future<TracedFeatures> forHole({
    required String courseId,
    required int holeNumber,
  }) async {
    final json = await _apiClient.get(
      '/courses/$courseId/holes/$holeNumber/features',
    );
    return parse(json);
  }

  /// Pure, so the grouping can be tested without a network.
  static TracedFeatures parse(dynamic json) {
    if (json is! Map<String, dynamic>) return TracedFeatures.empty;
    final features = json['features'];
    if (features is! List || features.isEmpty) return TracedFeatures.empty;

    final byLayer = <MapLayerType, List<Map<String, dynamic>>>{};
    var anyUnverified = false;
    var anyFromModel = false;

    for (final entry in features) {
      if (entry is! Map<String, dynamic>) continue;
      final properties = entry['properties'];
      if (properties is! Map<String, dynamic>) continue;
      final type = _layerOf(properties['layerType'] as String?);
      if (type == null) continue;
      if (properties['verified'] != true) anyUnverified = true;
      if (properties['source'] == 'ai-satellite') anyFromModel = true;
      byLayer.putIfAbsent(type, () => []).add(entry);
    }

    return TracedFeatures(
      layers: {
        for (final entry in byLayer.entries)
          entry.key: MapLayerEntity(
            type: entry.key,
            format: LayerGeometryFormat.geoJson,
            geoJson: {
              'type': 'FeatureCollection',
              'features': entry.value,
            },
            style: const LayerStyle(),
          ),
      },
      anyUnverified: anyUnverified,
      anyFromModel: anyFromModel,
    );
  }

  static MapLayerType? _layerOf(String? name) {
    switch (name) {
      case 'green':
        return MapLayerType.green;
      case 'fairway':
        return MapLayerType.fairway;
      case 'bunker':
        return MapLayerType.bunker;
      case 'water':
        return MapLayerType.water;
      case 'tee':
        return MapLayerType.tee;
      case 'rough':
        return MapLayerType.rough;
      case 'penaltyArea':
        return MapLayerType.penaltyArea;
      case 'ob':
        return MapLayerType.ob;
      case 'cartPath':
        return MapLayerType.cartPath;
      case 'landmark':
        return MapLayerType.landmark;
      default:
        return null;
    }
  }
}
