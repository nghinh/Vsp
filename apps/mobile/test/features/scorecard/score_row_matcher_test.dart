// Matching the labels on a card against the players in the round.
//
// Getting this wrong is worse than not doing it: a row assigned to the wrong
// golfer takes one player's round away and builds another's handicap out of an
// afternoon they did not play. So the rule these pin down is "match or say
// nothing", never "pick the closest".

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/scorecard/domain/score_row_matcher.dart';

void main() {
  const nghi = RowCandidate(playerId: '66', name: 'Nguyễn Hồng Nghi');
  const nam = RowCandidate(playerId: '67', name: 'Trần Văn Nam');
  const linh = RowCandidate(playerId: '68', name: 'Phạm Thùy Linh');

  List<String?> labels(List<String?> values) => values;

  test('a given name written on the card finds its player', () {
    // Vietnamese names run family-first and are used given-name last: Nguyễn
    // Hồng Nghi is Nghi to everyone he plays with, and Nghi is what goes in
    // the margin.
    final matches = ScoreRowMatcher.match(labels(['Nghi']), [nghi, nam]);

    expect(matches.single.playerId, '66');
    expect(matches.single.kind, RowMatchKind.name);
  });

  test('tone marks left off the card still match', () {
    // Nobody writes diacritics with a golf pencil.
    final matches = ScoreRowMatcher.match(labels(['NGHI', 'nam']), [nghi, nam]);

    expect(matches[0].playerId, '66');
    expect(matches[1].playerId, '67');
  });

  test('a single initial matches the given name', () {
    final matches = ScoreRowMatcher.match(labels(['N']), [nghi]);

    expect(matches.single.playerId, '66');
    expect(matches.single.kind, RowMatchKind.initial);
  });

  test('initials of the whole name match', () {
    final matches = ScoreRowMatcher.match(labels(['NHN']), [nghi, nam]);

    expect(matches.single.playerId, '66');
    expect(matches.single.kind, RowMatchKind.initial);
  });

  test('a name beats an initial for the same letter', () {
    // "N" could be Nghi or Nam. The row that spells Nam out should take Nam,
    // leaving N to Nghi — not the other way round, decided by row order.
    final matches = ScoreRowMatcher.match(labels(['N', 'Nam']), [nghi, nam]);

    expect(matches[1].playerId, '67');
    expect(matches[0].playerId, '66');
  });

  test('an initial two players share is left for the golfer to say', () {
    // Nghi and Nam both start with N. Picking either is a coin toss with
    // somebody's round on it.
    final matches = ScoreRowMatcher.match(labels(['N']), [nghi, nam]);

    expect(matches.single.playerId, isNull);
    expect(matches.single.kind, RowMatchKind.none);
  });

  test('a label that matches nobody is left unassigned', () {
    final matches = ScoreRowMatcher.match(labels(['Khách']), [nghi, nam]);

    expect(matches.single.playerId, isNull);
  });

  test('a row with no label at all is left unassigned', () {
    final matches = ScoreRowMatcher.match(labels([null, '']), [nghi, nam]);

    expect(matches[0].playerId, isNull);
    expect(matches[1].playerId, isNull);
  });

  test('one player cannot be two rows', () {
    // Two rows both reading "Nghi" is a misread of somebody else's row. Giving
    // both to Nghi would write one over the other and lose a golfer's card
    // without saying so.
    final matches = ScoreRowMatcher.match(labels(['Nghi', 'Nghi']), [nghi, nam]);

    expect(matches[0].playerId, '66');
    expect(matches[1].playerId, isNull);
  });

  test('a shortened full name matches its tail', () {
    final matches = ScoreRowMatcher.match(labels(['Hồng Nghi']), [nghi, nam]);

    expect(matches.single.playerId, '66');
  });

  test('a prefix of a name is not that name', () {
    // "Ng" starts Nghi and is not Nghi. Treating fragments as names would let
    // any two letters claim a player.
    final matches = ScoreRowMatcher.match(labels(['Ng']), [nghi, nam]);

    expect(matches.single.playerId, isNull);
  });

  test('a four-ball is matched row by row', () {
    final matches = ScoreRowMatcher.match(
      labels(['L', 'Nam', 'Nghi']),
      [nghi, nam, linh],
    );

    expect(matches[0].playerId, '68');
    expect(matches[1].playerId, '67');
    expect(matches[2].playerId, '66');
  });

  test('the family initial plus the given initial matches', () {
    final matches = ScoreRowMatcher.match(labels(['NN']), [nghi, linh]);

    expect(matches.single.playerId, '66');
  });

  test('initials written with dots are still initials', () {
    // "N.H.N" is how half the cards in a clubhouse are labelled.
    final matches = ScoreRowMatcher.match(labels(['N.H.N']), [nghi, nam]);

    expect(matches.single.playerId, '66');
    expect(matches.single.kind, RowMatchKind.initial);
  });

  test('one row and one player is the only reading there is', () {
    // A golfer playing alone should not have to tell the app who they are, and
    // whatever they scrawled at the left of their own row does not change the
    // answer when there is no other row and no other player.
    final matches = ScoreRowMatcher.match(labels([null]), [nghi]);

    expect(matches.single.playerId, '66');
    expect(matches.single.kind, RowMatchKind.only);
  });

  test('a label that does say something is read as what it says', () {
    // Even alone: the fallback is a last resort, not a shortcut past the card.
    final matches = ScoreRowMatcher.match(labels(['N']), [nghi]);

    expect(matches.single.kind, RowMatchKind.initial);
  });

  test('one row among several players is still matched on its label', () {
    // The shortcut is about there being nothing to confuse, not about there
    // being one row: three golfers and one legible row is a real question.
    final matches = ScoreRowMatcher.match(labels([null]), [nghi, nam, linh]);

    expect(matches.single.playerId, isNull);
  });

  test('punctuation around a label does not stop it matching', () {
    final matches = ScoreRowMatcher.match(labels(['(Nghi)', 'Nam.']), [nghi, nam]);

    expect(matches[0].playerId, '66');
    expect(matches[1].playerId, '67');
  });
}
