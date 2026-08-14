package vnpt.vsp.module.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.ai.dto.HoleAdviceResponse;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * What to think about standing on one tee, for one golfer.
 *
 * <p>The app already shows a golfer the number: 415 yards, par 4, index 4.
 * That number is the same for everyone, and it is the least useful thing known
 * about the hole to the person holding a 7-iron they cannot hit 160. What this
 * adds is the part that depends on who is asking — their handicap, what they
 * have actually scored on this hole before, and how far their own clubs go.
 *
 * <h2>Only facts that are on record</h2>
 *
 * <p>Everything in the prompt comes from a row: the hole from the club's card,
 * the history from this golfer's own score entries, the clubs from their own
 * bag. Nothing is inferred about the hole's shape, because nothing is known
 * about it — there is no fairway polygon, no bunker, no dogleg on file for most
 * courses. The prompt says so explicitly, so the model advises on distance and
 * scoring rather than inventing a lake to carry.
 *
 * <p>That restraint is the whole design. A confident sentence about a hazard
 * that is not there is worse than silence: a golfer who follows it once and
 * finds nothing stops believing the ones that are true.
 *
 * <h2>Cached per golfer</h2>
 *
 * <p>The advice for a golfer on a hole changes when their history does, which
 * is at most once a round. A metered model call per hole per tap would be paid
 * eighteen times a round, per player, for an answer that did not change.
 */
@Service
public class HoleAdviceService {

    private static final Logger log = LoggerFactory.getLogger(HoleAdviceService.class);

    private static final int MAX_TOKENS = 700;
    private static final Duration CACHE_TTL = Duration.ofHours(12);

    private final EntityManager em;
    private final LlmGateway gateway;
    private final RedisTemplate<String, Object> redis;
    private final ObjectMapper objectMapper;

    public HoleAdviceService(EntityManager em, LlmGateway gateway,
                             RedisTemplate<String, Object> redis, ObjectMapper objectMapper) {
        this.em = em;
        this.gateway = gateway;
        this.redis = redis;
        this.objectMapper = objectMapper;
    }

    public boolean isEnabled() {
        return gateway.isEnabled();
    }

    @Transactional(readOnly = true)
    public HoleAdviceResponse advise(Long courseId, int holeNumber, String teeName, Long golferId) {
        Hole hole = hole(courseId, holeNumber, teeName);
        if (hole == null) {
            throw new VspApiException(VspErrorCode.COURSE_001);
        }

        History history = history(courseId, holeNumber, golferId);
        Golfer golfer = golfer(golferId);
        List<String> bag = bag(golferId);

        String cacheKey = "hole-advice:" + courseId + ":" + holeNumber + ":"
                + (teeName == null ? "-" : teeName) + ":" + golferId + ":" + history.rounds;
        String cached = cached(cacheKey);
        if (cached != null) {
            return new HoleAdviceResponse(hole.par, hole.strokeIndex, hole.yards, hole.meters,
                    hole.tee, history.rounds, history.average, history.best,
                    history.fairways, history.girs, cached, true);
        }

        if (!gateway.isEnabled()) {
            // The facts are worth serving without the model: the screen still
            // has a hole to draw, and the golfer still has their own record on
            // it. Only the sentence is missing.
            return new HoleAdviceResponse(hole.par, hole.strokeIndex, hole.yards, hole.meters,
                    hole.tee, history.rounds, history.average, history.best,
                    history.fairways, history.girs, null, false);
        }

        String advice = gateway.ask(prompt(hole, history, golfer, bag), MAX_TOKENS).trim();
        remember(cacheKey, advice);

        log.info("Advised golfer {} on course {} hole {} ({} rounds of history)",
                golferId, courseId, holeNumber, history.rounds);
        return new HoleAdviceResponse(hole.par, hole.strokeIndex, hole.yards, hole.meters,
                hole.tee, history.rounds, history.average, history.best,
                history.fairways, history.girs, advice, false);
    }

    /**
     * The prompt. Written in Vietnamese because the golfer reads it.
     *
     * <p>The instruction not to invent hazards is the load-bearing line. Asked
     * for "strategy on a 415-yard par 4" a model will happily describe the
     * bunker on the right, and there is no bunker on file for any hole in this
     * database.
     */
    private String prompt(Hole hole, History history, Golfer golfer, List<String> bag) {
        var facts = new StringBuilder();
        facts.append("Hố ").append(hole.number)
                .append(", par ").append(hole.par);
        if (hole.strokeIndex != null) {
            facts.append(", chỉ số gậy ").append(hole.strokeIndex).append("/18");
        }
        if (hole.yards != null) {
            facts.append(", dài ").append(hole.yards).append(" yard");
            if (hole.tee != null) {
                facts.append(" từ tee ").append(hole.tee);
            }
        } else if (hole.meters != null) {
            facts.append(", dài ").append(hole.meters.setScale(0, java.math.RoundingMode.HALF_UP))
                    .append(" mét");
        }
        facts.append(". Sân: ").append(hole.courseName).append(".\n");

        if (golfer != null) {
            facts.append("Người chơi:");
            if (golfer.handicap != null) {
                facts.append(" handicap ").append(golfer.handicap).append(";");
            }
            if (golfer.skill != null) {
                facts.append(" trình độ ").append(skillInVietnamese(golfer.skill)).append(";");
            }
            if (golfer.driverDistance != null) {
                facts.append(" cú phát bóng driver khoảng ").append(golfer.driverDistance)
                        .append(" mét;");
            }
            facts.append(" thích đơn vị ")
                    .append("YARDS".equals(golfer.unit) ? "yard" : "mét").append(".\n");
        }

        if (history.rounds > 0) {
            facts.append("Thành tích của chính người này ở hố này: ")
                    .append(history.rounds).append(" lần chơi, trung bình ")
                    .append(history.average).append(" gậy, tốt nhất ")
                    .append(history.best).append(" gậy");
            if (history.fairways != null) {
                facts.append(", vào fairway ").append(history.fairways).append("/")
                        .append(history.rounds).append(" lần");
            }
            if (history.girs != null) {
                facts.append(", lên green đúng nhịp ").append(history.girs).append("/")
                        .append(history.rounds).append(" lần");
            }
            if (history.penalties > 0) {
                facts.append(", tổng ").append(history.penalties).append(" gậy phạt");
            }
            facts.append(".\n");
        } else {
            facts.append("Người này chưa có dữ liệu vòng nào ở hố này.\n");
        }

        if (!bag.isEmpty()) {
            facts.append("Gậy trong túi và cự ly carry: ")
                    .append(String.join(", ", bag)).append(".\n");
        }

        return """
                Bạn là caddie tư vấn cho một golfer Việt Nam sắp đánh một hố cụ thể.

                DỮ LIỆU CÓ THẬT VỀ HỐ NÀY:
                %s
                CÁCH TRẢ LỜI:
                - Viết tiếng Việt, 3 đến 4 câu ngắn, giọng như caddie đứng cạnh.
                - Chỉ dựa vào số liệu ở trên. Nếu người chơi có lịch sử ở hố này, \
                nói thẳng con số đó và điều chỉnh lời khuyên theo nó.
                - Nếu biết cự ly gậy của họ, gọi tên gậy cụ thể nên dùng.
                - Nêu một mục tiêu điểm số thực tế cho riêng người này, không phải par mặc định.

                TUYỆT ĐỐI KHÔNG:
                - Không mô tả bunker, hồ nước, dogleg, gió hay bất cứ chi tiết địa hình nào. \
                Hệ thống KHÔNG có dữ liệu hình dạng hố, nên mọi mô tả như vậy là bịa. \
                Một câu chắc nịch về cái hố cát không tồn tại sẽ khiến golfer mất tin \
                vào những lời khuyên đúng.
                - Không bịa số liệu người chơi không có.
                - Không mở đầu bằng lời chào hay kết bằng lời chúc. Vào thẳng nội dung.
                """.formatted(facts);
    }

    /// The skill level as a golfer would say it. The column holds an enum name,
    /// and putting BEGINNER into a Vietnamese sentence produced "trình độ
    /// intermediate" — the model repeats whatever it is handed.
    private static String skillInVietnamese(String skill) {
        return switch (skill == null ? "" : skill.toUpperCase(Locale.ROOT)) {
            case "BEGINNER" -> "mới chơi";
            case "INTERMEDIATE" -> "trung bình";
            case "ADVANCED" -> "khá";
            case "PROFESSIONAL", "PRO" -> "chuyên nghiệp";
            default -> skill;
        };
    }

    // ─── The facts, each straight off a row ──────────────────────────────────

    /**
     * The hole, and the yardage of the tee the golfer is playing.
     *
     * <p>{@code :tee} is CAST to text on both sides of its null check. Without
     * the cast Postgres cannot infer a bound null's type and answers 42P18,
     * "could not determine data type of parameter" — which made every request
     * that did not name a tee a 500. That is the default the app sends.
     */
    private Hole hole(Long courseId, int holeNumber, String teeName) {
        var rows = em.createNativeQuery("""
                SELECT h.par, h.playing_length_meters, c.name,
                       (SELECT sh.stroke_index FROM scorecards s
                          JOIN scorecard_segments g ON g.scorecard_id = s.id
                          JOIN scorecard_holes sh ON sh.scorecard_id = s.id
                         WHERE g.course_id = c.id AND sh.hole_number = h.hole_number
                         LIMIT 1),
                       (SELECT y.yards FROM scorecards s
                          JOIN scorecard_segments g ON g.scorecard_id = s.id
                          JOIN scorecard_tees t ON t.scorecard_id = s.id
                          JOIN scorecard_tee_yardages y ON y.scorecard_tee_id = t.id
                         WHERE g.course_id = c.id AND y.hole_number = h.hole_number
                           AND (CAST(:tee AS text) IS NULL OR t.name = CAST(:tee AS text))
                         ORDER BY y.yards DESC LIMIT 1),
                       (SELECT t.name FROM scorecards s
                          JOIN scorecard_segments g ON g.scorecard_id = s.id
                          JOIN scorecard_tees t ON t.scorecard_id = s.id
                          JOIN scorecard_tee_yardages y ON y.scorecard_tee_id = t.id
                         WHERE g.course_id = c.id AND y.hole_number = h.hole_number
                           AND (CAST(:tee AS text) IS NULL OR t.name = CAST(:tee AS text))
                         ORDER BY y.yards DESC LIMIT 1)
                FROM holes h JOIN courses c ON c.id = h.course_id
                WHERE h.course_id = :course AND h.hole_number = :hole
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("tee", teeName)
                .getResultList();
        if (rows.isEmpty()) {
            return null;
        }
        Object[] r = (Object[]) rows.get(0);
        var hole = new Hole();
        hole.number = holeNumber;
        hole.par = ((Number) r[0]).intValue();
        hole.meters = (BigDecimal) r[1];
        hole.courseName = (String) r[2];
        hole.strokeIndex = r[3] == null ? null : ((Number) r[3]).intValue();
        hole.yards = r[4] == null ? null : ((Number) r[4]).intValue();
        hole.tee = (String) r[5];
        return hole;
    }

    private History history(Long courseId, int holeNumber, Long golferId) {
        var rows = em.createNativeQuery("""
                SELECT count(*), avg(e.strokes), min(e.strokes),
                       count(*) FILTER (WHERE e.fairway_hit),
                       count(*) FILTER (WHERE e.gir),
                       coalesce(sum(e.penalties), 0)
                FROM score_entries e
                JOIN scores sc ON sc.id = e.score_id
                JOIN rounds r ON r.id = sc.round_id
                WHERE r.course_id = :course AND e.hole_number = :hole
                  AND sc.golfer_account_id = :golfer AND sc.deleted_at IS NULL
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("golfer", golferId)
                .getResultList();
        var history = new History();
        Object[] r = (Object[]) rows.get(0);
        history.rounds = ((Number) r[0]).intValue();
        if (history.rounds > 0) {
            history.average = BigDecimal.valueOf(((Number) r[1]).doubleValue())
                    .setScale(1, java.math.RoundingMode.HALF_UP);
            history.best = ((Number) r[2]).intValue();
            history.fairways = ((Number) r[3]).intValue();
            history.girs = ((Number) r[4]).intValue();
            history.penalties = ((Number) r[5]).intValue();
        }
        return history;
    }

    private Golfer golfer(Long golferId) {
        var rows = em.createNativeQuery("""
                SELECT handicap, distance_unit, skill_level, driver_distance
                FROM golfer_profiles WHERE golfer_account_id = :golfer
                """).setParameter("golfer", golferId).getResultList();
        if (rows.isEmpty()) {
            return null;
        }
        Object[] r = (Object[]) rows.get(0);
        var golfer = new Golfer();
        golfer.handicap = (BigDecimal) r[0];
        golfer.unit = (String) r[1];
        golfer.skill = (String) r[2];
        golfer.driverDistance = r[3] == null ? null : ((Number) r[3]).intValue();
        return golfer;
    }

    private List<String> bag(Long golferId) {
        var rows = em.createNativeQuery("""
                SELECT c.club_type, c.carry_distance
                FROM clubs c JOIN golf_bags b ON b.id = c.golf_bag_id
                WHERE b.golfer_account_id = :golfer AND c.carry_distance IS NOT NULL
                ORDER BY c.carry_distance DESC
                """).setParameter("golfer", golferId).getResultList();
        var bag = new ArrayList<String>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            bag.add(r[0] + " " + Math.round(((Number) r[1]).doubleValue()) + "m");
        }
        return bag;
    }

    // ─── Cache ───────────────────────────────────────────────────────────────

    private String cached(String key) {
        try {
            Object hit = redis.opsForValue().get(key);
            return hit == null ? null : hit.toString();
        } catch (Exception e) {
            // A cache that is down costs a model call, not an answer.
            log.warn("Hole-advice cache unavailable: {}", e.getMessage());
            return null;
        }
    }

    private void remember(String key, String advice) {
        try {
            redis.opsForValue().set(key, advice, CACHE_TTL);
        } catch (Exception e) {
            log.warn("Hole advice could not be cached: {}", e.getMessage());
        }
    }

    private static final class Hole {
        int number;
        int par;
        Integer strokeIndex;
        Integer yards;
        BigDecimal meters;
        String tee;
        String courseName;
    }

    private static final class History {
        int rounds;
        BigDecimal average;
        Integer best;
        Integer fairways;
        Integer girs;
        int penalties;
    }

    private static final class Golfer {
        BigDecimal handicap;
        String unit;
        String skill;
        Integer driverDistance;
    }
}
