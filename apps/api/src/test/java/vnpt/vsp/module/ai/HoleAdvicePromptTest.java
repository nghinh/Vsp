package vnpt.vsp.module.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The prompt, which is the part of this feature that can be wrong quietly.
 *
 * <p>A wrong number in a sentence a golfer reads on the tee is worse than no
 * sentence at all: they act on it, and nothing on the screen says where it came
 * from. So what goes into the model is asserted directly rather than inferred
 * from what comes out of it.
 */
class HoleAdvicePromptTest {

    private final HoleAdviceService service = new HoleAdviceService(
            null, new LlmGateway(new ObjectMapper(), "", "", ""), null, new ObjectMapper());

    @Test
    void carriesTheGolfersOwnRecordOnThisHole() throws Exception {
        String prompt = prompt(hole(), history(6), null, List.of());

        assertThat(prompt).contains("6 lần chơi", "trung bình 5.4", "tốt nhất 4");
        assertThat(prompt).contains("vào fairway 1/6", "lên green đúng nhịp 0/6");
        assertThat(prompt).contains("3 gậy phạt");
    }

    /// A first visit must say so, rather than leave the model to assume.
    @Test
    void saysPlainlyWhenTheGolferHasNeverPlayedIt() throws Exception {
        String prompt = prompt(hole(), history(0), null, List.of());

        assertThat(prompt).contains("chưa có dữ liệu vòng nào ở hố này");
        assertThat(prompt).doesNotContain("trung bình");
    }

    @Test
    void carriesTheHolesOwnNumbers() throws Exception {
        String prompt = prompt(hole(), history(0), null, List.of());

        assertThat(prompt).contains("Hố 7", "par 4", "chỉ số gậy 4/18",
                "415 yard", "tee Black", "Champion");
    }

    @Test
    void namesTheClubsTheGolferActuallyCarries() throws Exception {
        String prompt = prompt(hole(), history(0), null, List.of("DRIVER 230m", "IRON_7 145m"));

        assertThat(prompt).contains("DRIVER 230m", "IRON_7 145m");
    }

    /// The load-bearing instruction. No fairway polygon, no bunker and no
    /// dogleg is on file for these courses, so a model asked for "strategy"
    /// will describe scenery that is not there — and a golfer who follows that
    /// once and finds nothing stops believing the advice that is true.
    @Test
    void forbidsInventingTerrainTheDatabaseDoesNotHave() throws Exception {
        String prompt = prompt(hole(), history(0), null, List.of());

        assertThat(prompt).contains("Không mô tả bunker, hồ nước, dogleg, gió");
        assertThat(prompt).contains("KHÔNG có dữ liệu hình dạng hố");
    }

    // ─── Reaching the private prompt builder ─────────────────────────────────

    private String prompt(Object hole, Object history, Object golfer, List<String> bag)
            throws Exception {
        Method m = HoleAdviceService.class.getDeclaredMethod("prompt",
                inner("Hole"), inner("History"), inner("Golfer"), List.class);
        m.setAccessible(true);
        return (String) m.invoke(service, hole, history, golfer, bag);
    }

    private static Class<?> inner(String name) throws Exception {
        return Class.forName("vnpt.vsp.module.ai.HoleAdviceService$" + name);
    }

    private Object hole() throws Exception {
        Object h = instance("Hole");
        set(h, "number", 7);
        set(h, "par", 4);
        set(h, "strokeIndex", 4);
        set(h, "yards", 415);
        set(h, "tee", "Black");
        set(h, "courseName", "Champion");
        return h;
    }

    private Object history(int rounds) throws Exception {
        Object h = instance("History");
        set(h, "rounds", rounds);
        if (rounds > 0) {
            set(h, "average", new BigDecimal("5.4"));
            set(h, "best", 4);
            set(h, "fairways", 1);
            set(h, "girs", 0);
            set(h, "penalties", 3);
        }
        return h;
    }

    private static Object instance(String name) throws Exception {
        var ctor = inner(name).getDeclaredConstructor();
        ctor.setAccessible(true);
        return ctor.newInstance();
    }

    private static void set(Object target, String field, Object value) throws Exception {
        var f = target.getClass().getDeclaredField(field);
        f.setAccessible(true);
        f.set(target, value);
    }
}
