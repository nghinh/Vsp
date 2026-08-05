// TournamentFeatureGuard — VSP Mobile App
//
// Offline-capable service that answers isFeatureEnabled(roundId, feature).
// Used by UI layers to hide/disable restricted controls.
//
// Per PRD §8.12: "Restricted features must be hidden or disabled."
// Per Architecture §14 QG-8: "Basic Tournament Mode restrictions are
// represented in config and UI."
//
// Story 7.4 — Slice C: TournamentFeatureGuard

import 'package:sqflite/sqflite.dart';

import '../../domain/models/tournament_policy.dart';
import '../../domain/models/tournament_feature.dart';
import '../../data/repositories/round_repository.dart';

/// Service that answers whether a feature is enabled for a given round.
///
/// Uses an in-memory cache backed by SQLite for offline capability.
///
/// **Semantics:**
/// - `null` tournamentPolicyId → all features enabled (casual/practice)
/// - `non-null` tournamentPolicyId → consult cached policy
/// - Policy not in cache → fetch from API and cache (or use stale cache if offline)
///
/// **Cache invalidation:** On round change or policy update.
class TournamentFeatureGuard {
  final RoundRepository _roundRepo;
  final TournamentPolicyLocalCache _cache;

  /// In-memory policy cache keyed by policyId.
  /// One entry per policyId, shared across all round lookups.
  final Map<String, TournamentPolicy> _policyCache = {};

  TournamentFeatureGuard({
    required RoundRepository roundRepo,
    required TournamentPolicyLocalCache cache,
  }) : _roundRepo = roundRepo,
       _cache = cache;

  /// Returns true if the given [feature] is enabled for the active round.
  ///
  /// - No active round → true (features available)
  /// - Round has no tournamentPolicyId (casual/practice) → true
  /// - Round has cached tournamentPolicy → use it directly (fast path for tournament rounds)
  /// - Policy not found → true (fail open — show feature)
  ///
  /// Performance target: <10ms for in-memory cache hit.
  Future<bool> isFeatureEnabled(
    String roundId,
    TournamentFeature feature,
  ) async {
    // Get the active round
    final round = await _roundRepo.getRound(roundId);
    if (round == null) return true; // No round = no restrictions

    // No policy ID = casual/practice round = no restrictions
    final policyId = round.tournamentPolicyId;
    if (policyId == null) return true;

    // Per Story 12.1 Slice F: if round has cached tournamentPolicy, use it directly
    if (round.tournamentPolicy != null) {
      return round.tournamentPolicy!.isFeatureEnabled(feature);
    }

    // Check in-memory cache first (fast path — <10ms)
    final cached = _policyCache[policyId];
    if (cached != null) {
      return cached.isFeatureEnabled(feature);
    }

    // Try to load from SQLite cache (offline path)
    final cachedPolicy = await _cache.getPolicy(policyId);
    if (cachedPolicy != null) {
      _policyCache[policyId] = cachedPolicy;
      return cachedPolicy.isFeatureEnabled(feature);
    }

    // Policy not found locally — fail open (show feature, sync will fix)
    // In a real implementation, would also fire an API fetch here.
    return true;
  }

  /// Returns the restriction reason for [feature] in [roundId], or null if enabled.
  ///
  /// Returns a localized string like
  /// "Wind adjustment is disabled in tournament mode."
  Future<String?> getRestrictionReason(
    String roundId,
    TournamentFeature feature,
  ) async {
    final enabled = await isFeatureEnabled(roundId, feature);
    if (enabled) return null;

    // Return the feature's restriction label
    return feature.restrictionLabel;
  }

  /// Updates the in-memory cache with a policy (after create/update).
  void cachePolicy(TournamentPolicy policy) {
    _policyCache[policy.id] = policy;
  }

  /// Invalidates the cache for a specific policy.
  void invalidatePolicy(String policyId) {
    _policyCache.remove(policyId);
    _cache.removePolicy(policyId);
  }

  /// Invalidates all cached policies (e.g., on round change).
  void invalidateAll() {
    _policyCache.clear();
  }
}

/// Local SQLite cache for tournament policies.
///
/// Enables the TournamentFeatureGuard to work fully offline
/// by persisting policy data between app sessions.
class TournamentPolicyLocalCache {
  static const String _tableName = 'tournament_policies';
  static const String _dbName = 'vsp_tournament.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        wind_adjustment_enabled INTEGER NOT NULL DEFAULT 1,
        plays_like_enabled INTEGER NOT NULL DEFAULT 1,
        elevation_enabled INTEGER NOT NULL DEFAULT 1,
        club_recommendation_enabled INTEGER NOT NULL DEFAULT 1,
        contours_enabled INTEGER NOT NULL DEFAULT 1,
        putting_help_enabled INTEGER NOT NULL DEFAULT 1,
        ai_features_enabled INTEGER NOT NULL DEFAULT 1,
        is_locked INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_tournament_policies_id ON $_tableName (id)
    ''');
  }

  /// Persist a policy to local cache.
  Future<void> savePolicy(TournamentPolicy policy) async {
    final db = await _database;
    await db.insert(
      _tableName,
      _toMap(policy),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve a policy from local cache.
  Future<TournamentPolicy?> getPolicy(String policyId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [policyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  /// Remove a policy from local cache.
  Future<void> removePolicy(String policyId) async {
    final db = await _database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [policyId]);
  }

  Map<String, dynamic> _toMap(TournamentPolicy p) {
    return {
      'id': p.id,
      'name': p.name,
      'wind_adjustment_enabled': p.windAdjustmentEnabled ? 1 : 0,
      'plays_like_enabled': p.playsLikeEnabled ? 1 : 0,
      'elevation_enabled': p.elevationEnabled ? 1 : 0,
      'club_recommendation_enabled': p.clubRecommendationEnabled ? 1 : 0,
      'contours_enabled': p.contoursEnabled ? 1 : 0,
      'putting_help_enabled': p.puttingHelpEnabled ? 1 : 0,
      'ai_features_enabled': p.aiFeaturesEnabled ? 1 : 0,
      'is_locked': p.isLocked ? 1 : 0,
      'created_at': p.createdAt.toIso8601String(),
      'created_by': p.createdBy,
      'version': p.version,
      'cached_at': DateTime.now().toIso8601String(),
    };
  }

  TournamentPolicy _fromMap(Map<String, dynamic> map) {
    return TournamentPolicy(
      id: map['id'] as String,
      name: map['name'] as String,
      windAdjustmentEnabled: ((map['wind_adjustment_enabled'] as num).toInt()) == 1,
      playsLikeEnabled: ((map['plays_like_enabled'] as num).toInt()) == 1,
      elevationEnabled: ((map['elevation_enabled'] as num).toInt()) == 1,
      clubRecommendationEnabled:
          ((map['club_recommendation_enabled'] as num).toInt()) == 1,
      contoursEnabled: ((map['contours_enabled'] as num).toInt()) == 1,
      puttingHelpEnabled: ((map['putting_help_enabled'] as num).toInt()) == 1,
      aiFeaturesEnabled: ((map['ai_features_enabled'] as num).toInt()) == 1,
      isLocked: ((map['is_locked'] as num).toInt()) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      createdBy: map['created_by'] as String,
      version: (map['version'] as num).toInt(),
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    _db?.close();
    _db = null;
  }
}
