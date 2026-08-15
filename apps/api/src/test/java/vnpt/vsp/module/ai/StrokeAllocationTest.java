package vnpt.vsp.module.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * How many shots a golfer receives on a hole.
 *
 * <p>Arithmetic the Rules define exactly, so it is computed rather than asked
 * of a model: a wrong answer here changes a net score silently, for everyone
 * playing off that card, and nothing on the screen would show where the number
 * came from.
 *
 * <p>The stroke index is what makes it possible at all, and it is the one thing
 * no open dataset carries — which is why the photographed cards this platform
 * collects are worth collecting.
 */
class StrokeAllocationTest {

    private final HoleAdviceService service = new HoleAdviceService(
            null, new LlmGateway(new ObjectMapper(), "", "", ""), null, new ObjectMapper(), null);

    private Integer strokes(String handicap, Integer strokeIndex) throws Exception {
        Method m = HoleAdviceService.class.getDeclaredMethod(
                "strokesReceived", BigDecimal.class, Integer.class, int.class);
        m.setAccessible(true);
        return (Integer) m.invoke(service,
                handicap == null ? null : new BigDecimal(handicap), strokeIndex, 18);
    }

    /// Handicap 18 is one shot on every hole.
    @Test
    void oneShotEverywhereAtEighteen() throws Exception {
        assertThat(strokes("18", 1)).isEqualTo(1);
        assertThat(strokes("18", 18)).isEqualTo(1);
    }

    /// Handicap 20 is one shot everywhere and a second on the two hardest —
    /// which is exactly what the stroke index ranks.
    @Test
    void theExtraShotsGoToTheHardestHoles() throws Exception {
        assertThat(strokes("20", 1)).isEqualTo(2);
        assertThat(strokes("20", 2)).isEqualTo(2);
        assertThat(strokes("20", 3)).isEqualTo(1);
        assertThat(strokes("20", 18)).isEqualTo(1);
    }

    @Test
    void underEighteenTheShotsRunOutPartWayDownTheCard() throws Exception {
        assertThat(strokes("7", 7)).isEqualTo(1);
        assertThat(strokes("7", 8)).isZero();
    }

    /// A plus handicap gives shots back, and gives them back on the easiest
    /// holes — the mirror of where they are received.
    @Test
    void aPlusHandicapGivesShotsBack() throws Exception {
        assertThat(strokes("-2", 18)).isEqualTo(-1);
        assertThat(strokes("-2", 17)).isEqualTo(-1);
        assertThat(strokes("-2", 16)).isZero();
        assertThat(strokes("-2", 1)).isZero();
    }

    @Test
    void aHandicapOfZeroReceivesNothing() throws Exception {
        assertThat(strokes("0", 1)).isZero();
        assertThat(strokes("0", 18)).isZero();
    }

    /// Half the country's cards carry no index row. Guessing one would hand out
    /// shots on the wrong holes, so nothing is handed out at all.
    @Test
    void saysNothingWithoutAStrokeIndexOrAHandicap() throws Exception {
        assertThat(strokes("18", null)).isNull();
        assertThat(strokes(null, 4)).isNull();
    }

    /// A handicap is stored to one decimal; shots are whole.
    @Test
    void roundsAHandicapBeforeAllocating() throws Exception {
        assertThat(strokes("19.6", 2)).isEqualTo(2);   // 20
        assertThat(strokes("19.4", 2)).isEqualTo(1);   // 19, only index 1 gets two
    }
}
