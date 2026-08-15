// Máy chia độ — VSP Mobile App
//
// Every photographed scorecard this project holds carries the same handwriting:
// four players, +/- notation, running totals per nine, crossings-out where a
// press changed the stakes. That is not stroke play — it is đánh độ, and the
// app pretended it did not exist while golfers did the arithmetic on paper.
//
// This engine does what the paper does, without the arguments:
//
//   * gives strokes on the RIGHT holes — the stroke index ranks difficulty and
//     handicap 20 gets its second stroke on the two hardest, which is the
//     entire reason clubs print an index and the entire reason this project
//     photographs their cards;
//   * plays every pair against each other (match play and Nassau are pairwise
//     by nature);
//   * carries tied skins forward the way the game is actually played;
//   * and settles the whole flight into the fewest transfers, which is the
//     sentence everyone actually wants: "ai trả ai bao nhiêu".
//
// Pure Dart, no I/O. It computes from whatever scores exist so far, so the
// standings are live mid-round, and it never touches money — it is the
// bookkeeping the paper always was, not a wallet.

/// One player of the game, as the flight knows them.
///
/// [handicap] is whatever the flight agrees on, typed into the sheet — a guest
/// with no account gets one the same way they always have, by negotiation on
/// the first tee.
class GamePlayer {
  const GamePlayer({
    required this.id,
    required this.name,
    this.handicap = 0,
  });

  final String id;
  final String name;
  final int handicap;
}

enum GameType { matchPlay, nassau, skins }

/// The agreed stake, in whatever unit the flight thinks in — points, nghìn,
/// beers. The engine multiplies; it does not care what it multiplies.
class GameConfig {
  const GameConfig({
    required this.type,
    this.stake = 1,
    this.useNet = true,
  });

  final GameType type;
  final int stake;

  /// False plays gross — the only honest option on a course whose card
  /// publishes no stroke index, because inventing an allocation would hand
  /// out strokes on the wrong holes.
  final bool useNet;
}

/// One money transfer of the settlement: [from] pays [to] [amount].
class Transfer {
  const Transfer({required this.from, required this.to, required this.amount});

  final GamePlayer from;
  final GamePlayer to;
  final int amount;
}

/// A pairwise match's running state, for the standings screen.
class MatchStanding {
  const MatchStanding({
    required this.a,
    required this.b,
    required this.aUp,
    required this.holesPlayed,
  });

  final GamePlayer a;
  final GamePlayer b;

  /// Positive: [a] is up by this many holes. Negative: down. Zero: all square.
  final int aUp;
  final int holesPlayed;
}

/// One skin, as won.
class SkinResult {
  const SkinResult({
    required this.holeNumber,
    required this.winner,
    required this.carriedHoles,
  });

  final int holeNumber;
  final GamePlayer winner;

  /// How many tied holes rolled into this one. The pot is (1 + carried) ×
  /// stake, collected from each other player.
  final int carriedHoles;
}

class GameResult {
  const GameResult({
    required this.matches,
    required this.skins,
    required this.carriedIntoNext,
    required this.transfers,
  });

  final List<MatchStanding> matches;
  final List<SkinResult> skins;

  /// Skins still carrying when the scores ran out — money on the table.
  final int carriedIntoNext;

  /// The settlement, netted: nobody pays someone who also owes them.
  final List<Transfer> transfers;
}

class GamesEngine {
  const GamesEngine({
    required this.players,
    required this.holeNumbers,
    required this.strokeIndexes,
    required this.gross,
    required this.config,
  });

  final List<GamePlayer> players;

  /// The round's holes, in play order.
  final List<int> holeNumbers;

  /// hole number → stroke index. Empty where the club published none — the
  /// engine then refuses to allocate rather than guessing.
  final Map<int, int> strokeIndexes;

  /// player id → hole number → gross strokes. Absent holes are simply not
  /// scored yet; the engine computes from what exists.
  final Map<String, Map<int, int>> gross;

  final GameConfig config;

  /// Whether net games are possible at all.
  bool get canPlayNet => strokeIndexes.length >= holeNumbers.length;

  // ─── Chấp gậy ─────────────────────────────────────────────────────────────

  /// Strokes [player] receives on [hole], playing off the lowest handicap in
  /// the flight.
  ///
  /// Off the lowest is how a flight actually plays: the best player gives
  /// strokes, everyone else receives the difference. Allocating each player's
  /// full handicap instead would change nothing pairwise but reads wrong on
  /// the card.
  ///
  /// The allocation itself is the Rules': the difference spread one stroke per
  /// hole from the hardest, second lap for anything past eighteen. The same
  /// arithmetic the server uses for net par — a wrong answer here changes who
  /// pays.
  int strokesOn(GamePlayer player, int hole) {
    if (!config.useNet || !canPlayNet) return 0;
    final si = strokeIndexes[hole];
    if (si == null) return 0;

    final low = players.map((p) => p.handicap).reduce((a, b) => a < b ? a : b);
    final playing = player.handicap - low;
    if (playing <= 0) return 0;

    final holes = holeNumbers.length;
    return playing ~/ holes + (si <= playing % holes ? 1 : 0);
  }

  /// Net strokes for [player] on [hole], or null when not scored yet.
  int? netOn(GamePlayer player, int hole) {
    final g = gross[player.id]?[hole];
    if (g == null) return null;
    return g - strokesOn(player, hole);
  }

  // ─── Match play ───────────────────────────────────────────────────────────

  /// The pairwise match between [a] and [b] over [holes].
  MatchStanding _match(GamePlayer a, GamePlayer b, List<int> holes) {
    var aUp = 0;
    var played = 0;
    for (final hole in holes) {
      final na = netOn(a, hole);
      final nb = netOn(b, hole);
      if (na == null || nb == null) continue;
      played++;
      if (na < nb) aUp++;
      if (nb < na) aUp--;
    }
    return MatchStanding(a: a, b: b, aUp: aUp, holesPlayed: played);
  }

  List<MatchStanding> _allMatches(List<int> holes) {
    final matches = <MatchStanding>[];
    for (var i = 0; i < players.length; i++) {
      for (var j = i + 1; j < players.length; j++) {
        matches.add(_match(players[i], players[j], holes));
      }
    }
    return matches;
  }

  // ─── Skins ────────────────────────────────────────────────────────────────

  /// Skins with carryover: the lowest unique net takes the hole; a tie rolls
  /// the hole into the next, which is what makes the 18th worth six beers.
  (List<SkinResult>, int) _skins() {
    final results = <SkinResult>[];
    var carried = 0;
    for (final hole in holeNumbers) {
      final nets = <GamePlayer, int>{};
      for (final p in players) {
        final n = netOn(p, hole);
        if (n == null) return (results, carried); // scores ran out here
        nets[p] = n;
      }
      final best = nets.values.reduce((a, b) => a < b ? a : b);
      final winners = nets.entries.where((e) => e.value == best).toList();
      if (winners.length == 1) {
        results.add(SkinResult(
          holeNumber: hole,
          winner: winners.first.key,
          carriedHoles: carried,
        ));
        carried = 0;
      } else {
        carried++;
      }
    }
    return (results, carried);
  }

  // ─── Settlement ───────────────────────────────────────────────────────────

  /// Who pays whom, netted.
  ///
  /// Netted matters: a raw ledger after eighteen holes of skins reads as a
  /// dozen crossing debts, and the whole point of doing this in software is
  /// that the clubhouse conversation becomes two sentences.
  List<Transfer> _settle(Map<String, int> balance) {
    // balance: +owed to them, −they owe. Sum is zero by construction.
    final creditors = players
        .where((p) => (balance[p.id] ?? 0) > 0)
        .map((p) => MapEntry(p, balance[p.id]!))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final debtors = players
        .where((p) => (balance[p.id] ?? 0) < 0)
        .map((p) => MapEntry(p, -balance[p.id]!))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final transfers = <Transfer>[];
    var ci = 0, di = 0;
    var credit = creditors.isEmpty ? 0 : creditors[0].value;
    var debt = debtors.isEmpty ? 0 : debtors[0].value;
    while (ci < creditors.length && di < debtors.length) {
      final amount = credit < debt ? credit : debt;
      if (amount > 0) {
        transfers.add(Transfer(
          from: debtors[di].key,
          to: creditors[ci].key,
          amount: amount,
        ));
      }
      credit -= amount;
      debt -= amount;
      if (credit == 0 && ++ci < creditors.length) credit = creditors[ci].value;
      if (debt == 0 && ++di < debtors.length) debt = debtors[di].value;
    }
    return transfers;
  }

  GameResult compute() {
    final balance = <String, int>{for (final p in players) p.id: 0};
    var matches = <MatchStanding>[];
    var skins = <SkinResult>[];
    var carried = 0;

    switch (config.type) {
      case GameType.matchPlay:
        matches = _allMatches(holeNumbers);
        // Đánh theo hố lệch: stake per hole up, per pair.
        for (final m in matches) {
          final amount = m.aUp.abs() * config.stake;
          if (m.aUp > 0) {
            balance[m.a.id] = balance[m.a.id]! + amount;
            balance[m.b.id] = balance[m.b.id]! - amount;
          } else if (m.aUp < 0) {
            balance[m.b.id] = balance[m.b.id]! + amount;
            balance[m.a.id] = balance[m.a.id]! - amount;
          }
        }

      case GameType.nassau:
        // Three flat bets per pair: front nine, back nine, the eighteen.
        // A nine-hole round simply has no back or total to bet on.
        final front = holeNumbers.take(9).toList();
        final back = holeNumbers.skip(9).toList();
        final segments = [
          front,
          if (back.isNotEmpty) back,
          if (back.isNotEmpty) holeNumbers,
        ];
        for (final segment in segments) {
          for (final m in _allMatches(segment)) {
            if (m.aUp == 0) continue;
            final winner = m.aUp > 0 ? m.a : m.b;
            final loser = m.aUp > 0 ? m.b : m.a;
            balance[winner.id] = balance[winner.id]! + config.stake;
            balance[loser.id] = balance[loser.id]! - config.stake;
          }
        }
        matches = _allMatches(holeNumbers);

      case GameType.skins:
        final (won, leftover) = _skins();
        skins = won;
        carried = leftover;
        for (final skin in won) {
          final pot = (1 + skin.carriedHoles) * config.stake;
          for (final p in players) {
            if (p.id == skin.winner.id) continue;
            balance[skin.winner.id] = balance[skin.winner.id]! + pot;
            balance[p.id] = balance[p.id]! - pot;
          }
        }
    }

    return GameResult(
      matches: matches,
      skins: skins,
      carriedIntoNext: carried,
      transfers: _settle(balance),
    );
  }
}
