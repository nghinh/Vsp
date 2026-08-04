// TournamentPlayer Model — VSP Mobile App
//
// Per Story 12.1 AC.
//
// Story 12.1 Slice F

import 'package:equatable/equatable.dart';

/// Registration status for a player in a tournament.
enum TournamentPlayerStatus { registered, confirmed, withdrawn, disqualified }

extension TournamentPlayerStatusExtension on TournamentPlayerStatus {
  String get label {
    switch (this) {
      case TournamentPlayerStatus.registered:
        return 'Registered';
      case TournamentPlayerStatus.confirmed:
        return 'Confirmed';
      case TournamentPlayerStatus.withdrawn:
        return 'Withdrawn';
      case TournamentPlayerStatus.disqualified:
        return 'Disqualified';
    }
  }

  static TournamentPlayerStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'REGISTERED':
        return TournamentPlayerStatus.registered;
      case 'CONFIRMED':
        return TournamentPlayerStatus.confirmed;
      case 'WITHDRAWN':
        return TournamentPlayerStatus.withdrawn;
      case 'DISQUALIFIED':
        return TournamentPlayerStatus.disqualified;
      default:
        throw ArgumentError('Unknown TournamentPlayerStatus: $value');
    }
  }
}

/// A player registered in a tournament.
class TournamentPlayer extends Equatable {
  final String id;
  final String tournamentId;
  final int playerId;
  final String? playerName; // denormalized for display
  final double? handicap;
  final String? flightId;
  final DateTime registrationTime;
  final TournamentPlayerStatus status;

  const TournamentPlayer({
    required this.id,
    required this.tournamentId,
    required this.playerId,
    this.playerName,
    this.handicap,
    this.flightId,
    required this.registrationTime,
    required this.status,
  });

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentPlayer(
      id: json['id'] as String,
      tournamentId: json['tournamentId'] as String,
      playerId: json['playerId'] is String
          ? int.parse(json['playerId'] as String)
          : json['playerId'] as int,
      playerName: json['playerName'] as String?,
      handicap: (json['handicap'] as num?)?.toDouble(),
      flightId: json['flightId'] as String?,
      registrationTime: DateTime.parse(json['registrationTime'] as String),
      status: TournamentPlayerStatusExtension.fromString(
        json['status'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tournamentId': tournamentId,
    'playerId': playerId,
    'playerName': playerName,
    'handicap': handicap,
    'flightId': flightId,
    'registrationTime': registrationTime.toIso8601String(),
    'status': status.name,
  };

  TournamentPlayer copyWith({
    String? id,
    String? tournamentId,
    int? playerId,
    String? playerName,
    double? handicap,
    String? flightId,
    DateTime? registrationTime,
    TournamentPlayerStatus? status,
  }) {
    return TournamentPlayer(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      handicap: handicap ?? this.handicap,
      flightId: flightId ?? this.flightId,
      registrationTime: registrationTime ?? this.registrationTime,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tournamentId,
    playerId,
    playerName,
    handicap,
    flightId,
    registrationTime,
    status,
  ];
}
