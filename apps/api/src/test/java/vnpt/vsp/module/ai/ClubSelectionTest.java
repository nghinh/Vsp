package vnpt.vsp.module.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import vnpt.vsp.module.ai.dto.HoleAdviceResponse;

import java.lang.reflect.Method;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Which club the hole asks for, from this golfer's own carry distances.
 *
 * <p>Computed rather than asked of a model, and from the bag rather than from a
 * table: a 7-iron is not a distance. Two golfers carry theirs 130 and 165, and
 * the one told to hit 7-iron from 160 is being told to come up short.
 */
class ClubSelectionTest {

    private final HoleAdviceService service = new HoleAdviceService(
            null, new LlmGateway(new ObjectMapper(), "", "", ""), null, new ObjectMapper());

    @SuppressWarnings("unchecked")
    private List<HoleAdviceResponse.ClubForShot> plan(int par, int metres, Object bag)
            throws Exception {
        Class<?> holeClass = Class.forName("vnpt.vsp.module.ai.HoleAdviceService$Hole");
        var ctor = holeClass.getDeclaredConstructor();
        ctor.setAccessible(true);
        Object hole = ctor.newInstance();
        set(hole, "par", par);
        set(hole, "meters", new java.math.BigDecimal(metres));

        Method m = HoleAdviceService.class.getDeclaredMethod("clubs", holeClass, List.class);
        m.setAccessible(true);
        return (List<HoleAdviceResponse.ClubForShot>) m.invoke(service, hole, bag);
    }

    private Object club(String type, int carry) throws Exception {
        var c = Class.forName("vnpt.vsp.module.ai.HoleAdviceService$Club");
        var ctor = c.getDeclaredConstructors()[0];
        ctor.setAccessible(true);
        return ctor.newInstance(type, carry);
    }

    private List<Object> bag() throws Exception {
        return List.of(club("DRIVER", 230), club("IRON_5", 170),
                       club("IRON_7", 145), club("WEDGE", 95));
    }

    private static void set(Object target, String field, Object value) throws Exception {
        var f = target.getClass().getDeclaredField(field);
        f.setAccessible(true);
        f.set(target, value);
    }

    /// A par 3 is one shot at the flag, not a tee shot and an approach.
    @Test
    void aParThreeIsOneClub() throws Exception {
        var plan = plan(3, 140, bag());

        assertThat(plan).hasSize(1);
        assertThat(plan.get(0).club()).isEqualTo("IRON_7");
        assertThat(plan.get(0).remainingMeters()).isEqualTo(140);
    }

    /// The shortest club that still covers it. A golfer given the club that
    /// only just reaches on a perfect strike is short on an ordinary one.
    @Test
    void takesTheShortestClubThatStillCarries() throws Exception {
        assertThat(plan(3, 96, bag()).get(0).club()).isEqualTo("IRON_7");
        assertThat(plan(3, 95, bag()).get(0).club()).isEqualTo("WEDGE");
    }

    @Test
    void aParFourIsATeeShotThenWhatIsLeft() throws Exception {
        var plan = plan(4, 370, bag());

        assertThat(plan).hasSize(2);
        assertThat(plan.get(0).club()).isEqualTo("DRIVER");
        assertThat(plan.get(1).remainingMeters()).isEqualTo(140);
        assertThat(plan.get(1).club()).isEqualTo("IRON_7");
    }

    @Test
    void aParFiveGetsAThirdShotWhenTheSecondCannotReach() throws Exception {
        var plan = plan(5, 520, bag());

        assertThat(plan).hasSize(3);
        assertThat(plan.get(0).club()).isEqualTo("DRIVER");
        assertThat(plan.get(2).remainingMeters()).isEqualTo(60);
        assertThat(plan.get(2).club()).isEqualTo("WEDGE");
    }

    /// There is no table of averages to fall back on, so a bag with no carry
    /// distances gets no advice rather than someone else's numbers.
    @Test
    void suggestsNothingForAnEmptyBag() throws Exception {
        assertThat(plan(4, 370, List.of())).isEmpty();
    }
}
