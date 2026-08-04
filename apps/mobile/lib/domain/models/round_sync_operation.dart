// Round Sync Operation Enum — VSP Mobile App
//
// Operation types for the round sync queue.
// Mirrors the BagSyncOperation pattern from BagSyncStore.
//
// Story 5.2: Persist Round Locally

/// Operation types for the round sync queue.
enum RoundSyncOperation {
  startRound,
  endRound,
  updateRound,
  addHoleScore,
  updateHoleScore,
  deleteHoleScore,
}
