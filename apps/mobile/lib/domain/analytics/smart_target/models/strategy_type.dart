// StrategyType Enum — VSP Mobile App
//
// Risk strategy tiers for Smart Target recommendations.
//
// Story 11.4 — Slice 0: Domain Models

/// Risk strategy tiers for shot recommendation.
enum StrategyType {
  /// Minimize risk; prefer higher-confidence clubs even if less distance.
  safe('Safe', 'Minimize risk, prefer accuracy'),

  /// Balance expected strokes gained vs. risk tradeoff.
  balanced('Balanced', 'Balance risk and reward'),

  /// Maximize potential distance gain, accept higher risk.
  aggressive('Aggressive', 'Maximize distance, accept risk');

  final String displayName;
  final String description;

  const StrategyType(this.displayName, this.description);
}
