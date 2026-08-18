// Bag BLoC — VSP Mobile App
//
// State management for bag list, bag detail, club CRUD, and active bag selection.
//
// Events: LoadBags, CreateBag, UpdateBag, DeleteBag, SetActiveBag,
//         LoadClubs, CreateClub, UpdateClub, DeleteClub, FlushQueue
// States: BagInitial, BagLoading, BagLoaded, BagError
//
// AC-1: Full club CRUD with all fields (loft, carry, total, dispersion, shaft, use date).
// AC-2: Active bag highlighted and selectable.
// AC-3: hasMinimumClubData exposed in state for RecommendationsDisabledBanner.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/bag_dto.dart';
import '../data/bag_repository.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

abstract class BagEvent extends Equatable {
  const BagEvent();

  @override
  List<Object?> get props => [];
}

class LoadBags extends BagEvent {
  final bool forceReload;
  const LoadBags({this.forceReload = false});

  @override
  List<Object?> get props => [forceReload];
}

class CreateBag extends BagEvent {
  final String name;
  const CreateBag({required this.name});

  @override
  List<Object?> get props => [name];
}

class UpdateBag extends BagEvent {
  final int bagId;
  final String? name;
  final bool? isActive;
  const UpdateBag({required this.bagId, this.name, this.isActive});

  @override
  List<Object?> get props => [bagId, name, isActive];
}

class DeleteBag extends BagEvent {
  final int bagId;
  const DeleteBag({required this.bagId});

  @override
  List<Object?> get props => [bagId];
}

class SetActiveBag extends BagEvent {
  final int bagId;
  const SetActiveBag({required this.bagId});

  @override
  List<Object?> get props => [bagId];
}

class LoadBagDetail extends BagEvent {
  final int bagId;
  const LoadBagDetail({required this.bagId});

  @override
  List<Object?> get props => [bagId];
}

class CreateClub extends BagEvent {
  final int bagId;
  final CreateClubRequest request;
  const CreateClub({required this.bagId, required this.request});

  @override
  List<Object?> get props => [bagId, request];
}

class UpdateClub extends BagEvent {
  final int bagId;
  final int clubId;
  final UpdateClubRequest request;
  const UpdateClub({
    required this.bagId,
    required this.clubId,
    required this.request,
  });

  @override
  List<Object?> get props => [bagId, clubId, request];
}

class DeleteClub extends BagEvent {
  final int bagId;
  final int clubId;
  const DeleteClub({required this.bagId, required this.clubId});

  @override
  List<Object?> get props => [bagId, clubId];
}

class FlushQueue extends BagEvent {
  const FlushQueue();
}

// ─── States ─────────────────────────────────────────────────────────────────

abstract class BagState extends Equatable {
  const BagState();

  @override
  List<Object?> get props => [];
}

class BagInitial extends BagState {
  const BagInitial();
}

class BagLoading extends BagState {
  const BagLoading();
}

class BagLoaded extends BagState {
  final List<BagDTO> bags;
  final BagDTO? activeBag;
  final bool hasMinimumClubData;
  final bool hasPendingSync;
  final bool isSyncing;
  final String? message;
  final bool isError;

  const BagLoaded({
    required this.bags,
    this.activeBag,
    required this.hasMinimumClubData,
    this.hasPendingSync = false,
    this.isSyncing = false,
    this.message,
    this.isError = false,
  });

  BagLoaded copyWith({
    List<BagDTO>? bags,
    BagDTO? activeBag,
    bool? hasMinimumClubData,
    bool? hasPendingSync,
    bool? isSyncing,
    String? message,
    bool? isError,
  }) {
    return BagLoaded(
      bags: bags ?? this.bags,
      activeBag: activeBag ?? this.activeBag,
      hasMinimumClubData: hasMinimumClubData ?? this.hasMinimumClubData,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
      isSyncing: isSyncing ?? this.isSyncing,
      message: message,
      isError: isError ?? this.isError,
    );
  }

  @override
  List<Object?> get props => [
    bags,
    activeBag,
    hasMinimumClubData,
    hasPendingSync,
    isSyncing,
    message,
    isError,
  ];
}

class BagDetailLoaded extends BagState {
  final List<BagDTO> bags;
  final BagDTO selectedBag;
  final bool hasMinimumClubData;
  final bool hasPendingSync;
  final bool isSyncing;
  final String? message;
  final bool isError;

  const BagDetailLoaded({
    required this.bags,
    required this.selectedBag,
    required this.hasMinimumClubData,
    this.hasPendingSync = false,
    this.isSyncing = false,
    this.message,
    this.isError = false,
  });

  BagDetailLoaded copyWith({
    List<BagDTO>? bags,
    BagDTO? selectedBag,
    bool? hasMinimumClubData,
    bool? hasPendingSync,
    bool? isSyncing,
    String? message,
    bool? isError,
  }) {
    return BagDetailLoaded(
      bags: bags ?? this.bags,
      selectedBag: selectedBag ?? this.selectedBag,
      hasMinimumClubData: hasMinimumClubData ?? this.hasMinimumClubData,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
      isSyncing: isSyncing ?? this.isSyncing,
      message: message,
      isError: isError ?? this.isError,
    );
  }

  @override
  List<Object?> get props => [
    bags,
    selectedBag,
    hasMinimumClubData,
    hasPendingSync,
    isSyncing,
    message,
    isError,
  ];
}

class BagError extends BagState {
  final String message;
  final List<BagDTO>? lastBags;

  const BagError({required this.message, this.lastBags});

  @override
  List<Object?> get props => [message, lastBags];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

class BagBloc extends Bloc<BagEvent, BagState> {
  final BagRepository _bagRepository;

  BagBloc({required BagRepository bagRepository})
    : _bagRepository = bagRepository,
      super(const BagInitial()) {
    on<LoadBags>(_onLoadBags);
    on<CreateBag>(_onCreateBag);
    on<UpdateBag>(_onUpdateBag);
    on<DeleteBag>(_onDeleteBag);
    on<SetActiveBag>(_onSetActiveBag);
    on<LoadBagDetail>(_onLoadBagDetail);
    on<CreateClub>(_onCreateClub);
    on<UpdateClub>(_onUpdateClub);
    on<DeleteClub>(_onDeleteClub);
    on<FlushQueue>(_onFlushQueue);
  }

  Future<void> _onLoadBags(LoadBags event, Emitter<BagState> emit) async {
    emit(const BagLoading());
    try {
      final bags = await _bagRepository.getBags(forceReload: event.forceReload);
      final activeBag = bags.isNotEmpty
          ? bags.firstWhere((b) => b.isActive, orElse: () => bags.first)
          : null;
      final hasMinData = await _bagRepository.hasMinimumClubData();
      final hasPending = await _bagRepository.hasPendingUpdates();
      emit(
        BagLoaded(
          bags: bags,
          activeBag: activeBag,
          hasMinimumClubData: hasMinData,
          hasPendingSync: hasPending,
        ),
      );
    } catch (ex) {
      emit(const BagError(message: AppMessages.bagLoadFailed));
    }
  }

  Future<void> _onCreateBag(CreateBag event, Emitter<BagState> emit) async {
    final currentState = state;
    if (currentState is! BagLoaded) return;

    emit(currentState.copyWith(isSyncing: true));
    final result = await _bagRepository.createBag(name: event.name);
    final hasPending = await _bagRepository.hasPendingUpdates();
    final bags = await _bagRepository.getBags();
    final activeBag = bags.isNotEmpty
        ? bags.firstWhere((b) => b.isActive, orElse: () => bags.first)
        : null;

    emit(
      currentState.copyWith(
        bags: bags,
        activeBag: activeBag,
        hasPendingSync: hasPending,
        isSyncing: false,
        message: result.wasQueued ? AppMessages.bagSavedOffline : null,
      ),
    );
  }

  Future<void> _onUpdateBag(UpdateBag event, Emitter<BagState> emit) async {
    final currentState = state;
    if (currentState is! BagLoaded) return;

    emit(currentState.copyWith(isSyncing: true));
    final result = await _bagRepository.updateBag(
      bagId: event.bagId,
      name: event.name,
      isActive: event.isActive,
    );
    final hasPending = await _bagRepository.hasPendingUpdates();
    final bags = await _bagRepository.getBags();
    final activeBag = bags.isNotEmpty
        ? bags.firstWhere((b) => b.isActive, orElse: () => bags.first)
        : null;

    emit(
      currentState.copyWith(
        bags: bags,
        activeBag: activeBag,
        hasPendingSync: hasPending,
        isSyncing: false,
        message: result.wasQueued ? AppMessages.bagSavedOffline : null,
      ),
    );
  }

  Future<void> _onDeleteBag(DeleteBag event, Emitter<BagState> emit) async {
    final currentState = state;
    if (currentState is! BagLoaded) return;

    emit(currentState.copyWith(isSyncing: true));
    await _bagRepository.deleteBag(event.bagId);
    final hasPending = await _bagRepository.hasPendingUpdates();
    final bags = await _bagRepository.getBags();
    final activeBag = bags.isNotEmpty
        ? bags.firstWhere((b) => b.isActive, orElse: () => bags.first)
        : null;

    emit(
      currentState.copyWith(
        bags: bags,
        activeBag: activeBag,
        hasPendingSync: hasPending,
        isSyncing: false,
        message: AppMessages.bagDeleted,
      ),
    );
  }

  Future<void> _onSetActiveBag(
    SetActiveBag event,
    Emitter<BagState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BagLoaded) return;

    emit(currentState.copyWith(isSyncing: true));
    final result = await _bagRepository.setActiveBag(event.bagId);
    final hasPending = await _bagRepository.hasPendingUpdates();
    final bags = await _bagRepository.getBags();
    final activeBag = bags.isNotEmpty
        ? bags.firstWhere((b) => b.isActive, orElse: () => bags.first)
        : null;

    emit(
      currentState.copyWith(
        bags: bags,
        activeBag: activeBag,
        hasPendingSync: hasPending,
        isSyncing: false,
        message: result.wasQueued ? AppMessages.bagActiveSavedOffline : null,
      ),
    );
  }

  Future<void> _onLoadBagDetail(
    LoadBagDetail event,
    Emitter<BagState> emit,
  ) async {
    final currentState = state;
    if (currentState is BagLoaded) {
      emit(currentState.copyWith(isSyncing: true));
    } else {
      emit(const BagLoading());
    }

    try {
      final bags = await _bagRepository.getBags();
      final selectedBag = bags.firstWhere((b) => b.id == event.bagId);
      final hasMinData = await _bagRepository.hasMinimumClubData();
      final hasPending = await _bagRepository.hasPendingUpdates();

      emit(
        BagDetailLoaded(
          bags: bags,
          selectedBag: selectedBag,
          hasMinimumClubData: hasMinData,
          hasPendingSync: hasPending,
        ),
      );
    } catch (ex) {
      emit(
        BagError(
          message: AppMessages.bagDetailLoadFailed,
          lastBags: currentState is BagLoaded ? currentState.bags : null,
        ),
      );
    }
  }

  Future<void> _onCreateClub(CreateClub event, Emitter<BagState> emit) async {
    final currentState = state;
    if (currentState is! BagDetailLoaded) return;

    emit(currentState.copyWith(isSyncing: true));
    final result = await _bagRepository.createClub(
      bagId: event.bagId,
      request: event.request,
    );
    final hasPending = await _bagRepository.hasPendingUpdates();
    final bags = await _bagRepository.getBags();
    final selectedBag = bags.firstWhere((b) => b.id == event.bagId);
    final hasMinData = await _bagRepository.hasMinimumClubData();

    emit(
      currentState.copyWith(
        bags: bags,
        selectedBag: selectedBag,
        hasMinimumClubData: hasMinData,
        hasPendingSync: hasPending,
        isSyncing: false,
        message: result.wasQueued ? AppMessages.clubSavedOffline : null,
      ),
    );
  }

  Future<void> _onUpdateClub(UpdateClub event, Emitter<BagState> emit) async {
    final currentState = state;
    if (currentState is! BagDetailLoaded) return;

    emit(currentState.copyWith(isSyncing: true));
    final result = await _bagRepository.updateClub(
      bagId: event.bagId,
      clubId: event.clubId,
      request: event.request,
    );
    final hasPending = await _bagRepository.hasPendingUpdates();
    final bags = await _bagRepository.getBags();
    final selectedBag = bags.firstWhere((b) => b.id == event.bagId);
    final hasMinData = await _bagRepository.hasMinimumClubData();

    emit(
      currentState.copyWith(
        bags: bags,
        selectedBag: selectedBag,
        hasMinimumClubData: hasMinData,
        hasPendingSync: hasPending,
        isSyncing: false,
        message: result.wasQueued ? AppMessages.clubSavedOffline : null,
      ),
    );
  }

  Future<void> _onDeleteClub(DeleteClub event, Emitter<BagState> emit) async {
    final currentState = state;
    if (currentState is! BagDetailLoaded) return;

    emit(currentState.copyWith(isSyncing: true));
    await _bagRepository.deleteClub(bagId: event.bagId, clubId: event.clubId);
    final hasPending = await _bagRepository.hasPendingUpdates();
    final bags = await _bagRepository.getBags();
    final selectedBag = bags.firstWhere((b) => b.id == event.bagId);
    final hasMinData = await _bagRepository.hasMinimumClubData();

    emit(
      currentState.copyWith(
        bags: bags,
        selectedBag: selectedBag,
        hasMinimumClubData: hasMinData,
        hasPendingSync: hasPending,
        isSyncing: false,
        message: AppMessages.clubDeleted,
      ),
    );
  }

  Future<void> _onFlushQueue(FlushQueue event, Emitter<BagState> emit) async {
    final currentState = state;

    if (currentState is BagLoaded) {
      emit(currentState.copyWith(isSyncing: true));
    } else if (currentState is BagDetailLoaded) {
      emit(currentState.copyWith(isSyncing: true));
    }

    try {
      await _bagRepository.flushQueue();
      final hasPending = await _bagRepository.hasPendingUpdates();
      final bags = await _bagRepository.getBags();
      final hasMinData = await _bagRepository.hasMinimumClubData();

      if (currentState is BagLoaded) {
        final activeBag = bags.isNotEmpty
            ? bags.firstWhere((b) => b.isActive, orElse: () => bags.first)
            : null;
        emit(
          BagLoaded(
            bags: bags,
            activeBag: activeBag,
            hasMinimumClubData: hasMinData,
            hasPendingSync: hasPending,
            isSyncing: false,
            message: AppMessages.synced,
          ),
        );
      } else if (currentState is BagDetailLoaded) {
        emit(
          currentState.copyWith(
            bags: bags,
            selectedBag: bags.firstWhere(
              (b) => b.id == currentState.selectedBag.id,
            ),
            hasMinimumClubData: hasMinData,
            hasPendingSync: hasPending,
            isSyncing: false,
            message: AppMessages.synced,
          ),
        );
      }
    } catch (_) {
      if (currentState is BagLoaded) {
        emit(currentState.copyWith(isSyncing: false));
      } else if (currentState is BagDetailLoaded) {
        emit(currentState.copyWith(isSyncing: false));
      }
    }
  }
}
