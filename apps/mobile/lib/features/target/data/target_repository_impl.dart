// Target Repository Implementation — VSP Mobile App
//
// Concrete implementation of TargetRepository backed by TargetLocalStore.
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import '../domain/target_model.dart';
import '../domain/target_repository.dart';
import 'target_local_store.dart';

/// Concrete implementation of TargetRepository using SQLite local store.
class TargetRepositoryImpl implements TargetRepository {
  final TargetLocalStore _localStore;

  TargetRepositoryImpl({TargetLocalStore? localStore})
    : _localStore = localStore ?? TargetLocalStore();

  @override
  Future<void> saveTarget(TargetModel target) async {
    await _localStore.upsertTarget(target);
  }

  @override
  Future<TargetModel?> getTarget(String roundId, int holeNumber) {
    return _localStore.getTarget(roundId, holeNumber);
  }

  @override
  Future<void> deleteTarget(String roundId, int holeNumber) {
    return _localStore.deleteTarget(roundId, holeNumber);
  }

  @override
  Future<List<TargetModel>> getTargetsForRound(String roundId) {
    return _localStore.getTargetsForRound(roundId);
  }

  @override
  Future<void> close() {
    return _localStore.close();
  }
}
