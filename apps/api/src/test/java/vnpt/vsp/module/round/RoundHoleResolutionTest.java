package vnpt.vsp.module.round;

import org.junit.jupiter.api.Test;
import vnpt.vsp.module.round.entity.Round;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Which course a hole of a round actually belongs to.
 *
 * <p>Long Biên is đường A, B and C at nine holes each, so an eighteen there is
 * two of them. A round could name one course, which left holes 10 to 18
 * belonging to nothing: the map reported no survey for any of them, advice
 * answered 404, and the pars and yardages already loaded for those holes were
 * unreachable — on a club whose card this project holds in full.
 */
class RoundHoleResolutionTest {

    private Round round(Long front, Long back) {
        Round r = new Round();
        r.setCourseId(front);
        r.setBackNineCourseId(back);
        return r;
    }

    /// The front nine is the round's own course, unchanged.
    @Test
    void holesOneToNineComeFromTheFirstCourse() {
        Round r = round(1351L, 1352L);

        assertThat(r.resolveHole(1)).containsExactly(1351L, 1);
        assertThat(r.resolveHole(9)).containsExactly(1351L, 9);
    }

    /// The bug, in one line: hole 10 is hole 1 of the back nine, not hole 10
    /// of a course that has nine.
    @Test
    void holeTenIsTheFirstHoleOfTheSecondCourse() {
        Round r = round(1351L, 1352L);

        assertThat(r.resolveHole(10)).containsExactly(1352L, 1);
        assertThat(r.resolveHole(18)).containsExactly(1352L, 9);
    }

    /// Most rounds are one eighteen-hole layout and stay exactly as they were.
    @Test
    void aRoundOnOneCourseIsUntouched() {
        Round r = round(1387L, null);

        assertThat(r.resolveHole(1)).containsExactly(1387L, 1);
        assertThat(r.resolveHole(10)).containsExactly(1387L, 10);
        assertThat(r.resolveHole(18)).containsExactly(1387L, 18);
    }

    /// A club can be played round twice — đường A out and đường A back.
    @Test
    void theSameNineCanBeBothHalves() {
        Round r = round(1351L, 1351L);

        assertThat(r.resolveHole(3)).containsExactly(1351L, 3);
        assertThat(r.resolveHole(12)).containsExactly(1351L, 3);
    }
}
