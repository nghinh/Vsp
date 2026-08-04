// Deferred Update Model — VSP Mobile App
//
// Stores package updates that were deferred because an active round was in progress.
// These updates should be applied after the round completes.
//
// Story 4.4 INC-MOBILE-GUARD: deferred update queue.

import 'package:equatable/equatable.dart';

/// A package update that was deferred due to an active round.
class DeferredUpdate extends Equatable {
  final int courseId;
  final String newVersion;
  final String newEtag;
  final DateTime deferredAt;
  final String? roundId;

  const DeferredUpdate({
    required this.courseId,
    required this.newVersion,
    required this.newEtag,
    required this.deferredAt,
    this.roundId,
  });

  @override
  List<Object?> get props => [
    courseId,
    newVersion,
    newEtag,
    deferredAt,
    roundId,
  ];
}
