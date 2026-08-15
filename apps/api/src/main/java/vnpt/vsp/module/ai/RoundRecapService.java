package vnpt.vsp.module.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.ai.dto.RoundRecapResponse;

import jakarta.persistence.EntityManager;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.Instant;
import java.util.UUID;

/**
 * The round, told as the message that goes to the flight's Zalo.
 *
 * <p>Every Vietnamese golf group has the same thread: someone posts the card,
 * someone retells the one good hole, someone counts the water balls. This
 * writes that message from the rows the round actually produced — the counts
 * a golfer talks in, the best hole, whether it was their best round — and
 * asks the model for the three sentences, never for the numbers.
 *
 * <p>Facts survive an unconfigured model; only the sentence goes missing.
 * Cached per round per golfer: a finished round's story does not change.
 */
@Service
public class RoundRecapService {

    private static final Logger log = LoggerFactory.getLogger(RoundRecapService.class);

    private static final int MAX_TOKENS = 500;
    private static final Duration CACHE_TTL = Duration.ofDays(7);
    private static final ZoneId VIETNAM = ZoneId.of("Asia/Ho_Chi_Minh");

    private final EntityManager em;
    private final LlmGateway gateway;
    private final RedisTemplate<String, Object> redis;

    public RoundRecapService(EntityManager em, LlmGateway gateway,
                             RedisTemplate<String, Object> redis) {
        this.em = em;
        this.gateway = gateway;
        this.redis = redis;
    }

    @Transactional(readOnly = true)
    public RoundRecapResponse recap(UUID roundId, Long golferId) {
        RoundRow round = round(roundId, golferId);
        Facts facts = facts(roundId, golferId);
        if (facts.holes == 0) {
            // A round with no scored holes has no story to tell.
            throw new VspApiException(VspErrorCode.ROUND_005);
        }
        BestHole best = bestHole(roundId, golferId);
        Standing standing = standing(golferId, facts.toPar());

        String cacheKey = "round-recap:" + roundId + ":" + golferId;
        String cached = cached(cacheKey);
        if (cached != null) {
            return response(round, facts, best, standing, cached, true);
        }
        if (!gateway.isEnabled()) {
            return response(round, facts, best, standing, null, false);
        }

        String recap = gateway.ask(prompt(round, facts, best, standing), MAX_TOKENS).trim();
        remember(cacheKey, recap);
        log.info("Recapped round {} for golfer {} ({} holes, {} to par)",
                roundId, golferId, facts.holes, facts.toPar());
        return response(round, facts, best, standing, recap, false);
    }

    private RoundRecapResponse response(RoundRow round, Facts f, BestHole best,
                                        Standing standing, String recap, boolean cached) {
        return new RoundRecapResponse(
                round.courseName, round.playedOn,
                f.holes, f.strokes, f.par,
                f.eagleOrBetter, f.birdies, f.pars, f.bogeys, f.doubleOrWorse,
                f.penalties, f.fairways, f.girs,
                best == null ? null : best.holeNumber,
                best == null ? null : best.strokes,
                best == null ? null : best.par,
                standing.rounds, standing.isBest,
                recap, cached);
    }

    /**
     * The prompt. Written in Vietnamese because the group reads it.
     *
     * <p>Same load-bearing restraint as the hole advice: the model gets the
     * numbers and is told to add nothing — no invented weather, no imagined
     * shots, no score it was not given. A recap that misremembers the score
     * gets corrected in the thread by four people holding the same card.
     */
    private String prompt(RoundRow round, Facts f, BestHole best, Standing standing) {
        var facts = new StringBuilder();
        facts.append("Sân: ").append(round.courseName)
                .append(". Ngày: ").append(round.playedOn).append(".\n");
        facts.append("Kết quả: ").append(f.strokes).append(" gậy cho ")
                .append(f.holes).append(" hố, par ").append(f.par)
                .append(" (").append(f.toPar() >= 0 ? "+" + f.toPar() : f.toPar())
                .append(").\n");
        facts.append("Trong đó: ");
        if (f.eagleOrBetter > 0) {
            facts.append(f.eagleOrBetter).append(" eagle trở lên, ");
        }
        facts.append(f.birdies).append(" birdie, ")
                .append(f.pars).append(" par, ")
                .append(f.bogeys).append(" bogey, ")
                .append(f.doubleOrWorse).append(" double bogey trở lên.\n");
        if (f.penalties > 0) {
            facts.append("Tổng gậy phạt: ").append(f.penalties).append(".\n");
        }
        if (f.fairways > 0 || f.girs > 0) {
            facts.append("Vào fairway ").append(f.fairways)
                    .append(" lần, lên green đúng nhịp ").append(f.girs).append(" lần.\n");
        }
        if (best != null) {
            facts.append("Hố hay nhất: hố ").append(best.holeNumber)
                    .append(", par ").append(best.par).append(", đánh ")
                    .append(best.strokes).append(" gậy.\n");
        }
        if (standing.isBest && standing.rounds > 1) {
            facts.append("Đây là vòng hay nhất trong ").append(standing.rounds)
                    .append(" vòng đã ghi của người này.\n");
        }

        return """
                Bạn viết tin nhắn tổng kết vòng golf để người chơi gửi vào nhóm Zalo của hội.

                SỐ LIỆU THẬT CỦA VÒNG:
                %s
                CÁCH VIẾT:
                - Tiếng Việt, 3 đến 4 câu, giọng vui vẻ như kể cho bạn trong hội.
                - Nhắc đúng các con số ở trên, chọn 2-3 con số đáng kể nhất chứ không liệt kê hết.
                - Nếu có hố hay nhất hoặc vòng hay nhất, kể nó ra.
                - Tối đa 2 emoji.

                TUYỆT ĐỐI KHÔNG:
                - Không bịa thời tiết, cú đánh, khoảng cách hay bất cứ chi tiết nào không có ở trên.
                - Không thêm lời chào, không xưng tên. Viết như chính người chơi tự kể.
                """.formatted(facts);
    }

    // ─── The rows ────────────────────────────────────────────────────────────

    /// The round, provided this golfer has a score in it — the person sharing
    /// a recap is whoever played, not only whoever created the round.
    private RoundRow round(UUID roundId, Long golferId) {
        var rows = em.createNativeQuery("""
                SELECT c.name,
                       (SELECT c2.name FROM courses c2 WHERE c2.id = r.back_nine_course_id),
                       coalesce(r.ended_at, r.started_at)
                FROM rounds r
                LEFT JOIN courses c ON c.id = r.course_id
                WHERE r.id = :round AND r.deleted_at IS NULL
                  AND (r.golfer_account_id = :golfer OR EXISTS (
                        SELECT 1 FROM scores s
                        WHERE s.round_id = r.id AND s.golfer_account_id = :golfer
                          AND s.deleted_at IS NULL))
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getResultList();
        if (rows.isEmpty()) {
            throw new VspApiException(VspErrorCode.ROUND_001);
        }
        Object[] r = (Object[]) rows.get(0);
        var round = new RoundRow();
        String front = (String) r[0];
        String back = (String) r[1];
        round.courseName = front == null ? "" : back == null ? front : front + " + " + back;
        // What a timestamptz comes back as depends on the mapping layer, and
        // this should not care.
        Object ts = r[2];
        Instant played = ts instanceof Instant i ? i
                : ts instanceof java.time.OffsetDateTime o ? o.toInstant()
                : ((java.sql.Timestamp) ts).toInstant();
        round.playedOn = played.atZone(VIETNAM).toLocalDate();
        return round;
    }

    private Facts facts(UUID roundId, Long golferId) {
        Object[] r = (Object[]) em.createNativeQuery("""
                SELECT count(*), coalesce(sum(e.strokes), 0), coalesce(sum(e.par), 0),
                       count(*) FILTER (WHERE e.strokes <= e.par - 2),
                       count(*) FILTER (WHERE e.strokes = e.par - 1),
                       count(*) FILTER (WHERE e.strokes = e.par),
                       count(*) FILTER (WHERE e.strokes = e.par + 1),
                       count(*) FILTER (WHERE e.strokes >= e.par + 2),
                       coalesce(sum(e.penalties), 0),
                       count(*) FILTER (WHERE e.fairway_hit),
                       count(*) FILTER (WHERE e.gir)
                FROM score_entries e
                JOIN scores s ON s.id = e.score_id
                WHERE s.round_id = :round AND s.golfer_account_id = :golfer
                  AND s.deleted_at IS NULL
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getSingleResult();
        var f = new Facts();
        f.holes = ((Number) r[0]).intValue();
        f.strokes = ((Number) r[1]).intValue();
        f.par = ((Number) r[2]).intValue();
        f.eagleOrBetter = ((Number) r[3]).intValue();
        f.birdies = ((Number) r[4]).intValue();
        f.pars = ((Number) r[5]).intValue();
        f.bogeys = ((Number) r[6]).intValue();
        f.doubleOrWorse = ((Number) r[7]).intValue();
        f.penalties = ((Number) r[8]).intValue();
        f.fairways = ((Number) r[9]).intValue();
        f.girs = ((Number) r[10]).intValue();
        return f;
    }

    private BestHole bestHole(UUID roundId, Long golferId) {
        var rows = em.createNativeQuery("""
                SELECT e.hole_number, e.strokes, e.par
                FROM score_entries e
                JOIN scores s ON s.id = e.score_id
                WHERE s.round_id = :round AND s.golfer_account_id = :golfer
                  AND s.deleted_at IS NULL
                ORDER BY (e.strokes - e.par), e.hole_number
                LIMIT 1
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getResultList();
        if (rows.isEmpty()) {
            return null;
        }
        Object[] r = (Object[]) rows.get(0);
        var best = new BestHole();
        best.holeNumber = ((Number) r[0]).intValue();
        best.strokes = ((Number) r[1]).intValue();
        best.par = ((Number) r[2]).intValue();
        return best;
    }

    /// Rounds on record and whether this one beats them all against par.
    /// Compared against par rather than raw strokes so a nine and an
    /// eighteen can stand in the same list without the nine always winning.
    private Standing standing(Long golferId, int thisToPar) {
        var rows = em.createNativeQuery("""
                SELECT count(*), min(t.to_par)
                FROM (SELECT sum(e.strokes - e.par) AS to_par
                      FROM score_entries e
                      JOIN scores s ON s.id = e.score_id
                      WHERE s.golfer_account_id = :golfer AND s.deleted_at IS NULL
                      GROUP BY s.round_id
                      HAVING count(*) IN (9, 18)) t
                """)
                .setParameter("golfer", golferId)
                .getResultList();
        var standing = new Standing();
        Object[] r = (Object[]) rows.get(0);
        standing.rounds = ((Number) r[0]).intValue();
        standing.isBest = r[1] != null && thisToPar <= ((Number) r[1]).intValue();
        return standing;
    }

    // ─── Cache ───────────────────────────────────────────────────────────────

    private String cached(String key) {
        try {
            Object hit = redis.opsForValue().get(key);
            return hit == null ? null : hit.toString();
        } catch (Exception e) {
            log.warn("Round-recap cache unavailable: {}", e.getMessage());
            return null;
        }
    }

    private void remember(String key, String recap) {
        try {
            redis.opsForValue().set(key, recap, CACHE_TTL);
        } catch (Exception e) {
            log.warn("Round recap could not be cached: {}", e.getMessage());
        }
    }

    private static final class RoundRow {
        String courseName;
        LocalDate playedOn;
    }

    private static final class Facts {
        int holes;
        int strokes;
        int par;
        int eagleOrBetter;
        int birdies;
        int pars;
        int bogeys;
        int doubleOrWorse;
        int penalties;
        int fairways;
        int girs;

        int toPar() {
            return strokes - par;
        }
    }

    private static final class BestHole {
        int holeNumber;
        int strokes;
        int par;
    }

    private static final class Standing {
        int rounds;
        boolean isBest;
    }
}
