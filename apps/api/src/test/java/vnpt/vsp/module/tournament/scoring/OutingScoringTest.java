package vnpt.vsp.module.tournament.scoring;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import vnpt.vsp.module.tournament.scoring.OutingRules.CapBand;
import vnpt.vsp.module.tournament.scoring.OutingRules.Division;
import vnpt.vsp.module.tournament.scoring.OutingRules.HandicapCap;
import vnpt.vsp.module.tournament.scoring.OutingRules.TechnicalKind;
import vnpt.vsp.module.tournament.scoring.OutingRules.TechnicalPrizeSpec;
import vnpt.vsp.module.tournament.scoring.OutingScoring.Card;
import vnpt.vsp.module.tournament.scoring.OutingScoring.Ranked;
import vnpt.vsp.module.tournament.scoring.OutingScoring.Results;
import vnpt.vsp.module.tournament.scoring.OutingScoring.TechnicalAward;
import vnpt.vsp.module.tournament.scoring.OutingScoring.TechnicalEntry;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The prize rules, tested against the clauses they came from.
 *
 * Two things are being checked here, and they are different. Most tests fix the
 * *shape* of a rule — that a countback reads the tail of a round, that a group
 * prize outranks a technical one. A smaller set, under {@link Configurable},
 * fixes that none of the club's numbers are welded in: change the sheet, change
 * the outcome, no release.
 *
 * Where a test encodes a clause, the clause is quoted in the language the
 * organisers wrote it in.
 */
class OutingScoringTest {

    private static final OutingRules RULES = OutingRules.vnptItSpringOuting2026();
    private static final OutingScoring SCORING = new OutingScoring(RULES);
    private static final int PAR = RULES.coursePar();

    /** The prize holes, from the rules — never written out by hand. */
    private static final int NTP_1 = RULES.technicalPrizes().get(0).holes().get(0);
    private static final int NTP_2 = RULES.technicalPrizes().get(0).holes().get(1);
    private static final int LD_1 = RULES.technicalPrizes().get(1).holes().get(0);

    /** Par over the last {@code holes} holes of the configured card. */
    private static int tailOfCard(int holes) {
        int[] pars = RULES.holePars();
        int sum = 0;
        for (int i = pars.length - holes; i < pars.length; i++) sum += pars[i];
        return sum;
    }

    /** Two holes of the same par, one on each nine — for countback tests. */
    private static final int FRONT_PAR4 = firstHoleWithPar(4, 1, 9);
    private static final int BACK_PAR4 = firstHoleWithPar(4, 10, RULES.holeCount());
    private static final int A_PAR5 = firstHoleWithPar(5, 1, RULES.holeCount());

    private static int firstHoleWithPar(int par, int from, int to) {
        for (int h = from; h <= to; h++) {
            if (RULES.parAt(h) == par) return h;
        }
        throw new IllegalStateException("no par " + par + " between holes " + from + " and " + to);
    }

    private static int[] evenPar() {
        return RULES.holePars().clone();
    }

    private static Card card(String ref, String division, int handicap, int[] holes) {
        return new Card(ref, ref, division, handicap, null, holes, null, null);
    }

    private static Card total(String ref, String division, int handicap, int gross) {
        return new Card(ref, ref, division, handicap, gross, null, null, null);
    }

    /** A fast-path card: one number for the round, plus what the flight reported. */
    private static Card fast(String ref, String division, int handicap, int gross,
                             Integer birdies, Integer eagles) {
        return new Card(ref, ref, division, handicap, gross, null, birdies, eagles);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "thể thức đấu gậy, tính tổng gậy so với HDC"
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class TheNetScore {

        @Test
        void isGrossMinusThePlayingHandicap() {
            // Nguyễn Hồng Nghi, nhóm B, HDC xét giải 28.
            assertEquals(95 - 28, SCORING.net(total("nghi", "B", 28, 95)));
        }

        @Test
        void addsUpTheHolesWhenTheyAreAllIn() {
            assertEquals(PAR - 6, SCORING.net(card("x", "A", 6, evenPar())));
        }

        @Test
        void prefersTheHolesOverAnEnteredTotal() {
            // Both present and disagreeing: the holes are the scorecard, the
            // total is a convenience. A mistyped total must not outrank the
            // eighteen numbers the marker signed for.
            assertEquals(PAR, SCORING.gross(new Card("x", "x", "A", 0, 999, evenPar(), null, null)));
        }

        @Test
        void isNullWhileTheFlightIsStillOut() {
            assertNull(SCORING.net(new Card("x", "x", "A", 10, null, null, null, null)));
        }

        @Test
        void ignoresAPartlyFilledCardsHoles() {
            // Six holes in. The total of those six is not a round, and treating
            // it as one would put the player straight to the top of the board.
            int[] partial = new int[18];
            for (int i = 0; i < 6; i++) partial[i] = 4;
            assertNull(SCORING.net(card("x", "A", 10, partial)));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "kết quả xét giải được tính thấp hơn HDC dự giải tối đa ba gậy
    //  (cắt đến âm 3)"
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class TheJudgingFloor {

        @Test
        void countsStrokesUnderTheHandicapUntilTheFloor() {
            // Two under par after the handicap, whatever par happens to be.
            assertEquals(-2, SCORING.judgingScore(total("x", "A", 10, PAR + 10 - 2)));
        }

        @Test
        void stopsAtTheFloor() {
            // Gross 72 off 10 is net 62, ten under. Judged at −3.
            assertEquals(-3, SCORING.judgingScore(total("x", "A", 10, 72)));
        }

        @Test
        void doesNotFloorScoresOverTheHandicap() {
            assertEquals(5, SCORING.judgingScore(total("x", "A", 10, PAR + 10 + 5)));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "cùng tổng gậy thì golfer có HDC thấp hơn sẽ thắng"
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class TheHandicapTieBreak {

        @Test
        void theLowerHandicapWins() {
            List<Ranked> r = SCORING.rankDivision("A",
                    List.of(total("high", "A", 24, 96), total("low", "A", 18, 90)));

            assertEquals("low", r.get(0).card().playerRef());
        }

        @Test
        void decidesBetweenTwoPlayersBothAtTheFloor() {
            // "cùng -3 thì người có handicap dự giải thấp hơn thắng"
            List<Ranked> r = SCORING.rankDivision("B",
                    List.of(total("hdc20", "B", 20, 60), total("hdc10", "B", 10, 50)));

            assertEquals(-3, r.get(0).judgingScore());
            assertEquals(-3, r.get(1).judgingScore());
            assertEquals("hdc10", r.get(0).card().playerRef());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "Đếm ngược: 9 hố vòng sau (10-18), 6 hố cuối, 3 hố cuối, hố 18"
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class TheCountback {

        /** Even par everywhere, then the named holes replaced. */
        private int[] parExcept(int... holeThenScore) {
            int[] h = evenPar();
            for (int i = 0; i < holeThenScore.length; i += 2) {
                h[holeThenScore[i] - 1] = holeThenScore[i + 1];
            }
            return h;
        }

        @Test
        void theBetterBackNineWins() {
            // Same gross, same handicap; one dropped a shot on the front nine
            // and the other on the back, so the back nine separates them. Both
            // holes are par 4, picked off the configured card — dropping one on
            // a par 3 instead would change the gross and the tie-break would
            // never be reached.
            Card front = card("droppedEarly", "A", 10, parExcept(FRONT_PAR4, RULES.parAt(FRONT_PAR4) + 1));
            Card back = card("droppedLate", "A", 10, parExcept(BACK_PAR4, RULES.parAt(BACK_PAR4) + 1));

            assertEquals(SCORING.gross(front), SCORING.gross(back));
            assertEquals("droppedEarly",
                    SCORING.rankDivision("A", List.of(back, front)).get(0).card().playerRef());
        }

        @Test
        void thenTheLastSix() {
            Card early = card("hole10", "A", 10, parExcept(13, 3, 10, 6));
            Card late = card("hole13", "A", 10, parExcept(10, 3, 13, 6));

            assertEquals(SCORING.countback(early, 9), SCORING.countback(late, 9));
            assertEquals("hole10",
                    SCORING.rankDivision("A", List.of(late, early)).get(0).card().playerRef());
        }

        @Test
        void thenTheLastThree() {
            Card early = card("hole13", "A", 10, parExcept(16, 3, 13, 6));
            Card late = card("hole16", "A", 10, parExcept(13, 3, 16, 6));

            assertEquals(SCORING.countback(early, 6), SCORING.countback(late, 6));
            assertEquals("hole13",
                    SCORING.rankDivision("A", List.of(late, early)).get(0).card().playerRef());
        }

        @Test
        void thenTheEighteenth() {
            Card early = card("hole16", "A", 10, parExcept(18, 3, 16, 6));
            Card late = card("hole18", "A", 10, parExcept(16, 3, 18, 6));

            assertEquals(SCORING.countback(early, 3), SCORING.countback(late, 3));
            assertEquals("hole16",
                    SCORING.rankDivision("A", List.of(late, early)).get(0).card().playerRef());
        }

        @Test
        void readsTheWindowsFromTheEndOfTheRound() {
            Card c = card("x", "A", 0, evenPar());
            // Read off the card rather than written out: these numbers are a
            // property of the course, and hardcoding them made the test fail
            // when the real Long Thành card replaced the placeholder.
            for (int window : List.of(9, 6, 3, 1)) {
                assertEquals(tailOfCard(window), SCORING.countback(c, window),
                        "last " + window + " holes");
            }
        }

        @Test
        void isUnavailableForATotalOnlyCard() {
            assertNull(SCORING.countback(total("x", "A", 10, 90), 9));
        }

        @Test
        void doesNotSilentlyRankATotalOnlyCardAheadOnCountback() {
            // Zeros for the missing holes would give the total-only card a
            // countback of nothing and put it first.
            List<Ranked> r = SCORING.rankDivision("A",
                    List.of(total("totalOnly", "A", 10, PAR), card("withHoles", "A", 10, evenPar())));

            assertEquals("withHoles", r.get(0).card().playerRef());
            assertFalse(r.get(1).countbackAvailable(),
                    "the board must show that this card cannot be counted back");
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Genuinely inseparable players
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class WhenNothingSeparatesThem {

        @Test
        void bothAreFlagged() {
            // Identical cards, identical handicaps: every tie-break is level.
            // The BTC decides; the software must not pretend it did.
            List<Ranked> r = SCORING.rankDivision("A",
                    List.of(card("a", "A", 10, evenPar()), card("b", "A", 10, evenPar())));

            assertTrue(r.get(0).tiedAndUnresolved());
            assertTrue(r.get(1).tiedAndUnresolved());
        }

        @Test
        void aClearWinnerIsNotFlagged() {
            List<Ranked> r = SCORING.rankDivision("A",
                    List.of(total("a", "A", 10, 80), total("b", "A", 10, 90)));

            assertFalse(r.get(0).tiedAndUnresolved());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Players still on the course
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class FlightsStillOut {

        @Test
        void sortLastButStayOnTheBoard() {
            List<Ranked> r = SCORING.rankDivision("A",
                    List.of(new Card("out", "out", "A", 10, null, null, null, null), total("in", "A", 10, 90)));

            assertEquals(2, r.size());
            assertEquals("in", r.get(0).card().playerRef());
            assertNull(r.get(1).net());
        }

        @Test
        void neverTakeAPrize() {
            // Only one player has finished, so nobody can be second or third —
            // and a card with no score must not collect "Nhì" by being the only
            // other row in the division.
            List<Ranked> r = SCORING.rankDivision("A",
                    List.of(total("finished", "A", 10, 90), new Card("out", "out", "A", 10, null, null, null, null)));

            assertNotNull(r.get(0).prizeTitle());
            assertNull(r.get(1).prizeTitle());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "Cách tính CAP ngày"
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class TheDailyCap {

        private int[] allOver(int over) {
            int[] h = evenPar();
            for (int i = 0; i < h.length; i++) h[i] += over;
            return h;
        }

        @Test
        void parIsZero() {
            assertEquals(0, SCORING.dailyCapAdjustment(card("x", "A", 0, evenPar())));
        }

        @Test
        void bogeyAndDoubleBogeyAreAlsoZero() {
            // The flat band is the club's own scale and the easiest thing to
            // get wrong by reaching for Stableford.
            assertEquals(0, SCORING.dailyCapAdjustment(card("x", "A", 0, allOver(1))));
            assertEquals(0, SCORING.dailyCapAdjustment(card("x", "A", 0, allOver(2))));
        }

        @Test
        void tripleBogeyIsPlusOnePerHole() {
            assertEquals(18, SCORING.dailyCapAdjustment(card("x", "A", 0, allOver(3))));
        }

        @Test
        void fourOverIsPlusTwoAndFiveOrWorseIsPlusThree() {
            assertEquals(36, SCORING.dailyCapAdjustment(card("x", "A", 0, allOver(4))));
            assertEquals(54, SCORING.dailyCapAdjustment(card("x", "A", 0, allOver(5))));
            assertEquals(54, SCORING.dailyCapAdjustment(card("x", "A", 0, allOver(9))));
        }

        @Test
        void birdieIsMinusOneAndEagleIsMinusTwo() {
            int[] h = evenPar();
            h[0] -= 1;
            h[3] -= 2;
            assertEquals(-3, SCORING.dailyCapAdjustment(card("x", "A", 0, h)));
        }

        @Test
        void treatsAlbatrossAsAnEagleOnThisScale() {
            // The configured scale's best band is open-ended at −2; it names no
            // step below eagle. Three under needs a par 5 to still be a legal
            // number of strokes.
            int[] h = evenPar();
            h[A_PAR5 - 1] -= 3;
            assertEquals(-2, SCORING.dailyCapAdjustment(card("x", "A", 0, h)));
        }

        @Test
        void isNullUntilTheCardIsComplete() {
            assertNull(SCORING.dailyCapAdjustment(total("x", "A", 0, 90)));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "Golfer đạt điểm birdies, eagle sẽ có phần thưởng từ BTC"
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class BirdiesAndEagles {

        @Test
        void areCountedSeparately() {
            int[] h = evenPar();
            h[0] -= 1;
            h[2] -= 1;
            h[3] -= 2;
            Card c = card("x", "A", 0, h);

            assertEquals(2, SCORING.birdies(c));
            assertEquals(1, SCORING.eagles(c));
        }

        @Test
        void comeFromTheFlightWhenOnlyATotalWasEntered() {
            // The fast path: 44 numbers instead of 792. Nothing to count from,
            // so the figure written on the card is the figure used — otherwise
            // "Golfer đạt điểm birdies sẽ có phần thưởng" is unanswerable for
            // every player on that path.
            Card c = fast("x", "A", 10, 85, 3, 1);
            assertEquals(3, SCORING.birdies(c));
            assertEquals(1, SCORING.eagles(c));
        }

        @Test
        void areCountedFromTheHolesWhenBothAreAvailable() {
            // The card is the record; a reported number that disagrees with the
            // eighteen scores loses.
            int[] h = evenPar();
            h[0] -= 1;
            Card both = new Card("x", "x", "A", 0, null, h, 9, 9);
            assertEquals(1, SCORING.birdies(both));
            assertEquals(0, SCORING.eagles(both));
        }

        @Test
        void areZeroWhenNobodyReportedAnything() {
            assertEquals(0, SCORING.birdies(total("x", "A", 10, 85)));
            assertEquals(0, SCORING.eagles(total("x", "A", 10, 85)));
        }

        @Test
        void aNegativeReportedCountIsTreatedAsNone() {
            assertEquals(0, SCORING.birdies(fast("x", "A", 10, 85, -2, null)));
        }

        @Test
        void anEagleIsNotAlsoCountedAsABirdie() {
            int[] h = evenPar();
            h[3] -= 2;
            assertEquals(0, SCORING.birdies(card("x", "A", 0, h)));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "Mỗi Golfer nhận tối đa 01 giải" / "xét theo hố trước và chưa nhận
    //  giải khác"
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class TechnicalPrizes {

        private final TechnicalPrizeSpec ntp = RULES.technicalPrizes().get(0);
        private final TechnicalPrizeSpec ld = RULES.technicalPrizes().get(1);

        // Taken from the rules, not written out: the prize holes follow the
        // course's card, and this test broke the moment the real Long Thành
        // card replaced the placeholder — which is the test being brittle,
        // not the rules being wrong.
        private final int ntpHole1 = ntp.holes().get(0);
        private final int ntpHole2 = ntp.holes().get(1);
        private final int ldHole1 = ld.holes().get(0);

        @Test
        void nearestToThePinGoesToTheShortestMeasurement() {
            List<TechnicalAward> awards = SCORING.allocate(ntp,
                    List.of(new TechnicalEntry("far", ntpHole1, 4.20),
                            new TechnicalEntry("close", ntpHole1, 1.15)),
                    Set.of());

            assertEquals(1, awards.size());
            assertEquals("close", awards.get(0).playerRef());
        }

        @Test
        void longestDriveGoesToTheLongest() {
            List<TechnicalAward> awards = SCORING.allocate(ld,
                    List.of(new TechnicalEntry("short", ldHole1, 210),
                            new TechnicalEntry("long", ldHole1, 265)),
                    Set.of());

            assertEquals("long", awards.get(0).playerRef());
        }

        @Test
        void aPlayerWhoTopsTwoHolesTakesTheEarlierOne() {
            // "xét theo hố trước" — and the later hole then goes to the next
            // best rather than going unawarded.
            List<TechnicalAward> awards = SCORING.allocate(ntp,
                    List.of(
                            new TechnicalEntry("star", ntpHole1, 1.0),
                            new TechnicalEntry("other", ntpHole1, 2.0),
                            new TechnicalEntry("star", ntpHole2, 0.5),
                            new TechnicalEntry("second", ntpHole2, 3.0)),
                    Set.of());

            assertEquals(2, awards.size());
            assertEquals("star", awards.get(0).playerRef());
            assertEquals(ntpHole1, awards.get(0).holeNumber());
            assertEquals("second", awards.get(1).playerRef());
            assertEquals(ntpHole2, awards.get(1).holeNumber());
        }

        @Test
        void skipsAPlayerWhoAlreadyHasADivisionPrize() {
            // "BTC ưu tiên trao giải cho cá nhân đạt thành tích tại mục I trước"
            List<TechnicalAward> awards = SCORING.allocate(ntp,
                    List.of(new TechnicalEntry("winnerOfGroupA", ntpHole1, 0.5),
                            new TechnicalEntry("nobodyYet", ntpHole1, 2.0)),
                    Set.of("winnerOfGroupA"));

            assertEquals("nobodyYet", awards.get(0).playerRef());
        }

        @Test
        void leavesAHoleUnawardedWhenEveryoneOnItAlreadyHasAPrize() {
            List<TechnicalAward> awards = SCORING.allocate(ntp,
                    List.of(new TechnicalEntry("a", ntpHole1, 0.5), new TechnicalEntry("b", ntpHole1, 2.0)),
                    Set.of("a", "b"));

            assertTrue(awards.isEmpty());
        }

        @Test
        void ignoresAnEntryOnAHoleThisPrizeIsNotPlayedFor() {
            // A measurement typed against the wrong hole should not silently
            // create a fifth prize.
            List<TechnicalAward> awards = SCORING.allocate(ntp,
                    List.of(new TechnicalEntry("x", 5, 1.0)), Set.of());   // 5 carries no prize

            assertTrue(awards.isEmpty());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // "Mỗi Golfer nhận tối đa 01 giải", across the whole prize table
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class OnePrizeEach {

        /** Everyone at the same score, so the handicap alone orders them. */
        private List<Card> field() {
            return List.of(
                    total("first", "A", 10, 82),
                    total("second", "A", 11, 83),
                    total("third", "A", 12, 84),
                    total("fourth", "A", 13, 85),
                    total("fifth", "A", 14, 86));
        }

        @Test
        void aGroupWinnerIsSkippedAndTheProxyPasses() {
            // "được giải ba rồi thì không được longest, nearpin nữa, nhường cho
            // người thứ 2". Third place tops the nearest-to-pin board on the
            // 3rd; the prize goes to the next best measurement instead.
            Results r = SCORING.compute(field(), List.of(
                    new TechnicalEntry("third", NTP_1, 0.5),
                    new TechnicalEntry("fourth", NTP_1, 1.8),
                    new TechnicalEntry("fifth", NTP_1, 2.4)));

            assertEquals("Ba — Second Runner Up",
                    r.byDivision().get("A").get(2).prizeTitle());

            TechnicalAward ntp3 = r.technicalAwards().stream()
                    .filter(a -> a.holeNumber() == NTP_1).findFirst().orElseThrow();
            assertEquals("fourth", ntp3.playerRef());
        }

        @Test
        void andPassesAgainIfTheSecondBestAlsoHasOne() {
            // "thứ 2 có giải rồi thì đến người thứ 3". Both the closest and the
            // next closest already hold group prizes.
            Results r = SCORING.compute(field(), List.of(
                    new TechnicalEntry("second", NTP_1, 0.5),
                    new TechnicalEntry("third", NTP_1, 1.0),
                    new TechnicalEntry("fourth", NTP_1, 1.8)));

            assertEquals("fourth", r.technicalAwards().stream()
                    .filter(a -> a.holeNumber() == NTP_1).findFirst().orElseThrow().playerRef());
        }

        @Test
        void aLongestDriveRulesOutANearestToThePin() {
            // "có longest thì thôi near pin và ngược lại". NTP is settled
            // first — it is listed first in the rules — so the player who wins
            // the 3rd is out of the longest drive on the 4th.
            Results r = SCORING.compute(field(), List.of(
                    new TechnicalEntry("fourth", NTP_1, 0.5),     // takes NTP hole 3
                    new TechnicalEntry("fourth", LD_1, 280.0),   // would top LD hole 4
                    new TechnicalEntry("fifth", LD_1, 240.0)));

            assertEquals("fourth", awardOn(r, "NTP", NTP_1).playerRef());
            assertEquals("fifth", awardOn(r, "LD", LD_1).playerRef());
        }

        @Test
        void nobodyEndsUpHoldingTwo() {
            // The whole table at once: five players, six prizes available
            // (three group + up to eight technical) and every one of them on
            // every technical board.
            List<TechnicalEntry> everyoneEverywhere = new java.util.ArrayList<>();
            List<String> refs = List.of("first", "second", "third", "fourth", "fifth");
            for (int hole : RULES.technicalPrizes().get(0).holes()) {
                for (int i = 0; i < refs.size(); i++) {
                    everyoneEverywhere.add(new TechnicalEntry(refs.get(i), hole, 1.0 + i));
                }
            }
            for (int hole : RULES.technicalPrizes().get(1).holes()) {
                for (int i = 0; i < refs.size(); i++) {
                    everyoneEverywhere.add(new TechnicalEntry(refs.get(i), hole, 300.0 - i));
                }
            }

            Results r = SCORING.compute(field(), everyoneEverywhere);

            List<String> groupWinners = r.byDivision().get("A").stream()
                    .filter(e -> e.prizeTitle() != null)
                    .map(e -> e.card().playerRef())
                    .toList();
            List<String> technicalWinners = r.technicalAwards().stream()
                    .map(TechnicalAward::playerRef)
                    .toList();

            List<String> all = new java.util.ArrayList<>(groupWinners);
            all.addAll(technicalWinners);
            assertEquals(all.size(), Set.copyOf(all).size(), "somebody was given two prizes");

            // Five players, three of them on group prizes, so only two are left
            // for eight technical holes — the other six go unawarded rather
            // than doubling up.
            assertEquals(3, groupWinners.size());
            assertEquals(2, technicalWinners.size());
        }

        private TechnicalAward awardOn(Results r, String code, int hole) {
            return r.technicalAwards().stream()
                    .filter(a -> a.prizeCode().equals(code) && a.holeNumber() == hole)
                    .findFirst().orElseThrow();
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Nothing about this club is welded into the code
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class Configurable {

        @Test
        void theDivisionBoundariesComeFromTheRules() {
            // The club's own two sheets disagree about whether 26 is A or B.
            OutingRules widerA = new OutingRules(
                    RULES.holePars(),
                    List.of(new Division("A", "Nhóm A", 0, 26, List.of("Nhất")),
                            new Division("B", "Nhóm B", 27, 35, List.of("Nhất"))),
                    RULES.handicapCap(), RULES.judgingFloor(), RULES.countbackWindows(),
                    RULES.dailyCapBands(), RULES.technicalPrizes(), RULES.onePrizePerPlayer());

            assertEquals("B", RULES.divisionFor(26).code());
            assertEquals("A", widerA.divisionFor(26).code());
        }

        @Test
        void theHandicapCapComesFromTheRules() {
            // "Các Golfers HDC trên 36 sẽ cắt về 35" — 36 itself is not capped.
            assertEquals(36, RULES.playingHandicap(36));
            assertEquals(35, RULES.playingHandicap(37));
            assertEquals(35, RULES.playingHandicap(54));

            OutingRules uncapped = new OutingRules(
                    RULES.holePars(), RULES.divisions(), null, RULES.judgingFloor(),
                    RULES.countbackWindows(), RULES.dailyCapBands(),
                    RULES.technicalPrizes(), RULES.onePrizePerPlayer());
            assertEquals(54, uncapped.playingHandicap(54));
        }

        @Test
        void theJudgingFloorComesFromTheRules() {
            OutingRules floorAtFive = new OutingRules(
                    RULES.holePars(), RULES.divisions(), RULES.handicapCap(), -5,
                    RULES.countbackWindows(), RULES.dailyCapBands(),
                    RULES.technicalPrizes(), RULES.onePrizePerPlayer());

            Card c = total("x", "A", 10, 72);   // net 62, ten under par
            assertEquals(-3, SCORING.judgingScore(c));
            assertEquals(-5, new OutingScoring(floorAtFive).judgingScore(c));
        }

        @Test
        void theCountbackWindowsComeFromTheRules() {
            // A club that counts back on the front nine instead reverses this
            // pair without a line of code changing.
            OutingRules noCountback = new OutingRules(
                    RULES.holePars(), RULES.divisions(), RULES.handicapCap(), RULES.judgingFloor(),
                    List.of(), RULES.dailyCapBands(), RULES.technicalPrizes(), RULES.onePrizePerPlayer());

            int[] a = evenPar();
            a[1] = 5;
            int[] b = evenPar();
            b[10] = 5;

            assertEquals("early",
                    SCORING.rankDivision("A", List.of(card("late", "A", 10, b), card("early", "A", 10, a)))
                            .get(0).card().playerRef());

            // With no windows configured the two are simply inseparable.
            assertTrue(new OutingScoring(noCountback)
                    .rankDivision("A", List.of(card("late", "A", 10, b), card("early", "A", 10, a)))
                    .get(0).tiedAndUnresolved());
        }

        @Test
        void theDailyCapScaleComesFromTheRules() {
            // A club that scores bogey as +1 rather than 0.
            OutingRules strict = new OutingRules(
                    RULES.holePars(), RULES.divisions(), RULES.handicapCap(), RULES.judgingFloor(),
                    RULES.countbackWindows(),
                    List.of(new CapBand(null, -1, -1), new CapBand(0, 0, 0), new CapBand(1, null, 1)),
                    RULES.technicalPrizes(), RULES.onePrizePerPlayer());

            int[] allBogey = evenPar();
            for (int i = 0; i < allBogey.length; i++) allBogey[i] += 1;
            Card c = card("x", "A", 0, allBogey);

            assertEquals(0, SCORING.dailyCapAdjustment(c));
            assertEquals(18, new OutingScoring(strict).dailyCapAdjustment(c));
        }

        @Test
        void thePrizeCountPerDivisionComesFromTheRules() {
            OutingRules onlyAWinner = new OutingRules(
                    RULES.holePars(),
                    List.of(new Division("A", "Nhóm A", 0, 25, List.of("Nhất"))),
                    RULES.handicapCap(), RULES.judgingFloor(), RULES.countbackWindows(),
                    RULES.dailyCapBands(), RULES.technicalPrizes(), RULES.onePrizePerPlayer());

            List<Card> four = List.of(total("1st", "A", 10, 80), total("2nd", "A", 10, 82),
                    total("3rd", "A", 10, 84), total("4th", "A", 10, 86));

            assertEquals(3, SCORING.rankDivision("A", four).stream()
                    .filter(r -> r.prizeTitle() != null).count());
            assertEquals(1, new OutingScoring(onlyAWinner).rankDivision("A", four).stream()
                    .filter(r -> r.prizeTitle() != null).count());
        }

        @Test
        void theTechnicalPrizeHolesComeFromTheRules() {
            TechnicalPrizeSpec configured = RULES.technicalPrizes().get(0);
            TechnicalPrizeSpec twoHoles = new TechnicalPrizeSpec(
                    "NTP", "Nearest to the pin", TechnicalKind.NEAREST_TO_PIN,
                    configured.holes().subList(0, 2), "m");

            // One entry on each of the configured holes.
            List<TechnicalEntry> entries = configured.holes().stream()
                    .map(h -> new TechnicalEntry("p" + h, h, 1.0))
                    .toList();

            assertEquals(configured.holes().size(),
                    SCORING.allocate(configured, entries, Set.of()).size());
            assertEquals(2, SCORING.allocate(twoHoles, entries, Set.of()).size());
        }

        @Test
        void theOnePrizeRuleCanBeTurnedOff() {
            OutingRules manyPrizes = new OutingRules(
                    RULES.holePars(), RULES.divisions(), RULES.handicapCap(), RULES.judgingFloor(),
                    RULES.countbackWindows(), RULES.dailyCapBands(), RULES.technicalPrizes(), false);

            List<TechnicalEntry> entries = List.of(
                    new TechnicalEntry("star", NTP_1, 1.0), new TechnicalEntry("star", NTP_2, 1.0));

            // One prize per player: the second hole passes over the star, and
            // with nobody else on it, goes unawarded.
            assertEquals(1, SCORING.allocate(RULES.technicalPrizes().get(0), entries, Set.of()).size());
            assertEquals(2, new OutingScoring(manyPrizes)
                    .allocate(RULES.technicalPrizes().get(0), entries, Set.of()).size());
        }

        @Test
        void theCourseNeedNotHaveEighteenHoles() {
            OutingRules nine = new OutingRules(
                    new int[]{4, 3, 5, 4, 4, 3, 5, 4, 4},
                    List.of(new Division("A", "Nhóm A", 0, 54, List.of("Nhất"))),
                    null, -3, List.of(3, 1), List.of(new CapBand(null, null, 0)), List.of(), true);
            OutingScoring nineHole = new OutingScoring(nine);

            assertEquals(36, nine.coursePar());
            assertEquals(13, nineHole.countback(
                    new Card("x", "x", "A", 0, null, nine.holePars().clone(), null, null), 3));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Rules a caller can state wrongly
    // ═══════════════════════════════════════════════════════════════════════

    @Nested
    class BadRules {

        @Test
        void aCountbackWindowLongerThanTheRoundIsRefused() {
            assertThrows(IllegalArgumentException.class, () -> new OutingRules(
                    new int[]{4, 4, 4}, RULES.divisions(), null, -3, List.of(9),
                    List.of(), List.of(), true));
        }

        @Test
        void aTechnicalPrizeOnAHoleTheCourseDoesNotHaveIsRefused() {
            assertThrows(IllegalArgumentException.class, () -> new OutingRules(
                    new int[]{4, 4, 4}, RULES.divisions(), null, -3, List.of(),
                    List.of(),
                    List.of(new TechnicalPrizeSpec("NTP", "NTP", TechnicalKind.NEAREST_TO_PIN,
                            List.of(11), "m")),
                    true));
        }

        @Test
        void aDivisionWithAnInvertedRangeIsRefused() {
            assertThrows(IllegalArgumentException.class,
                    () -> new Division("A", "Nhóm A", 30, 10, List.of()));
        }

        @Test
        void noDivisionsAtAllIsRefused() {
            assertThrows(IllegalArgumentException.class, () -> new OutingRules(
                    RULES.holePars(), List.of(), null, -3, List.of(), List.of(), List.of(), true));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // The whole prize table, on the shape of the real outing
    // ═══════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("both divisions rank and the group winners drop out of the technical prizes")
    void endToEnd() {
        // Nhóm B, from the 19/04/2026 sheet with their real judging handicaps:
        // Phạm Đức Long 27, Lưu Thị Hà 27, Nguyễn Hồng Nghi 28, Phan Hoài Nam 34.
        // Plus two of nhóm A: Nguyễn Văn Nam 6, Đỗ Mai Lan 16.
        Results results = SCORING.compute(
                List.of(
                        total("long", "B", 27, 99),   // net 72, level
                        total("ha", "B", 27, 97),     // net 70, −2
                        total("nghi", "B", 28, 98),   // net 70, −2, higher handicap
                        total("nam", "B", 34, 100),   // net 66, −6 → floored to −3
                        total("vannam", "A", 6, 78),  // net 72, level
                        total("lan", "A", 16, 85)),   // net 69, −3
                List.of(
                        new TechnicalEntry("nam", NTP_1, 0.4),      // already has nhóm B nhất
                        new TechnicalEntry("long", NTP_1, 2.6),
                        new TechnicalEntry("vannam", LD_1, 271),   // already has nhóm A nhất
                        new TechnicalEntry("lan", LD_1, 198)));

        List<Ranked> b = results.byDivision().get("B");
        assertEquals("nam", b.get(0).card().playerRef());
        assertEquals(-3, b.get(0).judgingScore(), "six under is judged at the floor");
        assertEquals("Nhất — Best Net", b.get(0).prizeTitle());
        assertEquals("ha", b.get(1).card().playerRef(), "level on −2, lower handicap takes nhì");
        assertEquals("nghi", b.get(2).card().playerRef());
        assertNull(b.get(3).prizeTitle(), "only three prizes in the division");

        List<Ranked> a = results.byDivision().get("A");
        assertEquals("lan", a.get(0).card().playerRef());

        // Every technical prize went to someone who had not already won.
        Set<String> groupWinners = Set.of("nam", "ha", "nghi", "lan", "vannam");
        List<TechnicalAward> technical = results.technicalAwards();
        assertEquals("long", technical.stream()
                        .filter(t -> t.holeNumber() == NTP_1).findFirst().orElseThrow().playerRef(),
                "the group winner is skipped and NTP passes to the next best");
        assertTrue(technical.stream().noneMatch(t -> groupWinners.contains(t.playerRef())
                        && !t.playerRef().equals("long")),
                "nobody holds two prizes");
        assertTrue(technical.stream().noneMatch(t -> t.holeNumber() == LD_1),
                "the only two on the 4th already have group prizes, so it goes unawarded");
    }
}
