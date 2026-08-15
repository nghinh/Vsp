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
    private final vnpt.vsp.module.profile.AppHandicapService appHandicapService;

    public HoleAdviceService(EntityManager em, LlmGateway gateway,
                             RedisTemplate<String, Object> redis, ObjectMapper objectMapper,
                             vnpt.vsp.module.profile.AppHandicapService appHandicapService) {
        this.em = em;
        this.gateway = gateway;
        this.redis = redis;
        this.objectMapper = objectMapper;
        this.appHandicapService = appHandicapService;
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
        List<Club> bag = bag(golferId);

        // The profile's handicap where it exists; the one this app computed
        // from their own rounds where it does not. Most Vietnamese golfers
        // hold no official handicap, and without a number here the stroke
        // allocation — the feature the stroke index exists for — sat silent.
        BigDecimal handicap = golfer == null ? null : golfer.handicap;
        if (handicap == null) {
            handicap = appHandicapService.compute(golferId).handicap();
        }

        Integer strokes = strokesReceived(handicap, hole.strokeIndex, 18);
        Integer netPar = strokes == null ? null : hole.par + strokes;
        final BigDecimal handicapUsed = handicap;
        var clubs = clubs(hole, bag);
        boolean clubsAreStandard = !bag.isEmpty() && bag.stream().allMatch(Club::standard);

        String cacheKey = "hole-advice:" + courseId + ":" + holeNumber + ":"
                + (teeName == null ? "-" : teeName) + ":" + golferId + ":" + history.rounds;
        String cached = cached(cacheKey);
        if (cached != null) {
            return response(hole, history, strokes,
                    handicapUsed, netPar, clubs,
                    clubsAreStandard, cached, true);
        }

        if (!gateway.isEnabled()) {
            // The facts are worth serving without the model: the screen still
            // has a hole to draw, and the golfer still has their own record on
            // it. Only the sentence is missing.
            return response(hole, history, strokes,
                    handicapUsed, netPar, clubs,
                    clubsAreStandard, null, false);
        }

        String advice = gateway.ask(
                prompt(hole, history, golfer, bag, strokes, netPar, clubs), MAX_TOKENS).trim();
        remember(cacheKey, advice);

        log.info("Advised golfer {} on course {} hole {} ({} rounds of history, {} shot(s) received)",
                golferId, courseId, holeNumber, history.rounds, strokes);
        return response(hole, history, strokes,
                handicapUsed, netPar, clubs,
                clubsAreStandard, advice, false);
    }

    private HoleAdviceResponse response(
            Hole hole, History history, Integer strokes, BigDecimal handicap,
            Integer netPar, List<HoleAdviceResponse.ClubForShot> clubs,
            boolean clubsAreStandard, String advice, boolean cached) {
        return new HoleAdviceResponse(
                hole.par, hole.strokeIndex, hole.yards, hole.meters, hole.tee,
                history.rounds, history.average, history.best,
                history.fairways, history.girs,
                strokes, handicap, netPar, clubs, clubsAreStandard, advice, cached);
    }

    /**
     * The prompt. Written in Vietnamese because the golfer reads it.
     *
     * <p>The instruction not to invent hazards is the load-bearing line. Asked
     * for "strategy on a 415-yard par 4" a model will happily describe the
     * bunker on the right, and there is no bunker on file for any hole in this
     * database.
     */
    private String prompt(Hole hole, History history, Golfer golfer, List<Club> bag,
                          Integer strokes, Integer netPar,
                          List<HoleAdviceResponse.ClubForShot> clubs) {
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

        if (strokes != null) {
            facts.append("Chia gậy: người này được ").append(strokes)
                    .append(" gậy handicap ở hố này, nên par thực tế của họ là ")
                    .append(netPar).append(".\n");
        }

        boolean allStandard = !bag.isEmpty() && bag.stream().allMatch(Club::standard);
        if (allStandard) {
            facts.append("LƯU Ý: người này chưa sửa cự ly gậy nào, nên các cự ly dưới đây "
                    + "là số tiêu chuẩn chung chứ không phải của họ.\n");
        }

        if (!bag.isEmpty()) {
            facts.append("Gậy trong túi và cự ly carry: ")
                    .append(bag.stream()
                            .map(c -> c.type + " " + c.carryMeters + "m")
                            .collect(java.util.stream.Collectors.joining(", ")))
                    .append(".\n");
        }

        if (!clubs.isEmpty()) {
            facts.append("Gậy đã chọn sẵn cho từng cú (tính từ cự ly carry của họ): ");
            for (var c : clubs) {
                facts.append(c.label()).append(" còn ").append(c.remainingMeters())
                        .append("m → ").append(c.club() == null ? "không đủ gậy" : c.club())
                        .append("; ");
            }
            facts.append("\n");
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
                - Nêu mục tiêu điểm số theo PAR THỰC TẾ của họ ở trên nếu có, không phải par của hố.
                - Không nhắc lại nguyên văn danh sách gậy đã chọn — nó đã hiển thị riêng \
                trên màn hình. Chỉ nói khi có lý do đổi so với lựa chọn đó.

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

    private List<Club> bag(Long golferId) {
        var rows = em.createNativeQuery("""
                SELECT c.club_type, c.carry_distance, c.loft, c.carry_is_default
                FROM clubs c JOIN golf_bags b ON b.id = c.golf_bag_id
                WHERE b.golfer_account_id = :golfer
                  AND c.carry_distance IS NOT NULL AND c.carry_distance > 0
                ORDER BY c.carry_distance DESC
                """).setParameter("golfer", golferId).getResultList();
        var bag = new ArrayList<Club>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            var type = vnpt.vsp.module.bag.entity.Club.ClubType.valueOf((String) r[0]);
            Double loft = r[2] == null ? null : ((Number) r[2]).doubleValue();
            bag.add(new Club(
                    // Named from the loft, because ClubType stops at IRON and
                    // eight irons all reading "IRON" tells a golfer nothing.
                    vnpt.vsp.module.bag.StandardBag.nameFor(type, loft),
                    (int) Math.round(((Number) r[1]).doubleValue()),
                    Boolean.TRUE.equals(r[3]),
                    type == vnpt.vsp.module.bag.entity.Club.ClubType.DRIVER));
        }
        return bag;
    }

    /**
     * How many shots this golfer receives on this hole.
     *
     * <p>The Rules define it exactly: a handicap of 20 over eighteen holes is
     * one shot everywhere and a second on the four hardest, which is what the
     * stroke index ranks. So it is arithmetic, and it is computed here rather
     * than asked of a model — a model that got it wrong would be wrong in a way
     * that changes a net score, silently, for everyone playing off that card.
     *
     * <p>Null when the golfer has no handicap on file or the club published no
     * index row. Half the country's cards have no index, and guessing one would
     * hand out shots on the wrong holes.
     */
    private Integer strokesReceived(BigDecimal handicap, Integer strokeIndex, int holes) {
        if (handicap == null || strokeIndex == null) {
            return null;
        }
        int playing = handicap.setScale(0, java.math.RoundingMode.HALF_UP).intValue();
        // A plus handicap gives shots back, on the easiest holes first.
        if (playing < 0) {
            int given = (-playing) / holes;
            int remainder = (-playing) % holes;
            return -(given + (strokeIndex > holes - remainder ? 1 : 0));
        }
        return playing / holes + (strokeIndex <= playing % holes ? 1 : 0);
    }

    /**
     * The clubs the hole asks for, from this golfer's own carry distances.
     *
     * <p>A par 3 is one shot at the flag. Anything longer is a tee shot with
     * the longest club in the bag and then whatever covers what is left; a par
     * 5 gets a third if the second cannot reach.
     *
     * <p>The club chosen is the shortest one that still carries the distance —
     * a golfer who takes the club that only just reaches on a good strike
     * comes up short on an average one. Nothing is suggested for a bag with no
     * carry distances in it: there is no table of averages here, because a
     * 7-iron is not a distance.
     */
    private List<HoleAdviceResponse.ClubForShot> clubs(Hole hole, List<Club> bag) {
        if (bag.isEmpty() || hole.lengthMeters() == null) {
            return List.of();
        }
        var plan = new ArrayList<HoleAdviceResponse.ClubForShot>();
        int remaining = hole.lengthMeters();
        int shotsAllowed = Math.max(1, hole.par - 2);   // par 3 → 1, par 5 → 3

        for (int shot = 1; shot <= shotsAllowed && remaining > 0; shot++) {
            boolean lastShot = shot == shotsAllowed;
            // A driver is hit off a tee peg. Recommending one for the second
            // shot of a par 5 — which this did, off the fairway, at 240 m — is
            // not a club choice any golfer would recognise.
            List<Club> playable = shot == 1
                    ? bag
                    : bag.stream().filter(c -> !c.driver()).toList();
            if (playable.isEmpty()) {
                break;
            }
            Club pick = lastShot
                    ? shortestThatCarries(playable, remaining)
                    : playable.get(0);
            String label = shotsAllowed == 1 ? "Cú vào green"
                    : shot == 1 ? "Cú phát bóng"
                    : lastShot ? "Cú vào green" : "Cú tiếp theo";

            plan.add(new HoleAdviceResponse.ClubForShot(
                    shot, label, remaining,
                    pick == null ? null : pick.type,
                    pick == null ? null : pick.carryMeters));

            if (pick == null) {
                break;
            }
            remaining -= pick.carryMeters;
        }
        return plan;
    }

    /// The shortest club that still covers the distance, or the longest
    /// available when nothing does — which is the honest answer to "I cannot
    /// reach from here".
    private Club shortestThatCarries(List<Club> bag, int metres) {
        Club best = null;
        for (Club club : bag) {
            if (club.carryMeters >= metres
                    && (best == null || club.carryMeters < best.carryMeters)) {
                best = club;
            }
        }
        return best != null ? best : bag.get(0);
    }

    /// @param standard true while the carry is the seeded default rather than
    ///                 something this golfer measured
    /// @param driver   a driver is hit off a tee peg and nowhere else, which
    ///                 is why it is excluded from every shot after the first
    private record Club(String type, int carryMeters, boolean standard, boolean driver) {}

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
        /// The hole's length in metres, from the tee's yardage where the card
        /// has one and from the measured coordinates otherwise.
        Integer lengthMeters() {
            if (yards != null) {
                return (int) Math.round(yards * 0.9144);
            }
            return meters == null ? null : meters.setScale(0,
                    java.math.RoundingMode.HALF_UP).intValue();
        }

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
