// Whose row is whose — VSP Mobile App
//
// A card carried round by a four-ball comes back with four rows of
// handwriting, and each row is labelled the way golfers label them: a first
// name, a nickname, a pair of initials, or one letter. The round already knows
// who is playing. Matching one against the other is the difference between
// picking your row out of a list every time and the app already knowing.
//
// It matches or it does not. A row it cannot place is left unassigned for the
// golfer to say, because assigning a round of strokes to the wrong player is
// worse in every direction than asking: the golfer whose card it was loses
// their round, and the golfer who receives it gets a handicap built on
// somebody else's afternoon.

import '../../../core/text/vietnamese_search.dart';

/// One candidate: a player in the round, and what they are called.
class RowCandidate {
  const RowCandidate({required this.playerId, required this.name});

  final String playerId;
  final String name;
}

/// How a label was matched, so the screen can say why rather than assert.
enum RowMatchKind {
  /// The label is the player's name, or the part of it people use.
  name,

  /// The label is their initials, or the first letter of their given name.
  initial,

  /// Nothing on the card decided it — there was simply nobody else it could
  /// be. One row, one player.
  only,

  /// Nothing matched, or more than one player matched equally well.
  none,
}

class RowMatch {
  const RowMatch({required this.playerId, required this.kind});

  static const RowMatch unmatched = RowMatch(playerId: null, kind: RowMatchKind.none);

  final String? playerId;
  final RowMatchKind kind;
}

/// Matches the labels read off a card against the players in the round.
///
/// Returns one entry per label, in the same order. A player is used at most
/// once: two rows cannot both be the same golfer, and letting them would
/// silently drop one row's strokes on top of the other's.
abstract final class ScoreRowMatcher {
  static List<RowMatch> match(
    List<String?> labels,
    List<RowCandidate> players,
  ) {
    final matches = List<RowMatch>.filled(labels.length, RowMatch.unmatched);
    final taken = <String>{};

    // Names first, across every row, then initials. A row labelled "N" should
    // not take Nghi before the row actually labelled "Nghi" has had its turn —
    // one letter is the weakest evidence on the card and should lose to the
    // strongest.
    for (final kind in [RowMatchKind.name, RowMatchKind.initial]) {
      for (var i = 0; i < labels.length; i++) {
        if (matches[i].playerId != null) continue;

        final label = _clean(labels[i]);
        if (label.isEmpty) continue;

        final hits = players
            .where((p) => !taken.contains(p.playerId))
            .where((p) => kind == RowMatchKind.name
                ? _matchesName(label, p.name)
                : _matchesInitial(label, p.name))
            .toList();

        // Exactly one, or nothing. Two players called Nam is a question the
        // card cannot answer and neither can this.
        if (hits.length == 1) {
          matches[i] = RowMatch(playerId: hits.single.playerId, kind: kind);
          taken.add(hits.single.playerId);
        }
      }
    }

    // One row on the card and one player in the round is not a guess, it is
    // the only reading there is — and a golfer playing alone should not have
    // to name themselves to an app that already knows who they are. Whatever
    // they scrawled at the left of their own row is a squiggle, an initial or
    // nothing at all, and none of it changes the answer. Last, so that a label
    // that does say something is read as what it says.
    if (labels.length == 1 && players.length == 1 && matches[0].playerId == null) {
      matches[0] = RowMatch(playerId: players.single.playerId, kind: RowMatchKind.only);
    }

    return matches;
  }

  /// The label as the golfer wrote it, minus what a pen leaves behind.
  static String _clean(String? label) =>
      VietnameseSearch.fold(label ?? '')
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');

  static List<String> _words(String name) =>
      _clean(name).split(' ').where((w) => w.isNotEmpty).toList();

  /// Whether the label names this player.
  ///
  /// Vietnamese names run family-name first and are used given-name last:
  /// Nguyễn Hồng Nghi is Nghi to everyone who plays with him, and that is what
  /// goes on the card. So the whole name matches, and so does any word of it —
  /// but a word, not a fragment: "Ng" is not Nghi, it is two letters that
  /// happen to start it, and treating it as a name would beat the initials
  /// rule that should be deciding it.
  static bool _matchesName(String label, String name) {
    final words = _words(name);
    if (words.isEmpty) return false;

    final whole = words.join(' ');
    if (label == whole) return true;

    // A label of several words matches the name's tail: "hong nghi" is Nguyễn
    // Hồng Nghi written short, which is how people sign a card.
    if (label.contains(' ') && whole.endsWith(label)) return true;

    return words.contains(label);
  }

  /// Whether the label is this player's initials.
  ///
  /// Three shapes, all of them on real cards: the first letter of the given
  /// name ("N" for Nghi), the initials of every word ("NHN"), and the family
  /// initial with the given name's ("NN").
  static bool _matchesInitial(String label, String name) {
    final words = _words(name);
    if (words.isEmpty) return false;

    // "N.H.N" is initials, and the punctuation strip has already turned it
    // into "n h n". Letters separated by dots is how half the cards in a
    // clubhouse are labelled, so a run of single letters is read as the one
    // word it was written as.
    final compact = label.contains(' ')
        ? (label.split(' ').every((w) => w.length == 1)
            ? label.replaceAll(' ', '')
            : null)
        : label;
    if (compact == null) return false;

    final letters = words.map((w) => w[0]).join();
    final given = words.last[0];

    return compact == given
        || compact == letters
        || (words.length > 1 && compact == '${words.first[0]}$given');
  }
}
